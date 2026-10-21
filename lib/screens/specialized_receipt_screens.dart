import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:favouritesub/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:share_plus/share_plus.dart';
import 'package:favouritesub/config/brand.dart';
import 'package:favouritesub/models/transaction_item.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:favouritesub/utils/receipt_image_share.dart';

abstract class BaseReceiptScreen extends StatelessWidget {
  final TransactionItem item;
  const BaseReceiptScreen({super.key, required this.item});

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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: RepaintBoundary(
              key: receiptKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: colors.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: buildReceiptContent(context),
              ),
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
    final choice = await showModalBottomSheet<String>(
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
            _ReceiptShareTile(
              icon: Icons.image_outlined,
              title: 'Share as image',
              subtitle: 'Best for WhatsApp and social apps',
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            const SizedBox(height: 10),
            _ReceiptShareTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Share as PDF',
              subtitle: 'Best for printing and record keeping',
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'image') {
      await ReceiptImageShare.share(
        context,
        boundaryKey: receiptKey,
        item: item,
      );
    } else {
      await _sharePdf(context);
    }
  }

  Widget buildReceiptContent(BuildContext context);

  Widget _dividerRow(String label, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              Expanded(child: Text(value, textAlign: TextAlign.right)),
            ],
          ),
        ),
        const Divider(height: 20),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  Color _statusColor(String s) {
    final t = s.toLowerCase();
    if (t == 'successful') return Colors.green;
    if (t == 'processing') return Colors.blue;
    return Colors.redAccent;
  }

  Color _statusBg(String s) {
    final t = s.toLowerCase();
    if (t == 'successful') return Colors.green.shade50;
    if (t == 'processing') return Colors.blue.shade50;
    return Colors.red.shade50;
  }

  Future<File> _buildPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: buildPdfContent(),
          );
        },
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${Brand.current.appName.toLowerCase()}_receipt_${item.id}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  List<pw.Widget> buildPdfContent();

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
        SnackBar(content: Text('Could not share receipt PDF: $error')),
      );
    }
  }
}

class _ReceiptShareTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReceiptShareTile({
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

class ElectricityReceiptScreen extends BaseReceiptScreen {
  const ElectricityReceiptScreen({super.key, required super.item});

  @override
  Widget buildReceiptContent(BuildContext context) {
    String tokenText = (item.token ?? '').trim();
    if (tokenText.toLowerCase().startsWith('token:')) {
      tokenText = tokenText.substring(6).trim();
    }
    final isPrepaid = ((item.meterType ?? 'Prepaid').toLowerCase().contains(
      'pre',
    ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.asset(
                      Utils.getAssetForElectricity(item.packageName ?? ''),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.meterNumber ?? 'Meter Number',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.packageName ?? 'Abuja Electric',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: item.meterNumber ?? ''),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Meter number copied')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        if (tokenText.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Token', style: TextStyle(color: Colors.grey.shade600)),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: tokenText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Token copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy all'),
                  ),
                  if (isPrepaid)
                    TextButton.icon(
                      onPressed: () => _showQrSheet(context, tokenText),
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('QR code'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SelectableText(
              tokenText,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount', style: TextStyle(color: Colors.grey)),
                Text(
                  '₦${item.amount}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusBg(item.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: _statusColor(item.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _dividerRow('Transaction ID', item.id),
        _dividerRow('Customer Name', item.customerName ?? 'N/A'),
        _dividerRow('Customer Address', item.customerAddress ?? 'N/A'),
        _dividerRow('Token', tokenText.isNotEmpty ? tokenText : 'N/A'),
        _dividerRow('Status', item.status),
        _dividerRow('Meter', item.meterNumber ?? 'N/A'),
        _dividerRow('Meter Type', item.meterType ?? 'Prepaid'),
        _dividerRow('Amount', '₦${item.amount}'),
        _dividerRow('Previous Balance', '₦${item.balanceBefore}'),
        _dividerRow('New Balance', '₦${item.balanceAfter}'),
        _dividerRow('Transaction Date', _formatDate(item.timestamp)),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Thank you for using ${Brand.current.appName}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  @override
  List<pw.Widget> buildPdfContent() {
    final rawToken = (item.token ?? '').trim();
    final tokenPdf = rawToken.toLowerCase().startsWith('token:')
        ? rawToken.substring(6).trim()
        : rawToken;
    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${item.packageName ?? 'Abuja Electric'} - ${item.meterNumber ?? 'N/A'}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            Brand.current.domain
                .replaceAll('https://', '')
                .replaceAll('http://', ''),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.SizedBox(height: 8),
      pw.Text('Transaction ID: ${item.id}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Customer Name: ${item.customerName ?? 'N/A'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Customer Address: ${item.customerAddress ?? 'N/A'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Token: ${tokenPdf.isNotEmpty ? tokenPdf : 'N/A'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Status: ${item.status}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Meter: ${item.meterNumber ?? 'N/A'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Meter Type: ${item.meterType ?? 'Prepaid'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Amount: ₦${item.amount}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Previous Balance: ₦${item.balanceBefore}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('New Balance: ₦${item.balanceAfter}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Transaction Date: ${_formatDate(item.timestamp)}'),
    ];
  }
}

void _showQrSheet(BuildContext context, String data) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Scan Token',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: data,
                size: 220,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            SelectableText(
              data,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: data));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Token copied')));
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy token'),
            ),
          ],
        ),
      ),
    ),
  );
}

