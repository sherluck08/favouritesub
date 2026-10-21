import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class PurchaseService {
  static Future<Map<String, dynamic>> buyData({
    required int networkId,
    required String planType,
    required String planId,
    required String phone,
    String? expectedAmount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final uri = Uri.parse('${Api.base}/api/data/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'network': networkId,
        'plan_type': planType,
        'plan': planId,
        'mobile_number': phone,
        'Ported_number': true,
        if (expectedAmount != null) 'expected_amount': expectedAmount,
      }),
    );

    String errorMessage(dynamic body) {
      if (body is! Map) return body?.toString() ?? 'Purchase failed';
      final error = body['error'] ?? body['detail'] ?? body['message'];
      if (error is List && error.isNotEmpty) return error.first.toString();
      if (error is Map && error.isNotEmpty) {
        final first = error.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return first.toString();
      }
      if (error != null) return error.toString();
      final apiResponse = body['api_response'];
      return apiResponse?.toString() ?? 'Purchase failed';
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final decoded = jsonDecode(resp.body);
      final status = decoded["Status"];
      if (status == "successful") return {'status': 'success', 'data': decoded};
      if (status == "processing") {
        return {'status': 'processing', 'data': decoded};
      }
      if (status == "failed") {
        return {'status': 'failed', 'message': decoded["api_response"]};
      }
      if (decoded is Map<String, dynamic>) {
        return {'status': 'success', 'data': decoded};
      }
      return {'status': 'success', 'data': decoded};
    } else {
      final decoded = jsonDecode(resp.body);
      final status = decoded["Status"];
      if (status == "successful") return {'status': 'success', 'data': decoded};
      if (status == "processing") {
        return {'status': 'processing', 'data': decoded};
      }
      if (status == "failed") {
        return {'status': 'failed', 'message': decoded["api_response"]};
      }
      return {'status': 'failed', 'message': errorMessage(decoded)};
    }
  }

  static Future<Map<String, dynamic>> buyAirtime({
    required int networkId,
    required String airtimeType,
    required String phone,
    required String amount,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final uri = Uri.parse('${Api.base}/api/topup/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'network': networkId,
        'airtime_type': airtimeType,
        'mobile_number': phone,
        'amount': amount,
        'Ported_number': true,
      }),
    );
    final decoded = jsonDecode(resp.body);
    final status = (decoded is Map<String, dynamic>) ? decoded['Status'] : null;

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

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (status == 'successful') return {'status': 'success', 'data': decoded};
      if (status == 'processing') {
        return {'status': 'processing', 'data': decoded};
      }
      if (status == 'failed') {
        return {'status': 'failed', 'message': normalizeFailedMessage(decoded)};
      }

      return {'status': 'success', 'data': decoded};
    } else {
      if (status == 'successful') return {'status': 'success', 'data': decoded};
      if (status == 'processing') {
        return {'status': 'processing', 'data': decoded};
      }

      return {'status': 'failed', 'message': normalizeFailedMessage(decoded)};
    }
  }
}
