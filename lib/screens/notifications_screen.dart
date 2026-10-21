import 'package:favouritesub/services/notification_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class _NCol {
  static const bg = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const text = Color(0xFF0F172A);
  static const textSub = Color(0xFF64748B);
  static const border = Color(0xFFE5E7EB);
  static const accent = Color(0xFF3B82F6);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
  static const cashback = Color(0xFFE07C00);
  static const announcement = Color(0xFF3B82F6);
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationStore.instance.syncFromBackend();
    });
  }

  Future<void> _refresh() async {
    final synced = await NotificationStore.instance.syncFromBackend();
    if (!mounted || synced) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not refresh. Showing saved notifications.'),
      ),
    );
  }

  Future<void> _openNotification(
    AppNotification item,
    NotificationStore store,
  ) async {
    await store.markAsRead(item.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _NotificationDetails(item: item.copyWith(read: true)),
    );
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear all notifications?',
          style: TextStyle(
            color: _NCol.text,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        content: const Text(
          'This will permanently remove every notification from your inbox.',
          style: TextStyle(color: _NCol.textSub, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _NCol.textSub,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear all',
              style: TextStyle(
                color: _NCol.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NotificationStore.instance.clearAll();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notifications cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _NCol.bg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Consumer<NotificationStore>(
            builder: (_, store, __) {
              if (store.items.isEmpty) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                tooltip: 'More',
                position: PopupMenuPosition.under,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                onSelected: (v) async {
                  if (v == 'read') {
                    await store.markAllAsRead();
                  } else if (v == 'clear') {
                    await _confirmClearAll();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'read',
                    child: _MenuRow(
                      icon: Icons.done_all_rounded,
                      label: 'Mark all as read',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: _MenuRow(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Clear all',
                      danger: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: _NCol.border),
        ),
      ),
      body: Consumer<NotificationStore>(
        builder: (_, store, __) {
          final items = store.items;
          return Column(
            children: [
              if (store.isSyncing)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: Theme.of(context).primaryColor,
                  backgroundColor: _NCol.border,
                )
              else
                const SizedBox(height: 2),
              Expanded(
                child: items.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _refresh,
                        child: const _EmptyState(),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: Builder(
                          builder: (_) {
                            final groups = _groupByDate(items);
                            return ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                              itemCount: groups.length,
                              itemBuilder: (_, i) {
                                final g = groups[i];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        16,
                                        4,
                                        8,
                                      ),
                                      child: Text(
                                        g.label,
                                        style: const TextStyle(
                                          color: _NCol.textSub,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: _NCol.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: _NCol.border),
                                      ),
                                      child: Column(
                                        children: [
                                          for (
                                            var j = 0;
                                            j < g.items.length;
                                            j++
                                          ) ...[
                                            _NotificationTile(
                                              item: g.items[j],
                                              onTap: () => _openNotification(
                                                g.items[j],
                                                store,
                                              ),
                                              onDismissed: () =>
                                                  store.remove(g.items[j].id),
                                            ),
                                            if (j != g.items.length - 1)
                                              const Divider(
                                                height: 1,
                                                thickness: 1,
                                                indent: 64,
                                                color: _NCol.border,
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? _NCol.danger : _NCol.text;
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = _kindColor(item.kind);
    final iconData = _kindIcon(item.kind);
    final unread = !item.read;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        color: const Color(0xFFFFEAEA),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline_rounded, color: _NCol.danger, size: 22),
            SizedBox(width: 6),
            Text(
              'Delete',
              style: TextStyle(
                color: _NCol.danger,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(iconData, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _NCol.text,
                                fontSize: 14,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTime(item.createdAt),
                            style: const TextStyle(
                              color: _NCol.textSub,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _NCol.textSub,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: _NCol.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _NCol.accent.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: _NCol.accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications yet',
                    style: TextStyle(
                      color: _NCol.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "We'll let you know when something important happens — purchases, cashback, and updates will show up here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _NCol.textSub,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationDetails extends StatelessWidget {
  final AppNotification item;

  const _NotificationDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final iconColor = _kindColor(item.kind);
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomPadding),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _NCol.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_kindIcon(item.kind), color: iconColor, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: const TextStyle(
                          color: _NCol.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _formatFullTimestamp(item.createdAt),
                        style: const TextStyle(
                          color: _NCol.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Text(
                  item.body,
                  style: const TextStyle(
                    color: _NCol.text,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group {
  final String label;
  final List<AppNotification> items;
  _Group(this.label, this.items);
}

List<_Group> _groupByDate(List<AppNotification> items) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekAgo = today.subtract(const Duration(days: 7));

  final todayList = <AppNotification>[];
  final yLis = <AppNotification>[];
  final week = <AppNotification>[];
  final older = <AppNotification>[];

  for (final n in items) {
    final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
    if (!d.isBefore(today)) {
      todayList.add(n);
    } else if (!d.isBefore(yesterday)) {
      yLis.add(n);
    } else if (!d.isBefore(weekAgo)) {
      week.add(n);
    } else {
      older.add(n);
    }
  }

  final out = <_Group>[];
  if (todayList.isNotEmpty) out.add(_Group('Today', todayList));
  if (yLis.isNotEmpty) out.add(_Group('Yesterday', yLis));
  if (week.isNotEmpty) out.add(_Group('This week', week));
  if (older.isNotEmpty) out.add(_Group('Earlier', older));
  return out;
}

String _formatTime(DateTime t) {
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final m = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  return '$d/$m';
}

String _formatFullTimestamp(DateTime value) {
  const months = [
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
  final time = value.toLocal();
  final hour = time.hour == 0
      ? 12
      : (time.hour > 12 ? time.hour - 12 : time.hour);
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '${time.day} ${months[time.month - 1]} ${time.year} · $hour:$minute $period';
}

IconData _kindIcon(AppNotificationKind k) {
  switch (k) {
    case AppNotificationKind.transactionSuccess:
      return Icons.check_circle_outline_rounded;
    case AppNotificationKind.transactionProcessing:
      return Icons.hourglass_top_rounded;
    case AppNotificationKind.transactionFailed:
      return Icons.error_outline_rounded;
    case AppNotificationKind.cashback:
      return Icons.card_giftcard_rounded;
    case AppNotificationKind.announcement:
      return Icons.campaign_rounded;
    case AppNotificationKind.system:
      return Icons.info_outline_rounded;
    case AppNotificationKind.generic:
      return Icons.notifications_none_rounded;
  }
}

Color _kindColor(AppNotificationKind k) {
  switch (k) {
    case AppNotificationKind.transactionSuccess:
      return _NCol.success;
    case AppNotificationKind.transactionProcessing:
      return _NCol.warning;
    case AppNotificationKind.transactionFailed:
      return _NCol.danger;
    case AppNotificationKind.cashback:
      return _NCol.cashback;
    case AppNotificationKind.announcement:
      return _NCol.announcement;
    case AppNotificationKind.system:
      return _NCol.accent;
    case AppNotificationKind.generic:
      return _NCol.accent;
  }
}
