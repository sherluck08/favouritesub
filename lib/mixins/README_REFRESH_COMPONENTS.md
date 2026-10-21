# Reusable Refresh Components

This package contains reusable, production-grade components for managing data refresh with intelligent cooldown, time tracking, and user-friendly UI.

## Components

### 1. `RefreshTrackerMixin` (Mixin)
**File:** `lib/mixins/refresh_tracker_mixin.dart`

A mixin that provides data refresh tracking and management capabilities.

#### Features:
- ✅ Tracks last refresh time
- ✅ Enforces minimum refresh intervals
- ✅ Human-readable "time ago" formatting
- ✅ Auto-updating UI timer
- ✅ Configurable cooldown periods

#### Usage:

```dart
class _MyScreenState extends State<MyScreen> with RefreshTrackerMixin {
  @override
  void initState() {
    super.initState();
    startRefreshTimer(); // Start the periodic UI update timer
    _loadData();
  }

  @override
  void dispose() {
    disposeRefreshTimer(); // Clean up the timer
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!canRefresh()) return; // Check if cooldown has passed
    
    // Your data loading logic
    await myDataProvider.load();
    
    markRefreshed(); // Mark current time as last refresh
  }

  @override
  Widget build(BuildContext context) {
    return Text('Last updated: ${getTimeAgo(lastRefreshTime)}');
  }
}
```

#### Customization:

```dart
// Override default intervals
@override
Duration get minRefreshInterval => const Duration(seconds: 30);

@override
Duration get minManualRefreshInterval => const Duration(seconds: 5);
```

#### Methods:

| Method | Description |
|--------|-------------|
| `canRefresh({bool isManual})` | Check if enough time has passed since last refresh |
| `getRemainingCooldown({bool isManual})` | Get remaining time until next refresh is allowed |
| `getTimeAgo(DateTime?)` | Format DateTime as "2 minutes ago", "Just now", etc. |
| `startRefreshTimer()` | Start periodic timer to update UI every minute |
| `disposeRefreshTimer()` | Cancel the periodic timer |
| `markRefreshed()` | Mark current time as last refresh time |

---

### 2. `LastUpdatedWidget` (Widget)
**File:** `lib/widgets/last_updated_widget.dart`

A reusable widget that displays last updated time with an optional refresh button.

#### Features:
- ✅ Shows "Updated X minutes ago"
- ✅ Optional refresh button
- ✅ Loading state with spinner
- ✅ Fully customizable appearance
- ✅ Built-in time formatting

#### Basic Usage:

```dart
LastUpdatedWidget(
  lastUpdateTime: _lastBalanceUpdateTime,
  onRefresh: _manualRefreshBalance,
  isRefreshing: _isManuallyRefreshing,
)
```

#### Advanced Usage:

```dart
LastUpdatedWidget(
  lastUpdateTime: _lastBalanceUpdateTime,
  onRefresh: _manualRefreshBalance,
  isRefreshing: _isManuallyRefreshing,
  getTimeAgo: myCustomFormatter, // Custom time formatter
  refreshText: 'Reload',
  updatePrefix: 'Last checked',
  timeColor: Colors.grey,
  refreshColor: Colors.blue,
  iconSize: 16.0,
  fontSize: 14.0,
  padding: EdgeInsets.all(8.0),
)
```

#### Properties:

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `lastUpdateTime` | `DateTime?` | Yes | - | The time of the last update |
| `onRefresh` | `VoidCallback?` | No | `null` | Callback when refresh is tapped |
| `isRefreshing` | `bool` | No | `false` | Whether currently refreshing |
| `getTimeAgo` | `String Function(DateTime?)?` | No | Built-in | Custom time formatter |
| `refreshText` | `String` | No | `'Refresh'` | Text for refresh button |
| `updatePrefix` | `String` | No | `'Updated'` | Prefix before time |
| `timeColor` | `Color?` | No | `Colors.grey.shade600` | Color of time text |
| `refreshColor` | `Color?` | No | `theme.primary` | Color of refresh button |
| `iconSize` | `double` | No | `14.0` | Size of icons |
| `fontSize` | `double` | No | `12.0` | Font size |
| `padding` | `EdgeInsetsGeometry?` | No | Horizontal 4.0 | Widget padding |

