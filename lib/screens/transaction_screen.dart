import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_item.dart';
import '../providers/transaction_provider.dart';
import '../widgets/portable_transaction_history.dart';
import '../widgets/transaction_list_item.dart';
import 'specialized_receipt_screens.dart';
import 'transaction_receipt_screen.dart';

class TransactionScreen extends StatefulWidget {
  const TransactionScreen({super.key});

  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  TransactionProvider? _transactions;

  static const _filters = [
    TransactionHistoryFilter(
      id: 'data',
      label: 'Data',
      icon: Icons.wifi_rounded,
    ),
    TransactionHistoryFilter(
      id: 'airtime',
      label: 'Airtime',
      icon: Icons.phone_android_rounded,
    ),
    TransactionHistoryFilter(
      id: 'cable',
      label: 'Cable TV',
      icon: Icons.live_tv_rounded,
    ),
    TransactionHistoryFilter(
      id: 'electricity',
      label: 'Electricity',
      icon: Icons.bolt_rounded,
    ),
    TransactionHistoryFilter(
      id: 'rechargeCard',
      label: 'Recharge PIN',
      icon: Icons.pin_rounded,
    ),
    TransactionHistoryFilter(
      id: 'exam',
      label: 'Exam PIN',
      icon: Icons.school_rounded,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_transactions != null) return;
    _transactions = context.read<TransactionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _transactions!.refresh();
    });
  }

  @override
  void dispose() {
    // A category request replaces the provider's list. Restore the combined
    // feed when leaving so dashboard "Recent activity" is not left filtered.
    if (_transactions?.selectedFilter != null) {
      _transactions?.setFilter(null);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: Navigator.of(context).canPop() ? 4 : 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Payments and purchases',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactions, _) {
          final items = transactions.items.toList(growable: false)
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return PortableTransactionHistory<TransactionItem>(
            items: items,
            titleOf: getTransactionDisplayText,
            subtitleOf: _subtitle,
            amountOf: (item) => _money(item.amount),
            dateOf: (item) => item.timestamp,
            statusOf: (item) => _status(item.status),
            statusLabelOf: (item) => _statusLabel(item.status),
            searchTextOf: (item) => [
              item.id,
              item.networkName,
              item.planSize,
              item.planType,
              item.status,
              item.amount,
              item.mobileNumber,
              item.meterNumber,
              item.smartCardNumber,
              item.packageName,
              item.examName,
            ].whereType<String>().join(' '),
            assetOf: (item) =>
                getAssetForTransactionType(item.transactionType, item),
            fallbackIconOf: (item) => _iconFor(item.transactionType),
            onItemTap: (item) => _openReceipt(context, item),
            onRefresh: transactions.refresh,
            onLoadMore: transactions.loadMore,
            filters: _filters,
            selectedFilterId: transactions.selectedFilter?.name,
            onFilterChanged: transactions.isLoading
                ? null
                : (id) => transactions.setFilter(
                    id == null ? null : TransactionType.values.byName(id),
                  ),
            isInitialLoading: transactions.isLoading,
            isLoadingMore: transactions.isLoadingMore,
            hasMore: transactions.hasMore,
            errorMessage: transactions.error,
            showSummary: false,
          );
        },
      ),
    );
  }

  Future<void> _openReceipt(BuildContext context, TransactionItem item) async {
    final Widget receipt = switch (item.transactionType) {
      TransactionType.electricity => ElectricityReceiptScreen(item: item),
      TransactionType.airtime => AirtimeReceiptScreen(item: item),
      TransactionType.cable => CableReceiptScreen(item: item),
      TransactionType.rechargeCard => RechargeCardPinsReceiptScreen(
        item: item,
        pinEntries: item.pinEntries ?? _extractPinEntries(item),
      ),
      TransactionType.exam => ExamPinsReceiptScreen(
        item: item,
        pinEntries: item.pinEntries ?? const [],
      ),
      _ => TransactionReceiptScreen(item: item),
    };

    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => receipt));
  }
}

List<dynamic> _extractPinEntries(TransactionItem item) {
  final pins = item.pins
      ?.split('\n')
      .map((pin) => pin.trim())
      .where((pin) => pin.isNotEmpty);
  if (pins == null) return const [];
  return pins
      .map(
        (pin) => {
          'fields': {'pin': pin, 'serial': '', 'load_code': ''},
        },
      )
      .toList(growable: false);
}

String _subtitle(TransactionItem item) {
  final reference = switch (item.transactionType) {
    TransactionType.electricity => item.meterNumber ?? item.mobileNumber,
    TransactionType.cable => item.smartCardNumber ?? item.mobileNumber,
    TransactionType.rechargeCard =>
      item.quantity == null
          ? item.mobileNumber
          : '${item.quantity} PIN${item.quantity == '1' ? '' : 's'}',
    TransactionType.exam =>
      item.quantity == null
          ? item.examName ?? ''
          : '${item.quantity} PIN${item.quantity == '1' ? '' : 's'}',
    _ => item.mobileNumber,
  };
  return reference.trim().isEmpty ? 'Tap to view receipt' : reference.trim();
}

TransactionHistoryStatus _status(String raw) {
  final value = raw.trim().toLowerCase();
  if (value == 'successful' || value == 'success' || value == 'completed') {
    return TransactionHistoryStatus.successful;
  }
  if (value == 'processing' || value == 'pending' || value == 'initiated') {
    return TransactionHistoryStatus.processing;
  }
  if (value == 'failed' || value == 'failure' || value == 'reversed') {
    return TransactionHistoryStatus.failed;
  }
  return TransactionHistoryStatus.unknown;
}

String _statusLabel(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'Unknown';
  return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
}

double _number(String raw) {
  return double.tryParse(raw.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
}

String _money(String raw) {
  final value = _number(raw);
  final fixed = value.toStringAsFixed(
    value.truncateToDouble() == value ? 0 : 2,
  );
  final parts = fixed.split('.');
  final formatted = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '₦$formatted${parts.length == 2 ? '.${parts.last}' : ''}';
}

IconData _iconFor(TransactionType type) => switch (type) {
  TransactionType.data => Icons.wifi_rounded,
  TransactionType.airtime => Icons.phone_android_rounded,
  TransactionType.cable => Icons.live_tv_rounded,
  TransactionType.electricity => Icons.bolt_rounded,
  TransactionType.rechargeCard => Icons.pin_rounded,
  TransactionType.exam => Icons.school_rounded,
  TransactionType.sms => Icons.sms_rounded,
};