class AirtimeReceiptScreen extends BaseReceiptScreen {
  const AirtimeReceiptScreen({super.key, required super.item});

  @override
  Widget buildReceiptContent(BuildContext context) {
    final logo = Utils.logoFor(item.networkName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(logo, width: 40, height: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item.networkName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Icon(
                                  Icons.public,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  Brand.current.domain
                                      .replaceAll('https://', '')
                                      .replaceAll('http://', ''),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                "API response:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 5),
              Text(
                '${item.apiResponse} ',
                style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount', style: TextStyle(color: Colors.grey)),
                Text(
                  '₦${item.amount}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusBg(item.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: _statusColor(item.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _dividerRow('Transaction ID', item.id),
        _dividerRow('Status', item.status),
        _dividerRow('Phone', item.mobileNumber),
        _dividerRow('Product', '${item.networkName} VTU'),
        _dividerRow('Amount', item.amount),
        _dividerRow('Amount Paid', item.amount),
        _dividerRow('Previous Balance', '₦${item.balanceBefore}'),
        _dividerRow('New Balance', '₦${item.balanceAfter}'),
        _dividerRow('Date', _formatDate(item.timestamp)),

        const SizedBox(height: 16),

        Text(
          'Thank you for using ${Brand.current.appName}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  @override
  List<pw.Widget> buildPdfContent() {
    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${item.networkName} ${item.product ?? 'VTU'}',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            Brand.current.domain
                .replaceAll('https://', '')
                .replaceAll('http://', ''),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.SizedBox(height: 8),
      pw.Text('Transaction ID: ${item.id}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Status: ${item.status}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Phone: ${item.mobileNumber}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Product: ${item.product ?? 'VTU'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Amount: ₦${item.amount}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Amount Paid: ₦${item.amount}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Previous Balance: ₦${item.balanceBefore}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('New Balance: ₦${item.balanceAfter}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Date: ${_formatDate(item.timestamp)}'),
    ];
  }
}

class CableReceiptScreen extends BaseReceiptScreen {
  const CableReceiptScreen({super.key, required super.item});

  @override
  Widget buildReceiptContent(BuildContext context) {
    final logo = Utils.getAssetForCable(item.packageName ?? '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(logo, width: 40, height: 40),
                  const SizedBox(width: 10),
                  Text(
                    item.packageName ?? 'Cable Subscription',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount', style: TextStyle(color: Colors.grey)),
                Text(
                  '₦${item.amount}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusBg(item.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: _statusColor(item.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _dividerRow('Transaction ID', item.id),
        _dividerRow('Status', item.status),
        _dividerRow('Smart Card Number', item.smartCardNumber ?? 'N/A'),
        _dividerRow('Product', item.packageName ?? 'Cable Subscription'),
        _dividerRow('Amount', '₦${item.amount}'),
        _dividerRow('Previous Balance', '₦${item.balanceBefore}'),
        _dividerRow('New Balance', '₦${item.balanceAfter}'),
        _dividerRow('Date', _formatDate(item.timestamp)),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Thank you for using ${Brand.current.appName}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  @override
  List<pw.Widget> buildPdfContent() {
    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${item.networkName} Cable Subscription',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            Brand.current.domain
                .replaceAll('https://', '')
                .replaceAll('http://', ''),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.SizedBox(height: 8),
      pw.Text('Transaction ID: ${item.id}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Status: ${item.status}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Phone: ${item.mobileNumber}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Smart Card Number: ${item.smartCardNumber ?? 'N/A'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Product: ${item.product ?? 'Cable Subscription'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Amount: ₦${item.amount}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Previous Balance: ₦${item.balanceBefore}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('New Balance: ₦${item.balanceAfter}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Date: ${_formatDate(item.timestamp)}'),
    ];
  }
}

class RechargeCardReceiptScreen extends BaseReceiptScreen {
  const RechargeCardReceiptScreen({super.key, required super.item});

  @override
  Widget buildReceiptContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.purple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'R',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.service ?? 'Recharge Card',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PIN Purchase',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount', style: TextStyle(color: Colors.grey)),
                Text(
                  '₦${item.amount}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusBg(item.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: _statusColor(item.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _dividerRow('Service', item.service ?? 'Recharge Card'),
        _dividerRow('Transaction ID', item.id),
        _dividerRow('Status', item.status),
        _dividerRow('Name on card', item.nameOnCard ?? 'N/A'),
        _dividerRow('Quantity', item.quantity ?? '1'),
        _dividerRow('Pins', item.pins ?? 'N/A'),
        _dividerRow('Date', _formatDate(item.timestamp)),
        _dividerRow('Amount', '₦${item.amount}'),
        _dividerRow('Previous Balance', '₦${item.balanceBefore}'),
        _dividerRow('After Balance', '₦${item.balanceAfter}'),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Thank you for using ${Brand.current.appName}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  @override
  List<pw.Widget> buildPdfContent() {
    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '${item.service ?? 'Recharge Card'} PIN',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            Brand.current.domain
                .replaceAll('https://', '')
                .replaceAll('http://', ''),
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.SizedBox(height: 8),
      pw.Text('Service: ${item.service ?? 'Recharge Card'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Transaction ID: ${item.id}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Status: ${item.status}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Name on card: ${item.nameOnCard ?? 'N/A'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Quantity: ${item.quantity ?? '1'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Pins: ${item.pins ?? 'N/A'}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Date: ${_formatDate(item.timestamp)}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Amount: ₦${item.amount}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Previous Balance: ₦${item.balanceBefore}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('After Balance: ₦${item.balanceAfter}'),
    ];
  }
}

class RechargeCardPinsReceiptScreen extends BaseReceiptScreen {
  final List<dynamic> pinEntries;
  const RechargeCardPinsReceiptScreen({
    super.key,
    required super.item,
    required this.pinEntries,
  });

  @override
  Widget buildReceiptContent(BuildContext context) {
    final pins = _normalizePins(pinEntries);
    final key = GlobalKey();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _saveDialog(context, key),
              icon: const Icon(Icons.save_alt),
              label: const Text('Save Receipt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _printReceipt(context, key),
              icon: const Icon(Icons.print),
              label: const Text('Print Receipt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RepaintBoundary(
          key: key,
          child: Column(
            children: [
              if (pins.length == 1)
                _VoucherCard(
                  logo: Utils.logoFor(Utils.getNetworkName(item.networkId)),
                  reference: item.id,
                  name: item.nameOnCard ?? (item.customerName ?? 'Customer'),
                  pin: pins.first['pin'] ?? '',
                  serial: (pins.first['serial'] ?? '').isEmpty
                      ? 'Nil'
                      : (pins.first['serial'] ?? ''),
                  amount: item.amount.toString(),
                  date: _formatDate(item.timestamp),
                  color: cs.primary,
                )
              else ...[
                for (final p in pins)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _VoucherCard(
                      logo: Utils.logoFor(Utils.getNetworkName(item.networkId)),
                      reference: item.id,
                      name:
                          item.nameOnCard ?? (item.customerName ?? 'Customer'),
                      pin: p['pin'] ?? '',
                      serial: (p['serial'] ?? '').isEmpty
                          ? 'Nil'
                          : (p['serial'] ?? ''),
                      amount: item.amount.toString(),
                      date: _formatDate(item.timestamp),
                      color: cs.primary,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  List<pw.Widget> buildPdfContent() {
    final pins = _normalizePins(pinEntries);
    final widgets = <pw.Widget>[];
    for (final p in pins) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: pdf.PdfColors.grey500),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'REF: ${item.id}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    Brand.current.appName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'PIN: ${p['pin'] ?? ''}',
                style: pw.TextStyle(font: pw.Font.times(), fontSize: 12),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'S/N: ${(p['serial'] ?? '').isEmpty ? 'Nil' : p['serial']}',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${_formatDate(item.timestamp)}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '₦${item.amount}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  '*123*PIN#',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _saveDialog(BuildContext context, GlobalKey key) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Save as Image'),
                subtitle: const Text('Save to Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  await _saveAsImage(context, key);
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('Save as PDF'),
                subtitle: const Text('Save to Downloads'),
                onTap: () async {
                  Navigator.pop(context);
                  await _saveAsPdf(context, key);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsImage(BuildContext context, GlobalKey key) async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();
        if (androidInfo >= 33) {
          final status = await Permission.photos.request();
          if (!status.isGranted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Storage permission is required to save images',
                  ),
                ),
              );
            }
            return;
          }
        } else {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Storage permission is required to save images',
                  ),
                ),
              );
            }
            return;
          }
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photos permission is required to save images'),
              ),
            );
          }
          return;
        }
      }

      final bytes = await _capturePngBytes(key);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(bytes);

      await Gal.putImage(tempFile.path, album: Brand.current.appName);

      await tempFile.delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved to Gallery successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
      }
    }
  }

  Future<void> _saveAsPdf(BuildContext context, GlobalKey key) async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _getAndroidVersion();
        if (androidInfo >= 33) {
        } else {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Storage permission is required to save PDFs'),
                ),
              );
            }
            return;
          }
        }
      }

      final bytes = await _capturePngBytes(key);
      final doc = pw.Document();
      final image = pw.MemoryImage(Uint8List.fromList(bytes));
      doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Image(image))));

      final pdfBytes = await doc.save();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (Platform.isAndroid) {
        final downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);

        if (await downloadsDir.exists()) {
          final file = File('$downloadsPath/$fileName');
          await file.writeAsBytes(pdfBytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF saved to Downloads folder: $fileName'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/$fileName');
          await file.writeAsBytes(pdfBytes);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening share dialog...'),
                duration: Duration(seconds: 1),
              ),
            );
          }

          await Share.shareXFiles([
            XFile(file.path),
          ], text: '${Brand.current.appName} receipt');
        }
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        await Share.shareXFiles([
          XFile(file.path),
        ], text: '${Brand.current.appName} receipt');
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(pdfBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('PDF saved to ${file.path}')));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save PDF: $e')));
      }
    }
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      var androidInfo = await _getAndroidSdkVersion();
      return androidInfo;
    }
    return 0;
  }

  Future<int> _getAndroidSdkVersion() async {
    try {
      final String version = Platform.operatingSystemVersion;

      final match = RegExp(r'SDK (\d+)').firstMatch(version);
      if (match != null) {
        return int.parse(match.group(1)!);
      }

      return 33;
    } catch (_) {
      return 33;
    }
  }

  Future<void> _printReceipt(BuildContext context, GlobalKey key) async {
    try {
      final bytes = await _capturePngBytes(key);
      final doc = pw.Document();
      final image = pw.MemoryImage(Uint8List.fromList(bytes));
      doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Image(image))));

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await doc.save());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: '${Brand.current.appName} receipt');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share PDF: $e')));
      }
    }
  }

  Future<List<int>> _capturePngBytes(GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  List<Map<String, String>> _normalizePins(List<dynamic> raw) {
    final out = <Map<String, String>>[];
    for (final item in raw) {
      try {
        if (item is Map && item['fields'] is Map) {
          final f = Map<String, dynamic>.from(item['fields'] as Map);
          out.add({
            'pin': (f['pin'] ?? '').toString(),
            'serial': (f['serial'] ?? '').toString(),
            'load': (f['load_code'] ?? '').toString(),
          });
        } else if (item is Map &&
            item['model'] == 'vtuapp.result_checker_pin' &&
            item['fields'] is Map) {
          final f = Map<String, dynamic>.from(item['fields'] as Map);
          final rc = (f['result_checker_pin'] ?? '').toString();

          String pin = rc;
          String serial = '';
          if (rc.contains('<=serial>')) {
            final parts = rc.split('<=serial>');
            pin = parts.isNotEmpty
                ? parts.first.replaceAll('Pin:', '').trim()
                : '';
            serial = parts.length > 1 ? parts.last.trim() : '';
          } else if (rc.contains('<=>')) {
            final parts = rc.split('<=>');
            pin = parts.isNotEmpty
                ? parts.first.replaceAll('Pin:', '').trim()
                : '';
            serial = parts.length > 1 ? parts.last.trim() : '';
          }
          out.add({'pin': pin, 'serial': serial, 'load': ''});
        }
      } catch (_) {}
    }
    return out;
  }
}

