import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class CableService {
  static String _defaultBase() => Api.base;

  static Future<Map<String, dynamic>> validateIuc({
    required String smartCardNumber,
    required String cableName,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final _ = prefs.getString('access_token');

    final uri = Uri.parse('${baseUrl ?? _defaultBase()}/ajax/validate_iuc/')
        .replace(
          queryParameters: {
            'smart_card_number': smartCardNumber.trim(),
            'cablename': cableName.trim(),
          },
        );

    final resp = await http.get(uri);

    Map<String, dynamic> parsed = {};
    try {
      final decoded = jsonDecode(resp.body);
      print(decoded);
      print(resp.statusCode);

      parsed = decoded is Map<String, dynamic>
          ? decoded
          : {'message': decoded.toString()};
    } catch (_) {
      parsed = {'message': resp.body};
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return parsed;
    }

    final message =
        parsed['message']?.toString() ??
        'Validation failed (${resp.statusCode})';
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> purchaseCableSubscription({
    required int cableNameId,
    required int cablePlanId,
    required String smartCardNumber,
    required String customerName,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final uri = Uri.parse('${baseUrl ?? _defaultBase()}/api/cablesub/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'cablename': cableNameId,
        'cableplan': cablePlanId,
        'smart_card_number': smartCardNumber,
        'customer_name': customerName,
      }),
    );

    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      decoded = {'message': resp.body};
    }

    Map<String, dynamic> normalizeFailedMessage(dynamic body) {
      if (body is Map<String, dynamic>) {
        if (body.containsKey('error') && body['error'] is List) {
          return {'error': body['error']};
        }
        if (body.containsKey('api_response')) {
          final v = body['api_response'];
          if (v is String) {
            return {
              'error': [v],
            };
          }
        }
        return body;
      }
      return {
        'error': [body?.toString() ?? 'Unknown error'],
      };
    }

    final statusField = (decoded is Map<String, dynamic>)
        ? decoded['Status']
        : null;
    final statusCodeOk = resp.statusCode >= 200 && resp.statusCode < 300;

    if (statusCodeOk) {
      if (statusField == 'successful') {
        return {'status': 'success', 'data': decoded};
      }
      if (statusField == 'processing') {
        return {'status': 'processing', 'data': decoded};
      }
      if (statusField == 'failed') {
        return {'status': 'failed', 'message': normalizeFailedMessage(decoded)};
      }
      return {'status': 'success', 'data': decoded};
    } else {
      if (statusField == 'successful') {
        return {'status': 'success', 'data': decoded};
      }
      if (statusField == 'processing') {
        return {'status': 'processing', 'data': decoded};
      }
      return {'status': 'failed', 'message': normalizeFailedMessage(decoded)};
    }
  }
}
