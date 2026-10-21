import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class BalanceProvider extends ChangeNotifier {
  String _balance = '₦0.00';
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;

  String get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  bool get isStale {
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!).inMinutes > 5;
  }

  Future<void> loadLocalBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBalance = prefs.getDouble('user_balance');
      final savedTimestamp = prefs.getInt('balance_timestamp');

      if (savedBalance != null) {
        _balance = _formatBalance(savedBalance);
        if (savedTimestamp != null) {
          _lastUpdated = DateTime.fromMillisecondsSinceEpoch(savedTimestamp);
        }
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading local balance: $e');
      }
    }
  }

  Future<void> fetchBalanceFromAPI() async {
    if (_isLoading) return;

    if (!isStale && _lastUpdated != null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        _error = 'No access token found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${Api.base}/api/v1/user-data/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['user'];
        final accountBalance = userData['Account_Balance']?.toDouble() ?? 0.0;

        await prefs.setDouble('user_balance', accountBalance);
        await prefs.setInt(
          'balance_timestamp',
          DateTime.now().millisecondsSinceEpoch,
        );

        _balance = _formatBalance(accountBalance);
        _lastUpdated = DateTime.now();
        _error = null;
      } else {
        _error = 'Failed to fetch balance: ${response.statusCode}';
        if (kDebugMode) {
          debugPrint('Failed to fetch user balance: ${response.statusCode}');
        }
      }
    } catch (e) {
      _error = 'Error fetching balance: $e';
      if (kDebugMode) {
        debugPrint('Error fetching balance from API: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBalance() async {
    await loadLocalBalance();

    if (isStale) {
      await fetchBalanceFromAPI();
    }
  }

  Future<void> refreshBalance() async {
    await fetchBalanceFromAPI();
  }

  String _formatBalance(double balance) {
    return '₦${balance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  void clearBalance() {
    _balance = '₦0.00';
    _isLoading = false;
    _error = null;
    _lastUpdated = null;
    notifyListeners();
  }
}
