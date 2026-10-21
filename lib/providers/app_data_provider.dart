import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';

import '../models/app_data.dart';

AppData _parseAppData(String body) =>
    AppData.fromJson(jsonDecode(body) as Map<String, dynamic>);

class AppDataProvider extends ChangeNotifier {
  static const String _cacheKey = 'app_data_cache_v2';
  static const String _cacheTsKey = 'app_data_cache_ts_v2';
  static const String _legacyCacheKey = 'app_data_cache_v1';
  static const String _legacyCacheTsKey = 'app_data_cache_ts_v1';
  static const String _supportConfigCacheKey = 'support_config_cache_v1';

  // Keep the persisted snapshot for instant/offline rendering, but revalidate
  // regularly so admin plan and price changes do not linger for an hour.
  static const Duration _staleThreshold = Duration(minutes: 5);
  static const Duration _silentThrottle = Duration(seconds: 5);
  static const Duration _requestTimeout = Duration(seconds: 15);

  AppData? _data;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;
  DateTime? _lastSilentAt;
  DateTime? _lastPublicConfigFetch;
  String? _lastBody;
  Future<void>? _inFlight;
  Future<void>? _publicConfigInFlight;
  WebConfig? _publicWebConfig;
  bool _publicCacheLoaded = false;

  bool _disposed = false;

  AppData? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  WebConfig? get webconfig => _publicWebConfig ?? _data?.webconfig;

  bool get isStale {
    if (_lastUpdated == null) return true;
    return DateTime.now().difference(_lastUpdated!) > _staleThreshold;
  }

  /// Hydrates cached data immediately, then fetches when missing or stale.
  Future<void> load() async {
    await _loadFromCache();
    if (_data == null || isStale) {
      await fetchFromApi();
    }
  }

  /// Loads the support contacts required on unauthenticated screens.
  Future<void> loadPublicConfig({bool force = false}) async {
    final running = _publicConfigInFlight;
    if (running != null) return running;
    final future = _loadPublicConfig(force: force);
    _publicConfigInFlight = future;
    return future.whenComplete(() => _publicConfigInFlight = null);
  }

  Future<void> _loadPublicConfig({required bool force}) async {
    if (!_publicCacheLoaded) {
      _publicCacheLoaded = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_supportConfigCacheKey);
        if (raw != null && raw.isNotEmpty) {
          _publicWebConfig = WebConfig.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map),
          );
          _safeNotify();
        }
      } catch (error) {
        if (kDebugMode) debugPrint('Support config cache error: $error');
      }
    }

    if (!force &&
        _lastPublicConfigFetch != null &&
        DateTime.now().difference(_lastPublicConfigFetch!) <
            const Duration(seconds: 30)) {
      return;
    }

    try {
      final uri = Api.uri('/api/v1/public-config/').replace(
        queryParameters: {
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            },
          )
          .timeout(_requestTimeout);
      _lastPublicConfigFetch = DateTime.now();
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['webconfig'] is! Map) return;
      final rawConfig = Map<String, dynamic>.from(decoded['webconfig'] as Map);
      _publicWebConfig = WebConfig.fromJson(rawConfig);
      _safeNotify();
      final prefs = await SharedPreferences.getInstance();
      unawaited(prefs.setString(_supportConfigCacheKey, jsonEncode(rawConfig)));
    } catch (error) {
      if (kDebugMode) debugPrint('Support config fetch error: $error');
    }
  }

  /// User-initiated refresh: always hits the API and exposes loading/errors.
  Future<void> refresh() => fetchFromApi(force: true);

  /// Background refresh for screen entry, route return, and app resume.
  /// Calls within five seconds are deduplicated to avoid request storms.
  Future<void> silentRefresh({bool force = false}) {
    if (_inFlight != null) return _inFlight!;
    if (!force &&
        _lastSilentAt != null &&
        DateTime.now().difference(_lastSilentAt!) < _silentThrottle) {
      return Future.value();
    }
    return _runFetch(silent: true);
  }

  Future<void> fetchFromApi({bool force = false}) {
    if (_inFlight != null) return _inFlight!;
    if (!force && !isStale && _data != null) return Future.value();
    return _runFetch(silent: false);
  }

  Future<void> _runFetch({required bool silent}) {
    final future = _doFetch(silent: silent);
    _inFlight = future;
    future.whenComplete(() {
      _inFlight = null;
      _lastSilentAt = DateTime.now();
    });
    return future;
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(_cacheKey) ?? prefs.getString(_legacyCacheKey);
      final timestamp =
          prefs.getInt(_cacheTsKey) ?? prefs.getInt(_legacyCacheTsKey);
      if (raw != null) {
        _data = AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        _lastBody = raw;
      }
      if (timestamp != null) {
        _lastUpdated = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      if (raw != null) _safeNotify();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AppDataProvider: cache load error: $error');
      }
    }
  }

  Future<void> _doFetch({required bool silent}) async {
    if (!silent) {
      _isLoading = true;
      _error = null;
      _safeNotify();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        if (!silent) _error = 'No access token found';
        return;
      }

      final uri = Uri.parse('${Api.base}/api/v1/user-data/').replace(
        queryParameters: {
          'fast': '1',
          // Defeats intermediary/CDN caches even when they ignore request
          // Cache-Control headers.
          '_': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        if (!silent) _error = 'Fetch failed: ${response.statusCode}';
        return;
      }

      final body = response.body;
      if (_data != null && _lastBody == body) {
        _lastUpdated = DateTime.now();
        unawaited(
          prefs.setInt(_cacheTsKey, _lastUpdated!.millisecondsSinceEpoch),
        );
        return;
      }

      final newData = await compute(_parseAppData, body);
      if (_disposed) return;

      _data = newData;
      _lastBody = body;
      _lastUpdated = DateTime.now();
      _error = null;
      _safeNotify();

      unawaited(_persist(prefs, body, _lastUpdated!));
    } catch (error) {
      if (!silent) _error = 'Error: $error';
      if (kDebugMode) debugPrint('AppDataProvider: fetch error: $error');
    } finally {
      if (!silent) {
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  Future<void> _persist(
    SharedPreferences prefs,
    String body,
    DateTime timestamp,
  ) async {
    try {
      await prefs.setString(_cacheKey, body);
      await prefs.setInt(_cacheTsKey, timestamp.millisecondsSinceEpoch);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('AppDataProvider: cache write error: $error');
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  List<String> get planTypes => _data?.planTypes ?? const [];
  List<NetworkDef> get networks => _data?.networks ?? const [];

  List<NetworkPlanItem> getPlansFor(int networkId, String type) {
    final network = _data?.networks.firstWhere(
      (item) => item.id == networkId,
      orElse: () => NetworkDef(
        name: '',
        id: -1,
        plansByType: const {},
        rechargeCardPricing: const [],
      ),
    );
    if (network == null || network.id == -1) return const [];
    return network.getPlans(type);
  }
}
