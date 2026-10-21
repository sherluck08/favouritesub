import 'package:flutter/material.dart';

/// App-independent status values used by [PortableTransactionHistory].
enum TransactionHistoryStatus { successful, processing, failed, unknown }

class TransactionHistoryFilter {
  const TransactionHistoryFilter({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// A provider- and model-independent transaction history UI.
///
/// This widget can be copied into another Flutter project unchanged. Connect
/// any transaction model through the mapper callbacks and keep API, provider,
/// navigation, assets, and currency decisions in the host app.
class PortableTransactionHistory<T> extends StatefulWidget {
  const PortableTransactionHistory({
    super.key,
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.amountOf,
    required this.dateOf,
    required this.statusOf,
    required this.statusLabelOf,
    required this.searchTextOf,
    required this.onItemTap,
    required this.onRefresh,
    this.assetOf,
    this.fallbackIconOf,
    this.filters = const [],
    this.selectedFilterId,
    this.onFilterChanged,
    this.onLoadMore,
    this.isInitialLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorMessage,
    this.showSummary = true,
    this.summaryLabel = 'Successful volume',
    this.summaryValue = '₦0',
    this.emptyTitle = 'No transactions yet',
    this.emptyMessage = 'Your completed purchases will appear here.',
  });

  final List<T> items;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final String Function(T) amountOf;
  final DateTime Function(T) dateOf;
  final TransactionHistoryStatus Function(T) statusOf;
  final String Function(T) statusLabelOf;
  final String Function(T) searchTextOf;
  final String? Function(T)? assetOf;
  final IconData Function(T)? fallbackIconOf;
  final ValueChanged<T> onItemTap;
  final Future<void> Function() onRefresh;
  final List<TransactionHistoryFilter> filters;
  final String? selectedFilterId;
  final ValueChanged<String?>? onFilterChanged;
  final Future<void> Function()? onLoadMore;
  final bool isInitialLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final bool showSummary;
  final String summaryLabel;
  final String summaryValue;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<PortableTransactionHistory<T>> createState() =>
      _PortableTransactionHistoryState<T>();
}

class _PortableTransactionHistoryState<T>
    extends State<PortableTransactionHistory<T>> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  bool _requestingMore = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(_rebuild);
    _scroll.addListener(_loadMore);
  }

  @override
  void dispose() {
    _search
      ..removeListener(_rebuild)
      ..dispose();
    _scroll
      ..removeListener(_loadMore)
      ..dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _loadMore() async {
    if (!_scroll.hasClients ||
        _scroll.position.extentAfter > 280 ||
        _requestingMore ||
        widget.isLoadingMore ||
        !widget.hasMore ||
        widget.onLoadMore == null) {
      return;
    }
    _requestingMore = true;
    try {
      await widget.onLoadMore!();
    } finally {
      _requestingMore = false;
    }
  }

  List<T> get _visibleItems {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.items;
    return widget.items
        .where(
          (item) => widget.searchTextOf(item).toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 380 ? 14.0 : 20.0;
    final items = _visibleItems;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView(
        key: const PageStorageKey('portable-transaction-history'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(padding, 10, padding, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showSummary) ...[
                    _SummaryCard(
                      label: widget.summaryLabel,
                      value: widget.summaryValue,
                      count: widget.items.length,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _SearchField(controller: _search),
                  if (widget.filters.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _FilterStrip(
                      filters: widget.filters,
                      selectedId: widget.selectedFilterId,
                      onChanged: widget.onFilterChanged,
                    ),
                  ],
                  if (widget.errorMessage?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    _ErrorBanner(onRetry: widget.onRefresh),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _search.text.trim().isEmpty
                              ? 'Activity'
                              : 'Search results',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (!widget.isInitialLoading)
                        Text(
                          '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (widget.isInitialLoading && widget.items.isEmpty)
                    const _LoadingList()
                  else if (items.isEmpty)
                    _EmptyState(
                      searching: _search.text.trim().isNotEmpty,
                      title: widget.emptyTitle,
                      message: widget.emptyMessage,
                      onClear: _search.clear,
                    )
                  else
                    _GroupedList<T>(
                      items: items,
                      titleOf: widget.titleOf,
                      subtitleOf: widget.subtitleOf,
                      amountOf: widget.amountOf,
                      dateOf: widget.dateOf,
                      statusOf: widget.statusOf,
                      statusLabelOf: widget.statusLabelOf,
                      assetOf: widget.assetOf,
                      fallbackIconOf: widget.fallbackIconOf,
                      onTap: widget.onItemTap,
                    ),
                  if (widget.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.count,
  });

  final String label;
  final String value;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = colors.onPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary,
            Color.lerp(colors.primary, Colors.black, .28)!,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: .18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: foreground.withValues(alpha: .72),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  '$count loaded ${count == 1 ? 'transaction' : 'transactions'}',
                  style: TextStyle(
                    color: foreground.withValues(alpha: .68),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.insights_rounded, color: foreground, size: 27),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search amount, recipient or service',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
          fillColor: colors.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.filters,
    required this.selectedId,
    required this.onChanged,
  });
  final List<TransactionHistoryFilter> filters;
  final String? selectedId;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final all = [
      const TransactionHistoryFilter(
        id: '__all__',
        label: 'All',
        icon: Icons.grid_view_rounded,
      ),
      ...filters,
    ];
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = all[index];
          final selected = filter.id == '__all__'
              ? selectedId == null
              : selectedId == filter.id;
          return _FilterChip(
            filter: filter,
            selected: selected,
            onTap: onChanged == null
                ? null
                : () => onChanged!(filter.id == '__all__' ? null : filter.id),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });
  final TransactionHistoryFilter filter;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primary : colors.surfaceContainerLowest,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filter.icon,
                size: 15,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                filter.label,
                style: TextStyle(
                  color: selected ? colors.onPrimary : colors.onSurface,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupedList<T> extends StatelessWidget {
  const _GroupedList({
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.amountOf,
    required this.dateOf,
    required this.statusOf,
    required this.statusLabelOf,
    required this.assetOf,
    required this.fallbackIconOf,
    required this.onTap,
  });

  final List<T> items;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final String Function(T) amountOf;
  final DateTime Function(T) dateOf;
  final TransactionHistoryStatus Function(T) statusOf;
  final String Function(T) statusLabelOf;
  final String? Function(T)? assetOf;
  final IconData Function(T)? fallbackIconOf;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    String? previousGroup;
    for (final item in items) {
      final group = _dateGroup(dateOf(item));
      if (group != previousGroup) {
        if (children.isNotEmpty) children.add(const SizedBox(height: 18));
        children.add(
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              group,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        previousGroup = group;
      }
      children.add(const SizedBox(height: 9));
      children.add(
        _TransactionCard(
          title: titleOf(item),
          subtitle: subtitleOf(item),
          amount: amountOf(item),
          date: dateOf(item),
          status: statusOf(item),
          statusLabel: statusLabelOf(item),
          asset: assetOf?.call(item),
          fallbackIcon:
              fallbackIconOf?.call(item) ?? Icons.receipt_long_rounded,
          onTap: () => onTap(item),
        ),
      );
    }
    return Column(children: children);
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.status,
    required this.statusLabel,
    required this.asset,
    required this.fallbackIcon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String amount;
  final DateTime date;
  final TransactionHistoryStatus status;
  final String statusLabel;
  final String? asset;
  final IconData fallbackIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(status, colors);
    final fallback = Icon(fallbackIcon, size: 21, color: colors.primary);
    return Semantics(
      button: true,
      label: '$title, $amount, $statusLabel',
      child: Material(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(19),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .55),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: asset?.trim().isNotEmpty == true
                      ? Image.asset(
                          asset!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => fallback,
                        )
                      : fallback,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _time(date),
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 105),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        amount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant.withValues(alpha: .55),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: colors.onErrorContainer,
            size: 19,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'Could not update history. Showing available records.',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.searching,
    required this.title,
    required this.message,
    required this.onClear,
  });
  final bool searching;
  final String title;
  final String message;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                searching
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_rounded,
                color: colors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              searching ? 'No matching transactions' : title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 7),
            Text(
              searching
                  ? 'Try another amount, recipient, service or status.'
                  : message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
            ),
            if (searching)
              TextButton(onPressed: onClear, child: const Text('Clear search')),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: List.generate(
        5,
        (_) => Container(
          height: 76,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(19),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _block(46, 46, color),
              const SizedBox(width: 12),
              Expanded(child: _block(120, 11, color)),
              _block(70, 24, color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _block(double width, double height, Color color) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
  );
}

Color _statusColor(TransactionHistoryStatus status, ColorScheme colors) {
  return switch (status) {
    TransactionHistoryStatus.successful => const Color(0xFF14805E),
    TransactionHistoryStatus.processing => const Color(0xFFC2730A),
    TransactionHistoryStatus.failed => colors.error,
    TransactionHistoryStatus.unknown => colors.onSurfaceVariant,
  };
}

String _dateGroup(DateTime value) {
  final date = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  final label = '${_months[date.month - 1]} ${date.day}';
  return date.year == now.year ? label : '$label, ${date.year}';
}

String _time(DateTime value) {
  final date = value.toLocal();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${date.minute.toString().padLeft(2, '0')} '
      '${date.hour >= 12 ? 'PM' : 'AM'}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
