import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class ResultCheckerService {
  static String _defaultBase() => Api.base;

  static Future<Map<String, dynamic>> purchasePins({
    required String examName,
    required int quantity,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) throw Exception('No access token');

    final uri = Uri.parse('${baseUrl ?? _defaultBase()}/api/epin/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'exam_name': examName, 'quantity': quantity}),
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
          if (v is String)
            return {
              'error': [v],
            };
        }
        return body;
      }
      return {
        'error': [body?.toString() ?? 'Unknown error'],
      };
    }

    final statusField = (decoded is Map<String, dynamic>)
        ? (decoded['Status'] ?? decoded['status'])
        : null;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (statusField == 'successful' || statusField == 'success')
        return {'status': 'success', 'data': decoded};
      if (statusField == 'processing')
        return {'status': 'processing', 'data': decoded};
      if (statusField == 'failed')
        return {'status': 'failed', 'message': normalizeFailedMessage(decoded)};
      return {'status': 'success', 'data': decoded};
    } else {
      return {'status': 'failed', 'message': normalizeFailedMessage(decoded)};
    }
  }
}
