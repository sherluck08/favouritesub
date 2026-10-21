import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class BonusService {
  static Future<Map<String, dynamic>> transferBonusToWallet({
    required String amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final uri = Uri.parse('${Api.base}/api/bonus_transfer/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'amount': amount}),
    );

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      parsed = {'message': resp.body};
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return parsed;
    } else if (resp.statusCode == 400) {
      return {'error': parsed['error']?[0]?.toString() ?? 'Transfer failed'};
    } else {
      final msg =
          parsed['message']?.toString() ??
          parsed['error']?.toString() ??
          'Transfer failed (${resp.statusCode})';
      return {'message': msg};
    }
  }
}
