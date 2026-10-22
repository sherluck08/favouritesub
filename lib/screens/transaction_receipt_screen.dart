import 'dart:io';

import 'package:favouritesub/config/brand.dart';
import 'package:favouritesub/models/transaction_item.dart';
import 'package:favouritesub/utils/receipt_image_share.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class TransactionReceiptScreen extends StatelessWidget {
  final TransactionItem item;

  const TransactionReceiptScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final receiptKey = GlobalKey();

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Transaction receipt'),
        centerTitle: true,
        actions: [
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: 'Share receipt',
              onPressed: () => _showShareOptions(buttonContext, receiptKey),
              icon: const Icon(Icons.ios_share_rounded),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: RepaintBoundary(
              key: receiptKey,
              child: _ReceiptDocument(item: item),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showShareOptions(
    BuildContext context,
    GlobalKey receiptKey,
  ) async {
    final choice = await showModalBottomSheet<_ShareFormat>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share receipt',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the format you want to share.',
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _ShareOption(
              icon: Icons.image_outlined,
              title: 'Share as image',
              subtitle: 'Best for WhatsApp and social apps',
              onTap: () => Navigator.pop(sheetContext, _ShareFormat.image),
            ),
            const SizedBox(height: 10),
            _ShareOption(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Share as PDF',
              subtitle: 'Best for printing and record keeping',
              onTap: () => Navigator.pop(sheetContext, _ShareFormat.pdf),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == _ShareFormat.image) {
      await ReceiptImageShare.share(
        context,
        boundaryKey: receiptKey,
        item: item,
      );
    } else {
      await _sharePdf(context);
    }
  }

  Future<File> _buildPdf() async {
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              Brand.current.appName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Transaction receipt'),
            pw.SizedBox(height: 20),
            pw.Text(
              formatMoney(item.receiptAmount),
              style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 18),
            _pdfRow('Status', normalizedStatus(item.status)),
            _pdfRow('Transaction ID', item.id),
            _pdfRow('Service', serviceLabel(item)),
            _pdfRow('Phone number', item.mobileNumber),
            if (item.transactionType == TransactionType.airtime) ...[
              _pdfRow('Airtime value', formatMoney(item.amount)),
              if (item.airtimeDiscountAmount != null)
                _pdfRow(
                  'Discount',
                  '-${formatMoney(item.airtimeDiscountAmount!.toString())}',
                ),
              _pdfRow('Amount paid', formatMoney(item.receiptAmount)),
            ],
            _pdfRow('Description', item.duration),
            _pdfRow('Plan', item.plan),
            _pdfRow('Payment method', item.paymentMedium),
            _pdfRow('Previous balance', item.balanceBefore),
            _pdfRow('New balance', item.balanceAfter),
            _pdfRow('Transaction date', formatReceiptDate(item.timestamp)),
          ],
        ),
      ),
    );
    final directory = await getTemporaryDirectory();
    final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File(
      '${directory.path}/${Brand.current.appName.toLowerCase()}_receipt_$safeId.pdf',
    );
    await file.writeAsBytes(await document.save(), flush: true);
    return file;
  }

  pw.Widget _pdfRow(String label, String value) {
    if (value.trim().isEmpty) return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.SizedBox(width: 20),
          pw.Expanded(child: pw.Text(value, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final file = await _buildPdf();
      if (!context.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: '${Brand.current.appName} transaction receipt',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share receipt: $error')),
      );
    }
  }
}

class _ReceiptDocument extends StatelessWidget {
  final TransactionItem item;

  const _ReceiptDocument({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = receiptStatus(item.status, colors);
    final rows = <(String, String)>[
      ('Transaction ID', item.id),
      ('Phone number', item.mobileNumber),
      if (item.transactionType == TransactionType.airtime) ...[
        ('Airtime value', formatMoney(item.amount)),
        if (item.airtimeDiscountAmount != null)
          (
            'Discount',
            '-${formatMoney(item.airtimeDiscountAmount!.toString())}',
          ),
        ('Amount paid', formatMoney(item.receiptAmount)),
      ],
      ('Description', item.duration),
      ('Plan', item.plan),
      ('Payment method', item.paymentMedium),
      ('Previous balance', formatOptionalMoney(item.balanceBefore)),
      ('New balance', formatOptionalMoney(item.balanceAfter)),
      ('Transaction date', formatReceiptDate(item.timestamp)),
    ].where((row) => row.$2.trim().isNotEmpty).toList();

    return Container(
      color: colors.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      Brand.current.logoAsset,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Brand.current.appName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Transaction receipt',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Divider(color: colors.outlineVariant, height: 1),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: status.background,
                shape: BoxShape.circle,
              ),
              child: Icon(status.icon, color: status.foreground, size: 27),
            ),
            const SizedBox(height: 12),
            Text(
              status.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                formatMoney(item.receiptAmount),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              serviceLabel(item),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Divider(color: colors.outlineVariant, height: 1),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Transaction details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < rows.length; index++) ...[
              _ReceiptRow(label: rows[index].$1, value: rows[index].$2),
              if (index != rows.length - 1)
                Divider(height: 24, color: colors.outlineVariant),
            ],
            if (item.apiResponse.trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provider response',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.apiResponse,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'Thank you for using ${Brand.current.appName}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 6,
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final ReceiptStatusPresentation status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: status.background,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      status.label,
      style: TextStyle(
        color: status.foreground,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

enum _ShareFormat { image, pdf }

class ReceiptStatusPresentation {
  final String label;
  final String message;
  final IconData icon;
  final Color foreground;
  final Color background;

  const ReceiptStatusPresentation({
    required this.label,
    required this.message,
    required this.icon,
    required this.foreground,
    required this.background,
  });
}

ReceiptStatusPresentation receiptStatus(String raw, ColorScheme colors) {
  final status = raw.trim().toLowerCase();
  if (status.contains('success') || status.contains('complete')) {
    return const ReceiptStatusPresentation(
      label: 'Successful',
      message: 'Payment successful',
      icon: Icons.check_rounded,
      foreground: Color(0xFF087A4B),
      background: Color(0xFFE5F6ED),
    );
  }
  if (status.contains('process') || status.contains('pending')) {
    return const ReceiptStatusPresentation(
      label: 'Processing',
      message: 'Payment processing',
      icon: Icons.schedule_rounded,
      foreground: Color(0xFF8A5600),
      background: Color(0xFFFFF1D8),
    );
  }
  return ReceiptStatusPresentation(
    label: raw.trim().isEmpty ? 'Failed' : normalizedStatus(raw),
    message: 'Payment unsuccessful',
    icon: Icons.close_rounded,
    foreground: colors.error,
    background: colors.errorContainer,
  );
}

String normalizedStatus(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Unknown';
  return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
}

String formatMoney(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^0-9.-]'), '');
  final amount = double.tryParse(cleaned);
  if (amount == null) return value.startsWith('₦') ? value : '₦$value';
  final parts = amount.toStringAsFixed(2).split('.');
  final sign = parts.first.startsWith('-') ? '-' : '';
  final digits = sign.isEmpty ? parts.first : parts.first.substring(1);
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$sign₦$grouped.${parts.last}';
}

String formatOptionalMoney(String value) {
  if (value.trim().isEmpty) return '';
  return formatMoney(value);
}

String formatReceiptDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/${date.year}, $hour:$minute $period';
}

String serviceLabel(TransactionItem item) {
  final parts = [
    item.networkName,
    item.planSize,
  ].where((value) => value.trim().isNotEmpty).toList();
  return parts.isEmpty ? 'Transaction' : parts.join(' • ');
}
