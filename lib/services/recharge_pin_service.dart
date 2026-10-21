import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class RechargePinService {
  static Future<Map<String, dynamic>> createOrder({
    required int network,
    required int networkAmount,
    required String nameOnCard,
    required int quantity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('${Api.base}/api/rechargepin/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'network': network,
        'network_amount': networkAmount,
        'name_on_card': nameOnCard,
        'quantity': quantity,
      }),
    );

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      parsed = {'message': resp.body};
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return parsed;
    }
    if (resp.statusCode == 400) {
      throw Exception(
        parsed['error']?[0]?.toString() ??
            'Request failed (${resp.statusCode})',
      );
    }
    final msg =
        parsed['message']?.toString() ?? 'Request failed (${resp.statusCode})';
    throw Exception(msg);
  }
}