class _VoucherCard extends StatelessWidget {
  final String logo;
  final String reference;
  final String name;
  final String pin;
  final String serial;
  final String amount;
  final String date;
  final Color color;

  const _VoucherCard({
    required this.logo,
    required this.reference,
    required this.name,
    required this.pin,
    required this.serial,
    required this.amount,
    required this.date,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'REF:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Text(reference),
                            ],
                          ),
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PIN:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SelectableText(
                              pin,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () async {
                              await Clipboard.setData(ClipboardData(text: pin));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('PIN copied')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text(
                            'S/N:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Text(serial),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Date:'),
                              const SizedBox(width: 6),
                              Text(date),
                            ],
                          ),
                          Text(
                            '₦$amount',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          '*123*PIN#',
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Image.asset(logo, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 3.0;

    _drawDashedLine(
      canvas,
      Offset(0, 0),
      Offset(size.width, 0),
      paint,
      dashWidth,
      dashSpace,
    );

    _drawDashedLine(
      canvas,
      Offset(size.width, 0),
      Offset(size.width, size.height),
      paint,
      dashWidth,
      dashSpace,
    );

    _drawDashedLine(
      canvas,
      Offset(size.width, size.height),
      Offset(0, size.height),
      paint,
      dashWidth,
      dashSpace,
    );

    _drawDashedLine(
      canvas,
      Offset(0, size.height),
      Offset(0, 0),
      paint,
      dashWidth,
      dashSpace,
    );
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashWidth,
    double dashSpace,
  ) {
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    double distance = 0;
    while (distance < totalLength) {
      final currentStart = start + direction * distance;
      final currentEnd =
          start + direction * (distance + dashWidth).clamp(0, totalLength);
      canvas.drawLine(currentStart, currentEnd, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ExamPinsReceiptScreen extends BaseReceiptScreen {
  final List<dynamic> pinEntries;
  const ExamPinsReceiptScreen({
    super.key,
    required super.item,
    required this.pinEntries,
  });

  @override
  Widget buildReceiptContent(BuildContext context) {
    final pins = _normalizeExamPins(pinEntries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  Utils.getAssetForExam(item.examName ?? ''),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${item.product?.toUpperCase() == 'WAEC'
                      ? 'WAEC'
                      : item.product?.toUpperCase() == 'NECO'
                      ? 'NECO'
                      : (item.product ?? item.service ?? 'Exam')} Pins',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.asset(
                  'assets/images/Logo_2.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount', style: TextStyle(color: Colors.grey)),
                Text(
                  '₦${item.amount}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusBg(item.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                item.status,
                style: TextStyle(
                  color: _statusColor(item.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _dividerRow('Transaction ID', item.id),
        _dividerRow('Status', item.status),
        _dividerRow('QTY', item.quantity ?? pins.length.toString()),
        _dividerRow('Product', item.product ?? (item.service ?? 'Exam')),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Pins', style: TextStyle(color: Colors.grey.shade500)),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${pins.length} PIN${pins.length == 1 ? '' : 's'} generated',
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final all = pins
                          .map((e) => e['formatted'])
                          .whereType<String>()
                          .join('\n');
                      await Clipboard.setData(ClipboardData(text: all));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All PINs copied')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy all'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final p in pins) _examPinRow(context, p),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _dividerRow('Previous Balance', '₦${item.balanceBefore}'),
        _dividerRow('New Balance', '₦${item.balanceAfter}'),
        _dividerRow('Transaction Date', _formatDate(item.timestamp)),
      ],
    );
  }

  @override
  List<pw.Widget> buildPdfContent() {
    final pins = _normalizeExamPins(pinEntries);
    final widgets = <pw.Widget>[
      pw.Text(
        'Exam PINs',
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Divider(),
      pw.Text('Transaction ID: ${item.id}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
      pw.Text('Product: ${item.product ?? (item.service ?? 'Exam')}'),
      pw.SizedBox(height: 4),
      pw.Divider(),
    ];
    for (final p in pins) {
      widgets.add(
        pw.Column(
          children: [
            pw.Text('PIN: ${p['pin'] ?? ''}'),
            if ((p['serial'] ?? '').isNotEmpty)
              pw.Text('Serial: ${p['serial']}'),
            pw.SizedBox(height: 6),
            pw.Divider(),
          ],
        ),
      );
    }
    return widgets;
  }

  List<Map<String, String>> _normalizeExamPins(List<dynamic> raw) {
    final out = <Map<String, String>>[];
    for (final item in raw) {
      try {
        if (item is Map && item['fields'] is Map) {
          final f = Map<String, dynamic>.from(item['fields'] as Map);
          final rc = (f['result_checker_pin'] ?? '').toString();
          String pin = rc;
          String serial = '';
          if (rc.contains('<=serial>')) {
            final parts = rc.split('<=serial>');
            pin = parts.isNotEmpty
                ? parts.first.replaceAll('Pin:', '').trim()
                : '';
            serial = parts.length > 1 ? parts.last.trim() : '';
          } else if (rc.contains('<=>')) {
            final parts = rc.split('<=>');
            pin = parts.isNotEmpty
                ? parts.first.replaceAll('Pin:', '').trim()
                : '';
            serial = parts.length > 1 ? parts.last.trim() : '';
          }
          out.add({
            'pin': pin,
            'serial': serial,
            'formatted': serial.isNotEmpty ? '$pin <=serial> $serial' : pin,
          });
        }
      } catch (_) {}
    }
    return out;
  }

  Widget _examPinRow(BuildContext ctx, Map<String, String> p) {
    final formatted = p['formatted'] ?? p['pin'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              formatted,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: formatted));
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(const SnackBar(content: Text('PIN copied')));
              }
            },
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
    );
  }
}