---

### 3. `RefreshHelper` (Utility Class)
**File:** `lib/utils/refresh_helper.dart`

A helper class with static methods for executing refresh operations with built-in error handling and cooldown management.

#### Features:
- ✅ Built-in cooldown checking
- ✅ Automatic error handling
- ✅ User-friendly notifications
- ✅ Success/error callbacks
- ✅ Customizable messages

#### Usage:

```dart
Future<void> _refreshBalance() async {
  final success = await RefreshHelper.executeRefresh(
    context: context,
    lastRefreshTime: _lastRefreshTime,
    minInterval: Duration(seconds: 5),
    onRefresh: () async {
      // Your refresh logic
      await userProvider.loadUserData();
    },
    onSuccess: () {
      setState(() => _lastRefreshTime = DateTime.now());
    },
    successMessage: 'Balance updated successfully',
    showSuccessSnackBar: true,
  );
  
  if (success) {
    print('Refresh completed successfully');
  }
}
```

#### Methods:

##### `executeRefresh()`

Executes a refresh operation with cooldown and error handling.

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `context` | `BuildContext` | Yes | Build context for showing snackbars |
| `onRefresh` | `Future<void> Function()` | Yes | The refresh operation to execute |
| `lastRefreshTime` | `DateTime?` | No | Time of last refresh for cooldown |
| `minInterval` | `Duration` | No | Minimum time between refreshes |
| `onSuccess` | `VoidCallback?` | No | Called on successful refresh |
| `onError` | `VoidCallback?` | No | Called on error |
| `successMessage` | `String?` | No | Success message to show |
| `errorMessage` | `String?` | No | Error message prefix |
| `showSuccessSnackBar` | `bool` | No | Whether to show success message |
| `showErrorSnackBar` | `bool` | No | Whether to show error message |

**Returns:** `Future<bool>` - `true` if refresh succeeded, `false` otherwise

##### `formatTimeAgo(DateTime?)`

Formats a DateTime as a human-readable string.

```dart
RefreshHelper.formatTimeAgo(DateTime.now()); // "Just now"
RefreshHelper.formatTimeAgo(DateTime.now().subtract(Duration(minutes: 5))); // "5 minutes ago"
```

##### `canRefresh(DateTime?, Duration)`

Checks if enough time has elapsed since last refresh.

```dart
if (RefreshHelper.canRefresh(_lastRefresh, Duration(seconds: 30))) {
  // Perform refresh
}
```

##### `getRemainingCooldown(DateTime?, Duration)`

Gets the remaining cooldown time.

```dart
final remaining = RefreshHelper.getRemainingCooldown(_lastRefresh, Duration(seconds: 30));
print('Wait ${remaining.inSeconds} more seconds');
```

---

## Complete Example

