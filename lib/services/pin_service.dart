import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class PinService {
  static Future<bool> verifyPin(String pin, {String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final uri = Uri.parse(
      '${baseUrl ?? Api.base}/api/checkpin/?pin=$pin&_=$timestamp',
    );

    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      final msg = decoded['message']?.toString().toLowerCase() ?? '';
      if (msg.contains('pin correct') ||
          msg.contains('success') ||
          msg.contains('verified')) {
        return true;
      }

      return false;
    }

    try {
      final decoded = jsonDecode(resp.body);
      final msg = (decoded['message'] ?? decoded['error'] ?? '')
          .toString()
          .toLowerCase();
      if (msg.contains('incorrect') ||
          msg.contains('wrong') ||
          msg.contains('invalid')) {
        return false;
      }
      throw Exception(
        decoded['error'] ?? decoded['message'] ?? 'PIN verification failed',
      );
    } catch (_) {
      throw Exception('PIN verification failed');
    }
  }

  static Future<void> resetPin({
    required String oldPin,
    required String newPin,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final uri = Uri.parse(
      '${baseUrl ?? Api.base}/api/resetpin/?pin1=$oldPin&pin2=$newPin&_=$timestamp',
    );

    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    print("Reset Status: ${resp.statusCode}");
    print("Reset Body: ${resp.body}");

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      if (decoded['message'] != null &&
          decoded['message'].toString().toLowerCase().contains('success')) {
        return;
      }
      throw Exception(decoded['message'] ?? 'PIN reset failed');
    }

    try {
      final decoded = jsonDecode(resp.body);
      throw Exception(
        decoded['error'] ?? decoded['message'] ?? 'PIN reset failed',
      );
    } catch (_) {
      throw Exception('PIN reset failed');
    }
  }

  static Future<void> setupPin({required String pin, String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final uri = Uri.parse(
      '${baseUrl ?? Api.base}/api/pin/?pin1=$pin&pin2=$pin&_=$timestamp',
    );

    final resp = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    print("Setup Status: ${resp.statusCode}");
    print("Setup Body: ${resp.body}");

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      if (decoded['message'] != null &&
          decoded['message'].toString().toLowerCase().contains('success')) {
        return;
      }
      throw Exception(decoded['message'] ?? 'PIN setup failed');
    }

    try {
      final decoded = jsonDecode(resp.body);
      throw Exception(
        decoded['error'] ?? decoded['message'] ?? 'PIN setup failed',
      );
    } catch (_) {
      throw Exception('PIN setup failed');
    }
  }
}
