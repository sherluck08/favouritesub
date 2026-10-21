import 'dart:convert';

import 'package:favouritesub/models/referral_member.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:favouritesub/utils/api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReferralService {
  const ReferralService._();

  static Future<List<ReferralMember>> fetchReferrals() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) {
      throw const ReferralException('Please sign in again to view referrals.');
    }

    final response = await http
        .get(
          Api.uri('/api/referal/'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ReferralException(_messageFrom(response.body));
    }

    final decoded = jsonDecode(response.body);
    final rawItems = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? (decoded['results'] as List? ?? const [])
        : const [];

    return rawItems
        .whereType<Map>()
        .map((item) => ReferralMember.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.username.isNotEmpty)
        .toList(growable: false);
  }

  static String _messageFrom(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        for (final key in const ['detail', 'message', 'error']) {
          final value = data[key]?.toString().trim();
          if (value != null && value.isNotEmpty) return value;
        }
      }
    } catch (_) {}
    return 'Could not load your referrals. Please try again.';
  }
}

class ReferralException implements Exception {
  const ReferralException(this.message);

  final String message;

  @override
  String toString() => message;
}
