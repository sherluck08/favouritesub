import 'dart:async';
import 'package:flutter/material.dart';

/// A reusable mixin for tracking data refresh times and managing refresh intervals
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with RefreshTrackerMixin {
///   @override
///   void initState() {
///     super.initState();
///     startRefreshTimer(); // Start the timer for UI updates
///     // Your initialization code
///   }
///
///   @override
///   void dispose() {
///     disposeRefreshTimer(); // Clean up the timer
///     super.dispose();
///   }
/// }
/// ```
mixin RefreshTrackerMixin<T extends StatefulWidget> on State<T> {
  DateTime? _lastRefreshTime;
  Timer? _refreshUpdateTimer;

  /// Minimum interval between automatic refreshes (default: 30 seconds)
  Duration get minRefreshInterval => const Duration(seconds: 30);

  /// Minimum interval between manual refreshes (default: 5 seconds)
  Duration get minManualRefreshInterval => const Duration(seconds: 5);

  /// Get the last refresh time
  DateTime? get lastRefreshTime => _lastRefreshTime;

  /// Set the last refresh time
  set lastRefreshTime(DateTime? value) => _lastRefreshTime = value;

  /// Check if enough time has passed since last refresh
  bool canRefresh({bool isManual = false}) {
    if (_lastRefreshTime == null) return true;

    final interval = isManual ? minManualRefreshInterval : minRefreshInterval;
    final elapsed = DateTime.now().difference(_lastRefreshTime!);
    return elapsed >= interval;
  }

  /// Get remaining time until next refresh is allowed
  Duration getRemainingCooldown({bool isManual = false}) {
    if (_lastRefreshTime == null) return Duration.zero;

    final interval = isManual ? minManualRefreshInterval : minRefreshInterval;
    final elapsed = DateTime.now().difference(_lastRefreshTime!);
    final remaining = interval - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Format a DateTime as a human-readable "time ago" string
  String getTimeAgo(DateTime? dateTime) {
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

  /// Start a periodic timer to update the UI every minute
  /// This keeps the "time ago" text current without re-fetching data
  void startRefreshTimer() {
    _refreshUpdateTimer?.cancel();
    _refreshUpdateTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Cancel the refresh timer
  void disposeRefreshTimer() {
    _refreshUpdateTimer?.cancel();
    _refreshUpdateTimer = null;
  }

  /// Mark the current time as last refresh time and update UI
  void markRefreshed() {
    if (mounted) {
      setState(() {
        _lastRefreshTime = DateTime.now();
      });
    }
  }
}
