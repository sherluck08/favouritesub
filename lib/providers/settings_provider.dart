import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyBiometric = 'pref_biometric_enabled';
  static const _keyBiometricPay = 'pref_biometric_pay_enabled';
  static const _keyShowBalance = 'pref_show_balance';
  static const _keyDarkMode = 'pref_dark_mode';

  bool _biometricEnabled = false;
  // Biometric payment is available by default when the device supports it.
  // An explicitly saved opt-out still takes precedence in [load].
  bool _biometricPayEnabled = true;
  bool _showBalance = true;
  bool _darkMode = false;

  bool get biometricEnabled => _biometricEnabled;
  bool get biometricPayEnabled => _biometricPayEnabled;
  bool get showBalance => _showBalance;
  bool get darkMode => _darkMode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _biometricEnabled = prefs.getBool(_keyBiometric) ?? false;
    _biometricPayEnabled = prefs.getBool(_keyBiometricPay) ?? true;
    _showBalance = prefs.getBool(_keyShowBalance) ?? true;
    _darkMode = prefs.getBool(_keyDarkMode) ?? false;
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    _biometricEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometric, value);
  }

  Future<void> setBiometricPayEnabled(bool value) async {
    _biometricPayEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricPay, value);
  }

  Future<void> setShowBalance(bool value) async {
    _showBalance = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowBalance, value);
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
  }
}
