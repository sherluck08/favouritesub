import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

class AppConfigProvider extends ChangeNotifier {
  static const String _cacheKeyPlanTypes = 'app_config_plan_types_v1';
  static const String _cacheKeyTimestamp = 'app_config_timestamp_v1';

  List<String> _planTypes = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;

  List<String> get planTypes => _planTypes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  bool get isStale {
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!).inMinutes > 60;
  }

  Future<void> loadConfig() async {
    await _loadLocalCache();
    if (_planTypes.isEmpty || isStale) {
      await fetchConfigFromApi();
    }
  }

  Future<void> refreshConfig() async {
    await fetchConfigFromApi(force: true);
  }

  Future<void> _loadLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKeyPlanTypes);
      final ts = prefs.getInt(_cacheKeyTimestamp);
      if (cached != null) {
        final decoded = (jsonDecode(cached) as List).cast<String>();
        _planTypes = decoded;
      }
      if (ts != null) {
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(ts);
      }
      if (cached != null) notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppConfigProvider: error loading cache: $e');
      }
    }
  }

  Future<void> fetchConfigFromApi({bool force = false}) async {
    if (_isLoading) return;
    if (!force && !isStale && _planTypes.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) {
        _error = 'No access token found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final response = await http.get(
        Uri.parse('${Api.base}/api/v1/user-data/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      print(jsonDecode(response.body));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final dynamic planTypeRaw = data['plan_type'];
        final List<String> planTypes = [];
        if (planTypeRaw is List) {
          for (final item in planTypeRaw) {
            if (item is List && item.isNotEmpty && item.first is String) {
              planTypes.add((item.first as String).trim());
            } else if (item is String) {
              planTypes.add(item.trim());
            }
          }
        }

        final seen = <String>{};
        _planTypes = planTypes.where((e) => seen.add(e.toUpperCase())).toList();

        _lastUpdated = DateTime.now();
        _error = null;

        await prefs.setString(_cacheKeyPlanTypes, jsonEncode(_planTypes));
        await prefs.setInt(
          _cacheKeyTimestamp,
          _lastUpdated!.millisecondsSinceEpoch,
        );

        notifyListeners();
      } else {
        _error = 'Failed to fetch config: ${response.statusCode}';
        if (kDebugMode) {
          debugPrint('AppConfigProvider: fetch failed ${response.statusCode}');
        }
      }
    } catch (e) {
      _error = 'Error fetching config: $e';
      if (kDebugMode) debugPrint('AppConfigProvider: error $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
