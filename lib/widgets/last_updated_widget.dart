import 'package:flutter/material.dart';

/// A reusable widget that displays last updated time with an optional refresh button
///
/// Usage:
/// ```dart
/// LastUpdatedWidget(
///   lastUpdateTime: _lastBalanceUpdateTime,
///   onRefresh: _manualRefreshBalance,
///   isRefreshing: _isManuallyRefreshing,
///   getTimeAgo: _getTimeAgo, // Optional: provide your own formatter
/// )
/// ```
class LastUpdatedWidget extends StatelessWidget {
  final DateTime? lastUpdateTime;
  final VoidCallback? onRefresh;
  final bool isRefreshing;
  final String Function(DateTime?)? getTimeAgo;
  final EdgeInsetsGeometry? padding;
  final String refreshText;
  final String updatePrefix;
  final Color? timeColor;
  final Color? refreshColor;
  final double iconSize;
  final double fontSize;

  const LastUpdatedWidget({
    super.key,
    required this.lastUpdateTime,
    this.onRefresh,
    this.isRefreshing = false,
    this.getTimeAgo,
    this.padding,
    this.refreshText = 'Refresh',
    this.updatePrefix = 'Updated',
    this.timeColor,
    this.refreshColor,
    this.iconSize = 14.0,
    this.fontSize = 12.0,
  });

  String _defaultTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Never';

    final difference = DateTime.now().difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatter = getTimeAgo ?? _defaultTimeAgo;
    final theme = Theme.of(context);
    final defaultTimeColor = timeColor ?? Colors.grey.shade600;
    final defaultRefreshColor = refreshColor ?? theme.colorScheme.primary;

    return Padding(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Icon(Icons.access_time, size: iconSize, color: defaultTimeColor),
          const SizedBox(width: 4),
          Text(
            '$updatePrefix ${timeFormatter(lastUpdateTime)}',
            style: TextStyle(fontSize: fontSize, color: defaultTimeColor),
          ),
          if (onRefresh != null) ...[
            const Spacer(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isRefreshing ? null : onRefresh,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isRefreshing)
                        SizedBox(
                          width: iconSize,
                          height: iconSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              defaultRefreshColor,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.refresh,
                          size: iconSize + 2,
                          color: defaultRefreshColor,
                        ),
                      const SizedBox(width: 4),
                      Text(
                        refreshText,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: defaultRefreshColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
