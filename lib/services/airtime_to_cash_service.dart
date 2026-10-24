import 'dart:convert';

import 'package:favouritesub/services/session_http.dart' as http;
import 'package:favouritesub/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AirtimeToCashService {
  const AirtimeToCashService._();

  static Future<Map<String, dynamic>> submit({
    required int networkId,
    required String senderPhone,
    required double airtimeAmount,
    required bool fundWallet,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      throw Exception('Your session has expired. Please sign in again.');
    }

    final response = await http
        .post(
          Api.uri('/api/Airtime_funding/'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'network': networkId,
            'mobile_number': senderPhone.trim(),
            'amount': airtimeAmount,
            'use_to_fund_wallet': fundWallet,
          }),
        )
        .timeout(const Duration(seconds: 30));

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return const <String, dynamic>{};
    }

    throw Exception(_errorMessage(decoded, response.statusCode));
  }

  static String _errorMessage(dynamic body, int statusCode) {
    dynamic value = body;
    if (body is Map) {
      value = body['error'] ?? body['message'] ?? body['detail'];
      if (value == null && body.isNotEmpty) value = body.values.first;
    }
    while (value is List && value.isNotEmpty) {
      value = value.first;
    }
    if (value is Map && value.isNotEmpty) {
      value = value.values.first;
      while (value is List && value.isNotEmpty) {
        value = value.first;
      }
    }
    final message = value?.toString().trim() ?? '';
    if (message.isNotEmpty) return message;
    if (statusCode == 401) {
      return 'Your session has expired. Please sign in again.';
    }
    return 'We could not submit your airtime transfer. Please try again.';
  }
}
