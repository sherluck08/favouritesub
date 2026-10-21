import 'dart:convert';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/config/brand.dart';

class DeleteAccountService {
  /// Delete the user's account permanently
  /// Requires password for verification
  static Future<Map<String, dynamic>> deleteAccount({
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');

    if (token == null || token.isEmpty) {
      return {'error': 'No access token found. Please log in again.'};
    }

    try {
      final uri = Uri.parse('${Brand.current.domain}/api/delete-account/');
      final resp = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({'password': password}),
      );

      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        parsed = {'message': resp.body};
      }

      // Success response
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        // Clear all local data after successful deletion
        await _clearAllLocalData();

        return {
          'success': true,
          'message': parsed['message'] ?? 'Account deleted successfully',
        };
      }

      // Error response
      final errorMessage = _extractErrorMessage(parsed).isNotEmpty
          ? _extractErrorMessage(parsed)
          : (parsed['error']?.toString() ??
                parsed['message']?.toString() ??
                'Failed to delete account (${resp.statusCode})');

      return {'error': errorMessage};
    } catch (e) {
      return {'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Get account deletion information
  static Future<Map<String, dynamic>> getDeleteAccountInfo() async {
    try {
      final uri = Uri.parse('${Brand.current.domain}/api/delete-account/');
      final resp = await http.get(uri);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }

      return {'error': 'Failed to fetch deletion information'};
    } catch (e) {
      return {'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Clear all local data after account deletion
  static Future<void> _clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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
          'password',
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
    return s.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
