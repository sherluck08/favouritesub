import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class RechargePinOrderResult {
  final int id;
  final String status;
  final String rawDataJson;
  RechargePinOrderResult({
    required this.id,
    required this.status,
    required this.rawDataJson,
  });
}

class RechargePinProvider extends ChangeNotifier {
  bool _isPlacing = false;
  String? _error;

  bool get isPlacing => _isPlacing;
  String? get error => _error;

  Future<RechargePinOrderResult?> placeOrder({
    required int networkId,
    required int networkAmountId,
    required String nameOnCard,
    required int quantity,
  }) async {
    if (_isPlacing) return null;
    _isPlacing = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        _error = 'No access token';
        _isPlacing = false;
        notifyListeners();
        return null;
      }

      final resp = await http.post(
        Uri.parse('${Api.base}/api/v1/recharge-pin/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'network': networkId,
          'network_amount': networkAmountId,
          'name_on_card': nameOnCard,
          'quantity': quantity,
        }),
      );

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final id = (body['id'] as num?)?.toInt() ?? 0;
        final status = (body['Status'] ?? body['status'] ?? 'successful')
            .toString();
        _isPlacing = false;
        notifyListeners();
        return RechargePinOrderResult(
          id: id,
          status: status,
          rawDataJson: resp.body,
        );
      } else {
        try {
          final body = jsonDecode(resp.body);
          _error =
              body['error']?.toString() ??
              body['message']?.toString() ??
              'Transaction Failed';
        } catch (_) {
          _error = 'Transaction Failed';
        }
        _isPlacing = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = 'Error: $e';
      _isPlacing = false;
      notifyListeners();
      return null;
    }
  }
}
