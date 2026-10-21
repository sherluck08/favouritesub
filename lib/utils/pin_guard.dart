import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:favouritesub/providers/app_data_provider.dart';
import 'package:favouritesub/screens/set_transaction_pin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinGuard {
  static bool _promptOpen = false;
  static SharedPreferences? _prefs;

  static Future<void> prewarm(BuildContext context) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;
      final token = prefs.getString('access_token');
      final tokenKey = token != null && token.isNotEmpty
          ? 'pin_set_for_token_$token'
          : 'pin_set_generic';
      final localHasPin = prefs.getBool(tokenKey) ?? false;
      if (localHasPin) return;

      final appDataProv = Provider.of<AppDataProvider>(context, listen: false);
      final raw = appDataProv.data?.user.pin;
      final pinRaw = raw == null ? '' : raw.toString();
      final pinVal = pinRaw.trim().toLowerCase() == 'null' ? '' : pinRaw.trim();
      final hasPin = pinVal.isNotEmpty;
      if (hasPin) {
        await prefs.setBool(tokenKey, true);
      }
    } catch (_) {}
  }

  static Future<T?> pushWithPinSetup<T>(
    BuildContext context,
    WidgetBuilder target,
  ) async {
    try {
      final navigator = Navigator.of(context);
      _prefs ??= await SharedPreferences.getInstance();
      final prefs = _prefs!;

      final token = prefs.getString('access_token');
      final tokenKey = token != null && token.isNotEmpty
          ? 'pin_set_for_token_$token'
          : 'pin_set_generic';
      final localHasPin = prefs.getBool(tokenKey) ?? false;
      if (localHasPin) {
        return navigator.push(MaterialPageRoute(builder: target));
      }

      final appDataProv = Provider.of<AppDataProvider>(context, listen: false);
      final raw = appDataProv.data?.user.pin;
      final pinRaw = raw == null ? '' : raw.toString();
      final pinVal = pinRaw.trim().toLowerCase() == 'null' ? '' : pinRaw.trim();
      final hasPin = pinVal.isNotEmpty;
      if (hasPin) {
        await prefs.setBool(tokenKey, true);
        return navigator.push(MaterialPageRoute(builder: target));
      }

      await appDataProv.fetchFromApi(force: true);
      final refreshed = appDataProv.data?.user.pin?.toString().trim();
      final refreshedHasPin =
          refreshed != null &&
          refreshed.isNotEmpty &&
          refreshed.toLowerCase() != 'null';
      if (refreshedHasPin) {
        await prefs.setBool(tokenKey, true);
        return navigator.push(MaterialPageRoute(builder: target));
      }

      if (_promptOpen) return null;
      _promptOpen = true;
      final result = await navigator.push(
        MaterialPageRoute(builder: (_) => const SetTransactionPinScreen()),
      );
      _promptOpen = false;

      final String? newPin = result is String ? result : null;
      final bool ok =
          result == true || (newPin != null && newPin.trim().isNotEmpty);
      if (ok) {
        try {
          await appDataProv.refresh();
        } catch (_) {}
        await prefs.setBool(tokenKey, true);
        return navigator.push(MaterialPageRoute(builder: target));
      }
      return null;
    } catch (_) {
      final navigator = Navigator.of(context);
      return navigator.push(MaterialPageRoute(builder: target));
    }
  }
}
