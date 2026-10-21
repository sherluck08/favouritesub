import 'dart:async';
import 'dart:convert';

import 'package:favouritesub/utils/api.dart';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AppNotificationKind {
  transactionSuccess,
  transactionProcessing,
  transactionFailed,
  cashback,
  announcement,
  system,
  generic,
}

AppNotificationKind notificationKindFromName(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'transactionsuccess':
    case 'transaction_success':
    case 'wallet_funding':
    case 'success':
      return AppNotificationKind.transactionSuccess;
    case 'transactionprocessing':
    case 'transaction_processing':
    case 'processing':
    case 'warning':
      return AppNotificationKind.transactionProcessing;
    case 'transactionfailed':
    case 'transaction_failed':
    case 'failed':
    case 'error':
      return AppNotificationKind.transactionFailed;
    case 'cashback':
      return AppNotificationKind.cashback;
    case 'announcement':
      return AppNotificationKind.announcement;
    case 'system':
    case 'info':
      return AppNotificationKind.system;
    default:
      return AppNotificationKind.generic;
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final AppNotificationKind kind;
  final DateTime createdAt;
  final bool read;
  final Map<String, dynamic>? meta;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.createdAt,
    this.read = false,
    this.meta,
  });

  String? get serverId {
    final value = meta?['server_id']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  AppNotification copyWith({
    String? title,
    String? body,
    AppNotificationKind? kind,
    DateTime? createdAt,
    bool? read,
    Map<String, dynamic>? meta,
  }) => AppNotification(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    kind: kind ?? this.kind,
    createdAt: createdAt ?? this.createdAt,
    read: read ?? this.read,
    meta: meta ?? this.meta,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'kind': kind.name,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
    if (meta != null) 'meta': meta,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      kind: notificationKindFromName(json['kind']?.toString()),
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
      read: json['read'] == true,
      meta: json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : null,
    );
  }

  factory AppNotification.fromServerJson(Map<String, dynamic> json) {
    final serverId = (json['id'] ?? '').toString().trim();
    final data = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final eventId = (json['event_id'] ?? data['event_id'] ?? '')
        .toString()
        .trim();

    var title = (json['title'] ?? json['verb'] ?? '').toString().trim();
    var body = (json['body'] ?? json['description'] ?? '').toString().trim();
    if (title.isEmpty && body.isEmpty) {
      title = 'Account update';
      body = 'You have a new notification.';
    } else if (body.isEmpty) {
      body = title;
      title = 'Account update';
    } else if (title.isEmpty) {
      title = 'Account update';
    }

    return AppNotification(
      id: eventId.isNotEmpty ? eventId : 'server_$serverId',
      title: title,
      body: body,
      kind: notificationKindFromName(
        json['kind']?.toString() ??
            data['kind']?.toString() ??
            json['level']?.toString(),
      ),
      createdAt:
          DateTime.tryParse(
            (json['created_at'] ?? json['timestamp'] ?? '').toString(),
          )?.toLocal() ??
          DateTime.now(),
      read: json['read'] == true || json['unread'] == false,
      meta: {
        ...data,
        if (serverId.isNotEmpty) 'server_id': serverId,
        if (eventId.isNotEmpty) 'event_id': eventId,
      },
    );
  }
}

class NotificationStore extends ChangeNotifier {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  static const _prefsKeyBase = 'app_notifications_v2';
  static const _legacyPrefsKeyBase = 'app_notifications_v1';
  static const int _maxItems = 200;
  static const int _maxTombstones = 500;

  final List<AppNotification> _items = [];
  final Set<String> _deletedServerIds = {};
  final Set<String> _deletedEventIds = {};
  Future<void> _operationQueue = Future<void>.value();
  Future<bool>? _syncInFlight;
  bool _loaded = false;
  bool _syncing = false;
  String _scope = 'guest';

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((item) => !item.read).length;
  bool get hasUnread => unreadCount > 0;
  bool get isLoaded => _loaded;
  bool get isSyncing => _syncing;

  String get _prefsKey => '${_prefsKeyBase}_$_scope';
  String get _deletedPrefsKey => '${_prefsKey}_deleted';

  Future<T> _serialize<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> ensureLoaded() {
    return _serialize(_ensureLoadedUnlocked);
  }

