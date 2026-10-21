import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class ElectricityService {
  static String _defaultBase() => Api.base;

  static Future<Map<String, dynamic>> validateMeterNumber({
    required String meterNumber,
    required String discoName,
    required String meterType,
    String? baseUrl,
  }) async {
    final uri =
        Uri.parse(
          '${baseUrl ?? _defaultBase()}/ajax/validate_meter_number/',
        ).replace(
          queryParameters: {
            'meternumber': meterNumber.trim(),
            'disconame': discoName.trim(),
            'mtype': meterType.trim().toUpperCase(),
          },
        );

    final resp = await http.get(uri);

    Map<String, dynamic> parsed = {};
    try {
      final decoded = jsonDecode(resp.body);
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

  static Future<Map<String, dynamic>> purchaseElectricity({
    required int discoName,
    required String meterNumber,
    required String meterType,
    required String amount,
    required String customerPhone,
    String? customerName,
    String? customerAddress,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw Exception('No access token');
    }

    final uri = Uri.parse('${baseUrl ?? _defaultBase()}/api/billpayment/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'disco_name': discoName,
        'meter_number': meterNumber,
        'MeterType': meterType,
        'amount': amount,
        'Customer_Phone': customerPhone,
        if (customerName != null && customerName.trim().isNotEmpty)
          'customer_name': customerName.trim(),
        if (customerAddress != null && customerAddress.trim().isNotEmpty)
          'customer_address': customerAddress.trim(),
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
    } else {
      String msg = 'Purchase failed (${resp.statusCode})';
      final err = parsed['error'];
      if (err is List && err.isNotEmpty) {
        msg = err.first.toString();
      } else if (err is String && err.trim().isNotEmpty) {
        msg = err.trim();
      } else if (parsed['message'] != null) {
        msg = parsed['message'].toString();
      }

      throw msg;
    }
  }
}
