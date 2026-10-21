import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class ChangePasswordService {
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
    String? confirmPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      throw Exception('No access token');
    }

    final uri = Uri.parse('${Api.base}/api/v1/change-password/');
    final resp = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,

        'confirm_new_password': confirmPassword ?? newPassword,

        'password1': newPassword,
        'password2': confirmPassword ?? newPassword,
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

    final message = _extractErrorMessage(parsed).isNotEmpty
        ? _extractErrorMessage(parsed)
        : (parsed['message']?.toString() ??
              parsed['error']?.toString() ??
              'Change password failed (${resp.statusCode})');
    return {'error': message};
  }

  static String _extractErrorMessage(dynamic body) {
    final List<String> out = [];

    void collect(dynamic v) {
      if (v == null) return;
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty) out.add(_humanize(s));
        return;
      }
      if (v is List) {
        for (final e in v) {
          collect(e);
        }
        return;
      }
      if (v is Map) {
        const preferredKeys = [
          'detail',
          'non_field_errors',
          'error',
          'message',
          'old_password',
          'new_password',
          'confirm_password',
          'password1',
          'password2',
        ];
        for (final k in preferredKeys) {
          if (v.containsKey(k)) collect(v[k]);
        }

        v.forEach((key, value) {
          if (!preferredKeys.contains(key)) collect(value);
        });
        return;
      }

      out.add(_humanize(v.toString()));
    }

    collect(body);
    return out.join('. ').replaceAll(RegExp(r'\.+$'), '.').trim();
  }

  static String _humanize(String s) {
    return s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}
