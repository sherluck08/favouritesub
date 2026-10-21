import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class EditProfileService {
  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phone,
    required String address,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      throw Exception('No access token');
    }

    final uri = Uri.parse('${Api.base}/api/v1/edit-user/');

    final resp = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'FullName': fullName,
        'Phone': phone,
        'Address': address,
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
              'Profile update failed (${resp.statusCode})');
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
        const preferred = [
          'detail',
          'non_field_errors',
          'error',
          'message',
          'FullName',
          'Phone',
          'Address',
        ];
        for (final k in preferred) {
          if (v.containsKey(k)) collect(v[k]);
        }
        v.forEach((key, value) {
          if (!preferred.contains(key)) collect(value);
        });
        return;
      }
      out.add(_humanize(v.toString()));
    }

    collect(body);
    return out.join('. ').replaceAll(RegExp(r'\.+$'), '.').trim();
  }

  static String _humanize(String s) =>
      s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
