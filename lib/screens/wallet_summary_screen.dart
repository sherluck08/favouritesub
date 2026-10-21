import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:favouritesub/providers/wallet_summary_provider.dart';

class WalletSummaryScreen extends StatefulWidget {
  const WalletSummaryScreen({super.key});

  @override
  State<WalletSummaryScreen> createState() => _WalletSummaryScreenState();
}

class _WalletSummaryScreenState extends State<WalletSummaryScreen> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          Provider.of<WalletSummaryProvider>(context, listen: false).refresh(),
    );
    _controller.addListener(() {
      final p = Provider.of<WalletSummaryProvider>(context, listen: false);
      if (_controller.position.pixels >=
              _controller.position.maxScrollExtent - 120 &&
          !p.isLoadingMore &&
          p.hasMore) {
        p.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_NG', symbol: '₦');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet History'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Consumer<WalletSummaryProvider>(
        builder: (context, p, _) {
          if (p.isLoading && p.items.isEmpty) {
            return const _LoadingList();
          }
          return RefreshIndicator(
            onRefresh: p.refresh,
            child: ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.all(16),
              itemCount: 2 + p.items.length + (p.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _SearchBar(
                    onChanged: (v) {
                      Provider.of<WalletSummaryProvider>(
                        context,
                        listen: false,
                      ).setQuery(v.trim());
                    },
                  );
                }
                if (index == 1) {
                  return const SizedBox(height: 12);
                }
                final i = index - 2;
                if (i < p.items.length) {
                  final item = p.items[i];
                  final isCredit = item.afterBalance >= item.previousBalance;
                  final asset = _resolveNetworkAsset(item.product);
                  return _WalletTile(
                    title: item.product,
                    amountText: currency.format(item.amount),
                    dateText: DateFormat(
                      'yyyy-MM-dd – hh:mm a',
                    ).format(item.createdAt),
                    prevBalance: currency.format(item.previousBalance),
                    newBalance: currency.format(item.afterBalance),
                    isCredit: isCredit,
                    leadingAsset: asset,
                  );
                }
                if (p.isLoadingMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search',
                border: InputBorder.none,
              ),
            ),
          ),
          Icon(Icons.search, color: Colors.grey.shade700),
        ],
      ),
    );
  }
}

class _WalletTile extends StatelessWidget {
  final String title;
  final String amountText;
  final String dateText;
  final String prevBalance;
  final String newBalance;
  final bool isCredit;
  final String? leadingAsset;

  const _WalletTile({
    required this.title,
    required this.amountText,
    required this.dateText,
    required this.prevBalance,
    required this.newBalance,
    required this.isCredit,
    this.leadingAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade50,
                child: leadingAsset != null
                    ? Image.asset(
                        leadingAsset!,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      )
                    : Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? Colors.green : Colors.red,
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateText,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                amountText,
                style: TextStyle(
                  color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prev Balance: $prevBalance',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
              Expanded(
                child: Text(
                  'New Balance: $newBalance',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _resolveNetworkAsset(String product) {
  final s = product.toLowerCase();
  if (s.contains('mtn')) return 'assets/images/mtn_logo.png';
  if (s.contains('glo')) return 'assets/images/glo_logo.png';
  if (s.contains('airtel')) return 'assets/images/airtel_logo.png';
  if (s.contains('9mobile') ||
      s.contains('9 mobile') ||
      s.contains('etisalat')) {
    return 'assets/images/9mobile_logo.png';
  }
  return null;
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => _shimmerCard(),
    );
  }

  Widget _shimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 12, width: 160, color: Colors.grey.shade200),
                const SizedBox(height: 8),
                Container(height: 10, width: 100, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(height: 10, color: Colors.grey.shade200),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(height: 10, color: Colors.grey.shade200),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
