import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BeneficiaryService {
  static const data = 'data';
  static const airtime = 'airtime';
  static const _keyPrefix = 'recent_beneficiaries_';
  static const _maxItems = 5;
  static const _guestScope = 'guest';

  static bool isBeneficiaryStorageKey(String key) => key.startsWith(_keyPrefix);

  static Future<List<BeneficiaryItem>> load({required String service}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(service, prefs);
    var raw = prefs.getString(key);

    if (raw == null || raw.isEmpty) {
      raw = await _migrateLegacyValue(service: service, prefs: prefs, key: key);
    }
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final items =
          decoded
              .whereType<Map>()
              .map(
                (item) =>
                    BeneficiaryItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.phone.isNotEmpty && item.networkId > 0)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items.take(_maxItems).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<BeneficiaryItem>> save({
    required String service,
    required int networkId,
    required String networkName,
    required String phone,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10 || networkId <= 0) {
      return load(service: service);
    }

    final prefs = await SharedPreferences.getInstance();
    final key = _key(service, prefs);
    final current = await load(service: service);
    final next = <BeneficiaryItem>[
      BeneficiaryItem(
        networkId: networkId,
        networkName: networkName,
        phone: cleanPhone,
        updatedAt: DateTime.now(),
      ),
      ...current.where(
        (item) => !(item.networkId == networkId && item.phone == cleanPhone),
      ),
    ].take(_maxItems).toList();

    await prefs.setString(
      key,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
    return next;
  }

  static String _key(String service, SharedPreferences prefs) {
    final scope = _stableUserScope(prefs);
    return '$_keyPrefix${service}_$scope';
  }

  static Future<String?> _migrateLegacyValue({
    required String service,
    required SharedPreferences prefs,
    required String key,
  }) async {
    final preferredKeys = <String>{
      '$_keyPrefix${service}_${_legacyTokenScope(prefs)}',
      '$_keyPrefix${service}_$_guestScope',
    }..remove(key);

    for (final legacyKey in preferredKeys) {
      final raw = prefs.getString(legacyKey);
      if (raw != null && raw.isNotEmpty) {
        await prefs.setString(key, raw);
        return raw;
      }
    }

    return null;
  }

  static String _stableUserScope(SharedPreferences prefs) {
    final username = prefs.getString('saved_username')?.trim().toLowerCase();
    if (username != null && username.isNotEmpty) {
      return 'u_${_fingerprint(username)}';
    }

    final email = prefs.getString('email')?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) {
      return 'e_${_fingerprint(email)}';
    }
    return _guestScope;
  }

  static String _legacyTokenScope(SharedPreferences prefs) {
    final token = prefs.getString('access_token') ?? '';
    return token.isEmpty ? _guestScope : _fingerprint(token);
  }

  static String _fingerprint(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }
}

class BeneficiaryItem {
  final int networkId;
  final String networkName;
  final String phone;
  final DateTime updatedAt;

  const BeneficiaryItem({
    required this.networkId,
    required this.networkName,
    required this.phone,
    required this.updatedAt,
  });

  factory BeneficiaryItem.fromJson(Map<String, dynamic> json) {
    return BeneficiaryItem(
      networkId: (json['network_id'] as num?)?.toInt() ?? 0,
      networkName: (json['network_name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, dynamic> toJson() => {
    'network_id': networkId,
    'network_name': networkName,
    'phone': phone,
    'updated_at': updatedAt.toIso8601String(),
  };
}