Here's a complete example using all three components together:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../mixins/refresh_tracker_mixin.dart';
import '../widgets/last_updated_widget.dart';
import '../utils/refresh_helper.dart';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({Key? key}) : super(key: key);

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> with RefreshTrackerMixin {
  DateTime? _lastBalanceUpdate;
  bool _isRefreshing = false;

  @override
  Duration get minManualRefreshInterval => const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    startRefreshTimer(); // Auto-update UI every minute
    _loadData();
  }

  @override
  void dispose() {
    disposeRefreshTimer();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!canRefresh()) return;

    final balanceProvider = Provider.of<BalanceProvider>(context, listen: false);
    await balanceProvider.loadBalance();
    
    markRefreshed();
    setState(() => _lastBalanceUpdate = DateTime.now());
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    await RefreshHelper.executeRefresh(
      context: context,
      lastRefreshTime: _lastBalanceUpdate,
      minInterval: minManualRefreshInterval,
      onRefresh: () async {
        final provider = Provider.of<BalanceProvider>(context, listen: false);
        await provider.loadBalance();
      },
      onSuccess: () {
        setState(() => _lastBalanceUpdate = DateTime.now());
      },
      successMessage: 'Balance updated successfully',
    );

    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance')),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance card
            Consumer<BalanceProvider>(
              builder: (_, balance, __) => BalanceCard(
                amount: balance.amount,
                isLoading: balance.isLoading,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Last updated widget with refresh button
            LastUpdatedWidget(
              lastUpdateTime: _lastBalanceUpdate,
              onRefresh: _manualRefresh,
              isRefreshing: _isRefreshing,
              getTimeAgo: getTimeAgo, // From mixin
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Production Best Practices

### 1. **Always Use Cooldowns**
```dart
// Good: Prevents API spam
if (!canRefresh(isManual: true)) {
  showSnackBar('Please wait before refreshing again');
  return;
}

// Bad: No cooldown check
await loadData();
```

### 2. **Handle Errors Gracefully**
```dart
// Good: Uses RefreshHelper with error handling
await RefreshHelper.executeRefresh(
  context: context,
  onRefresh: () async => await loadData(),
  onError: () => logError('Refresh failed'),
);

// Bad: No error handling
await loadData();
```

### 3. **Update UI State Properly**
```dart
// Good: Updates state after successful refresh
onSuccess: () {
  setState(() => _lastRefresh = DateTime.now());
},

// Bad: Forgets to update UI
await loadData();
// UI still shows old time
```

### 4. **Clean Up Resources**
```dart
@override
void dispose() {
  disposeRefreshTimer(); // Important!
  super.dispose();
}
```

### 5. **Use Appropriate Intervals**
```dart
// For automatic background refreshes
@override
Duration get minRefreshInterval => const Duration(seconds: 30);

// For manual user-triggered refreshes
@override
Duration get minManualRefreshInterval => const Duration(seconds: 5);
```

---

## Migration Guide

### Migrating Existing Code

**Before:**
```dart
class _MyScreenState extends State<MyScreen> {
  DateTime? _lastUpdate;
  Timer? _timer;
  
  String _formatTime(DateTime? dt) {
    // Custom formatting logic
  }
  
  Future<void> _refresh() async {
    // Custom refresh logic with manual cooldown checks
  }
}
```

**After:**
```dart
class _MyScreenState extends State<MyScreen> with RefreshTrackerMixin {
  // Remove manual timer and formatting - mixin provides them!
  
  @override
  void initState() {
    super.initState();
    startRefreshTimer();
  }
  
  @override
  void dispose() {
    disposeRefreshTimer();
    super.dispose();
  }
  
  Future<void> _refresh() async {
    if (!canRefresh()) return;
    await myProvider.load();
    markRefreshed();
  }
}
```

---

## Testing

### Unit Testing

```dart
test('RefreshHelper.formatTimeAgo formats correctly', () {
  final now = DateTime.now();
  expect(RefreshHelper.formatTimeAgo(now), 'Just now');
  expect(
    RefreshHelper.formatTimeAgo(now.subtract(Duration(minutes: 5))),
    '5 minutes ago',
  );
});

test('RefreshHelper.canRefresh respects cooldown', () {
  final lastRefresh = DateTime.now();
  final interval = Duration(seconds: 30);
  
  expect(RefreshHelper.canRefresh(lastRefresh, interval), false);
  expect(
    RefreshHelper.canRefresh(
      lastRefresh.subtract(Duration(seconds: 31)),
      interval,
    ),
    true,
  );
});
```

---

## License

These components are part of the ftplug project and can be reused across any of your Flutter projects.

## Contributing

When making improvements:
1. Maintain backward compatibility
2. Add tests for new features
3. Update this documentation
4. Follow Flutter/Dart best practices

