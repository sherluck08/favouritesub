import 'package:flutter/material.dart';

/// Helper class for managing refresh operations with cooldown and error handling
class RefreshHelper {
  /// Execute a refresh operation with built-in cooldown checking and error handling
  ///
  /// Usage:
  /// ```dart
  /// await RefreshHelper.executeRefresh(
  ///   context: context,
  ///   lastRefreshTime: _lastRefreshTime,
  ///   minInterval: Duration(seconds: 5),
  ///   onRefresh: () async {
  ///     await myDataProvider.loadData();
  ///   },
  ///   onSuccess: () {
  ///     setState(() => _lastRefreshTime = DateTime.now());
  ///   },
  ///   successMessage: 'Data updated successfully',
  /// );
  /// ```
  static Future<bool> executeRefresh({
    required BuildContext context,
    required Future<void> Function() onRefresh,
    DateTime? lastRefreshTime,
    Duration minInterval = const Duration(seconds: 5),
    VoidCallback? onSuccess,
    VoidCallback? onError,
    String? successMessage,
    String? errorMessage,
    bool showSuccessSnackBar = true,
    bool showErrorSnackBar = true,
  }) async {
    // Check cooldown
    if (lastRefreshTime != null) {
      final elapsed = DateTime.now().difference(lastRefreshTime);
      if (elapsed < minInterval) {
        final remaining = minInterval.inSeconds - elapsed.inSeconds;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please wait $remaining seconds between refreshes'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }
    }

    try {
      await onRefresh();

      if (context.mounted) {
        onSuccess?.call();

        if (showSuccessSnackBar) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(successMessage ?? 'Updated successfully'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        onError?.call();

        if (showErrorSnackBar) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage ?? 'Failed to refresh: ${e.toString()}',
              ),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return false;
    }
  }

  /// Format a DateTime as a human-readable "time ago" string
  static String formatTimeAgo(DateTime? dateTime) {
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

  /// Check if enough time has elapsed since last refresh
  static bool canRefresh(DateTime? lastRefreshTime, Duration minInterval) {
    if (lastRefreshTime == null) return true;
    final elapsed = DateTime.now().difference(lastRefreshTime);
    return elapsed >= minInterval;
  }

  /// Get remaining cooldown time
  static Duration getRemainingCooldown(
    DateTime? lastRefreshTime,
    Duration minInterval,
  ) {
    if (lastRefreshTime == null) return Duration.zero;

    final elapsed = DateTime.now().difference(lastRefreshTime);
    final remaining = minInterval - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}