  Future<void> _ensureLoadedUnlocked() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _scope = _resolveScope(prefs);
    await _loadFromPreferences(prefs);
    _loaded = true;
    notifyListeners();
  }

  Future<void> rebindToCurrentUser() async {
    await _serialize(() async {
      _loaded = false;
      _items.clear();
      _deletedServerIds.clear();
      _deletedEventIds.clear();
      notifyListeners();
      await _ensureLoadedUnlocked();
    });
    await syncFromBackend();
  }

  Future<void> add({
    required String title,
    required String body,
    required AppNotificationKind kind,
    Map<String, dynamic>? meta,
    String? id,
    DateTime? createdAt,
  }) {
    return _serialize(() async {
      await _ensureLoadedUnlocked();
      await _mergeLatestDiskState();

      final notificationId = id?.trim().isNotEmpty == true
          ? id!.trim()
          : 'local_${DateTime.now().microsecondsSinceEpoch}';
      if (_deletedEventIds.contains(notificationId)) return;
      final incoming = AppNotification(
        id: notificationId,
        title: title.trim(),
        body: body.trim(),
        kind: kind,
        createdAt: createdAt?.toLocal() ?? DateTime.now(),
        read: false,
        meta: meta,
      );
      _upsert(incoming);
      _sortAndTrim();
      await _persist();
      notifyListeners();
    });
  }

  Future<void> markAsRead(String id) {
    return _serialize(() async {
      await _ensureLoadedUnlocked();
      final index = _items.indexWhere((item) => item.id == id);
      if (index == -1 || _items[index].read) return;
      final serverId = _items[index].serverId;
      _items[index] = _items[index].copyWith(read: true);
      await _persist();
      notifyListeners();
      if (serverId != null) unawaited(_markRemoteAsRead(serverId));
    });
  }

  Future<void> markAllAsRead() {
    return _serialize(() async {
      await _ensureLoadedUnlocked();
      if (_items.every((item) => item.read)) return;
      for (var index = 0; index < _items.length; index++) {
        if (!_items[index].read) {
          _items[index] = _items[index].copyWith(read: true);
        }
      }
      await _persist();
      notifyListeners();
      unawaited(_markAllRemoteAsRead());
    });
  }

  Future<void> remove(String id) {
    return _serialize(() async {
      await _ensureLoadedUnlocked();
      final index = _items.indexWhere((item) => item.id == id);
      if (index == -1) return;
      final serverId = _items[index].serverId;
      _rememberDeletedEvent(_items[index].id);
      _items.removeAt(index);
      if (serverId != null) _rememberDeleted(serverId);
      await _persist();
      notifyListeners();
      if (serverId != null) unawaited(_deleteRemote(serverId));
    });
  }

  Future<void> clearAll() {
    return _serialize(() async {
      await _ensureLoadedUnlocked();
      if (_items.isEmpty) return;
      for (final item in _items) {
        _rememberDeletedEvent(item.id);
        final serverId = item.serverId;
        if (serverId != null) _rememberDeleted(serverId);
      }
      _items.clear();
      await _persist();
      notifyListeners();
      unawaited(_deleteAllRemote());
    });
  }

  Future<bool> syncFromBackend() {
    final running = _syncInFlight;
    if (running != null) return running;
    final future = _syncFromBackend();
    _syncInFlight = future;
    return future.whenComplete(() => _syncInFlight = null);
  }

  Future<bool> _syncFromBackend() async {
    await ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final accessToken = prefs.getString('access_token');
    if (accessToken == null || accessToken.isEmpty) return false;

    _syncing = true;
    notifyListeners();
    try {
      final response = await http
          .get(
            Api.uri('/api/v1/notifications/?limit=$_maxItems'),
            headers: _headers(accessToken),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) return false;

      final decoded = jsonDecode(response.body);
      final rawItems = decoded is List
          ? decoded
          : decoded is Map && decoded['results'] is List
          ? decoded['results'] as List
          : const <dynamic>[];
      final remoteItems = rawItems
          .whereType<Map>()
          .map(
            (item) =>
                AppNotification.fromServerJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty)
          .toList();

      await _serialize(() async {
        await _ensureLoadedUnlocked();
        await _mergeLatestDiskState();
        for (final item in remoteItems) {
          final serverId = item.serverId;
          if (!_deletedEventIds.contains(item.id) &&
              (serverId == null || !_deletedServerIds.contains(serverId))) {
            _upsert(item);
          }
        }
        _sortAndTrim();
        await _persist();
        notifyListeners();
      });
      return true;
    } catch (error) {
      if (kDebugMode) debugPrint('Notification sync failed: $error');
      return false;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromPreferences(SharedPreferences prefs) async {
    _items.clear();
    _deletedServerIds.clear();
    _deletedEventIds.clear();

    var raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      final token = prefs.getString('access_token');
      if (token != null && token.isNotEmpty) {
        final oldScope = token.hashCode.toUnsigned(32).toRadixString(16);
        raw = prefs.getString('${_legacyPrefsKeyBase}_$oldScope');
      }
    }
    _decodeItems(raw, into: _items);

    final rawDeleted = prefs.getString(_deletedPrefsKey);
    if (rawDeleted != null && rawDeleted.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDeleted);
        if (decoded is List) {
          _deletedServerIds.addAll(
            decoded
                .map((value) => value.toString())
                .where((id) => id.isNotEmpty),
          );
        } else if (decoded is Map) {
          _deletedServerIds.addAll(_stringValues(decoded['server_ids']));
          _deletedEventIds.addAll(_stringValues(decoded['event_ids']));
        }
      } catch (_) {
        // A corrupt tombstone cache should never make the inbox unusable.
      }
    }
    _sortAndTrim();
    if (raw != null && prefs.getString(_prefsKey) == null) await _persist();
  }

  Future<void> _mergeLatestDiskState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final diskItems = <AppNotification>[];
    _decodeItems(prefs.getString(_prefsKey), into: diskItems);
    for (final item in diskItems) {
      _upsert(item);
    }

    final rawDeleted = prefs.getString(_deletedPrefsKey);
    if (rawDeleted != null && rawDeleted.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDeleted);
        if (decoded is List) {
          _deletedServerIds.addAll(decoded.map((value) => value.toString()));
        } else if (decoded is Map) {
          _deletedServerIds.addAll(_stringValues(decoded['server_ids']));
          _deletedEventIds.addAll(_stringValues(decoded['event_ids']));
        }
      } catch (_) {
        // Keep the valid in-memory state.
      }
    }
  }

  void _decodeItems(String? raw, {required List<AppNotification> into}) {
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final value in decoded.whereType<Map>()) {
        try {
          final item = AppNotification.fromJson(
            Map<String, dynamic>.from(value),
          );
          if (item.id.isNotEmpty &&
              item.title.isNotEmpty &&
              item.body.isNotEmpty) {
            into.add(item);
          }
        } catch (_) {
          // Skip one malformed entry instead of discarding the entire inbox.
        }
      }
    } catch (_) {
      // Ignore an unreadable cache; the next backend sync can rebuild it.
    }
  }

  void _upsert(AppNotification incoming) {
    final index = _items.indexWhere((item) => item.id == incoming.id);
    if (index == -1) {
      _items.add(incoming);
      return;
    }

    final current = _items[index];
    _items[index] = incoming.copyWith(
      read: current.read || incoming.read,
      meta: {...?current.meta, ...?incoming.meta},
      createdAt: current.createdAt.isBefore(incoming.createdAt)
          ? current.createdAt
          : incoming.createdAt,
    );
  }

  void _sortAndTrim() {
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
  }

  void _rememberDeleted(String serverId) {
    _deletedServerIds.add(serverId);
    _trimTombstones();
  }

  void _rememberDeletedEvent(String eventId) {
    _deletedEventIds.add(eventId);
    _trimTombstones();
  }

  void _trimTombstones() {
    while (_deletedServerIds.length + _deletedEventIds.length >
        _maxTombstones) {
      if (_deletedEventIds.isNotEmpty) {
        _deletedEventIds.remove(_deletedEventIds.first);
      } else {
        _deletedServerIds.remove(_deletedServerIds.first);
      }
    }
  }

  Iterable<String> _stringValues(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw.map((value) => value.toString()).where((id) => id.isNotEmpty);
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(_items.map((item) => item.toJson()).toList()),
      );
      await prefs.setString(
        _deletedPrefsKey,
        jsonEncode({
          'server_ids': _deletedServerIds.toList(),
          'event_ids': _deletedEventIds.toList(),
        }),
      );
    } catch (error) {
      if (kDebugMode) debugPrint('NotificationStore persist failed: $error');
    }
  }

  Future<void> _markRemoteAsRead(String serverId) async {
    await _remoteRequest(
      (token) => http.patch(
        Api.uri('/api/v1/notifications/$serverId/'),
        headers: _headers(token),
        body: jsonEncode({'read': true}),
      ),
    );
  }

  Future<void> _markAllRemoteAsRead() async {
    await _remoteRequest(
      (token) => http.post(
        Api.uri('/api/v1/read-notifications/'),
        headers: _headers(token),
      ),
    );
  }

  Future<void> _deleteRemote(String serverId) async {
    await _remoteRequest(
      (token) => http.delete(
        Api.uri('/api/v1/notifications/$serverId/'),
        headers: _headers(token),
      ),
    );
  }

  Future<void> _deleteAllRemote() async {
    await _remoteRequest(
      (token) => http.delete(
        Api.uri('/api/v1/notifications/'),
        headers: _headers(token),
      ),
    );
  }

  Future<void> _remoteRequest(
    Future<http.Response> Function(String token) request,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) return;
      await request(token).timeout(const Duration(seconds: 10));
    } catch (error) {
      if (kDebugMode) debugPrint('Notification update failed: $error');
    }
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  String _resolveScope(SharedPreferences prefs) {
    final identity =
        (prefs.getString('email') ?? prefs.getString('saved_username'))
            ?.trim()
            .toLowerCase();
    if (identity == null || identity.isEmpty) return 'guest';

    var hash = 0x811c9dc5;
    for (final codeUnit in identity.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'user_${hash.toUnsigned(32).toRadixString(16)}';
  }
}
