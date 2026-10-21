import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider extends ChangeNotifier {
  static const _keyFullName = 'profile_fullname_override';
  static const _keyPhone = 'profile_phone_override';
  static const _keyAddress = 'profile_address_override';

  String? _fullName;
  String? _phone;
  String? _address;

  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get address => _address;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _fullName = prefs.getString(_keyFullName);
    _phone = prefs.getString(_keyPhone);
    _address = prefs.getString(_keyAddress);
    notifyListeners();
  }

  Future<void> update({
    String? fullName,
    String? phone,
    String? address,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (fullName != null) {
      _fullName = fullName;
      await prefs.setString(_keyFullName, fullName);
    }
    if (phone != null) {
      _phone = phone;
      await prefs.setString(_keyPhone, phone);
    }
    if (address != null) {
      _address = address;
      await prefs.setString(_keyAddress, address);
    }
    notifyListeners();
  }
}
