import 'dart:async';
import 'dart:convert';

import 'package:favouritesub/screens/login_screen.dart';
import 'package:favouritesub/utils/api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

export 'package:http/http.dart';

Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
    SessionHttp.get(url, headers: headers);

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => SessionHttp.post(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => SessionHttp.patch(url, headers: headers, body: body, encoding: encoding);

Future<http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => SessionHttp.delete(url, headers: headers, body: body, encoding: encoding);

enum _RefreshResultType { refreshed, invalid, unavailable }

class _RefreshResult {
  const _RefreshResult(this.type, [this.accessToken]);
  final _RefreshResultType type;
  final String? accessToken;
}

/// Central authenticated HTTP entry point. A 401 is retried once after a
/// serialized refresh, so concurrent API calls cannot rotate the same refresh
/// token multiple times.
class SessionHttp {
  SessionHttp._();

  static final http.Client _client = http.Client();
  static Future<_RefreshResult>? _refreshInFlight;

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _send((next) => _client.get(url, headers: next), headers);

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _send(
    (next) => _client.post(url, headers: next, body: body, encoding: encoding),
    headers,
  );

  static Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _send(
    (next) => _client.patch(url, headers: next, body: body, encoding: encoding),
    headers,
  );

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _send(
    (next) =>
        _client.delete(url, headers: next, body: body, encoding: encoding),
    headers,
  );

  static Future<http.Response> _send(
    Future<http.Response> Function(Map<String, String>? headers) request,
    Map<String, String>? headers,
  ) async {
    final response = await request(headers);
    final authorization = headers?['Authorization'];
    if (response.statusCode != 401 || authorization == null) return response;

    final result = await _refreshAccessToken();
    if (result.type == _RefreshResultType.refreshed) {
      final retryHeaders = Map<String, String>.from(headers!);
      retryHeaders['Authorization'] = 'Bearer ${result.accessToken}';
      return request(retryHeaders);
    }
    if (result.type == _RefreshResultType.invalid) {
      unawaited(SessionCoordinator.instance.expireSession());
    }
    return response;
  }

  static Future<_RefreshResult> _refreshAccessToken() {
    final running = _refreshInFlight;
    if (running != null) return running;
    final operation = _performRefresh();
    _refreshInFlight = operation;
    return operation.whenComplete(() => _refreshInFlight = null);
  }

  static Future<_RefreshResult> _performRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString('refresh_token');
      if (refresh == null || refresh.isEmpty) {
        return const _RefreshResult(_RefreshResultType.invalid);
      }
      final response = await _client
          .post(
            Api.uri('/api/v1/token/refresh/'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final access = body['access']?.toString() ?? '';
        if (access.isEmpty) {
          return const _RefreshResult(_RefreshResultType.invalid);
        }
        await prefs.setString('access_token', access);
        final rotatedRefresh = body['refresh']?.toString();
        if (rotatedRefresh != null && rotatedRefresh.isNotEmpty) {
          await prefs.setString('refresh_token', rotatedRefresh);
        }
        return _RefreshResult(_RefreshResultType.refreshed, access);
      }
      if (response.statusCode == 400 || response.statusCode == 401) {
        return const _RefreshResult(_RefreshResultType.invalid);
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Session refresh temporarily unavailable: $error');
      }
    }
    return const _RefreshResult(_RefreshResultType.unavailable);
  }
}

class SessionCoordinator {
  SessionCoordinator._();
  static final SessionCoordinator instance = SessionCoordinator._();

  GlobalKey<NavigatorState>? _navigatorKey;
  GlobalKey<ScaffoldMessengerState>? _messengerKey;
  bool _expiring = false;

  void configure({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
  }) {
    _navigatorKey = navigatorKey;
    _messengerKey = messengerKey;
  }

  Future<void> expireSession() async {
    if (_expiring) return;
    _expiring = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      await prefs.remove('email');

      final navigator = _navigatorKey?.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey?.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Your session has expired. Please sign in again to continue.',
              ),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 6),
            ),
          );
      });
    } finally {
      _expiring = false;
    }
  }
}
