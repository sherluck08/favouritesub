import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class UserProvider extends ChangeNotifier {
  String _username = 'User';
  String _balance = '₦0.00';
  bool _isLoading = false;
  String? _error;

  String get username => _username;
  String get balance => _balance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadUserData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await _loadLocalUserData();

    try {
      await _fetchUserDataFromAPI();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserProvider: error loading user data: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUserData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _fetchUserDataFromAPI();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserProvider: error refreshing user data: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('user_username');
      final savedBalance = prefs.getDouble('user_balance');

      if (savedUsername != null) {
        _username = savedUsername;
      }
      if (savedBalance != null) {
        _balance = _formatBalance(savedBalance);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UserProvider: error loading local data: $e');
      }
    }
  }

  Future<void> _fetchUserDataFromAPI() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      _error = 'No access token found';
      return;
    }

    final response = await http
        .get(
          Uri.parse('${Api.base}/api/v1/user-data/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final userData = data['user'];

      final username = userData['username'] ?? 'User';
      final fullName = userData['FullName'];
      final accountBalance = userData['Account_Balance']?.toDouble() ?? 0.0;

      final displayName = fullName?.isNotEmpty == true ? fullName : username;

      await prefs.setString('user_username', displayName);
      await prefs.setDouble('user_balance', accountBalance);

      _username = displayName;
      _balance = _formatBalance(accountBalance);
      _error = null;
    } else {
      _error = 'Failed to fetch user data: ${response.statusCode}';
      if (kDebugMode) {
        debugPrint('UserProvider: fetch failed ${response.statusCode}');
      }
    }
  }

  String _formatBalance(double balance) {
    return '₦${balance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }
}
