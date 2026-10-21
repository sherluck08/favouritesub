import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:favouritesub/utils/api.dart';
import 'package:favouritesub/services/push_notification_service.dart';
import 'package:favouritesub/services/notification_store.dart';

class AuthState {
  final bool isLoading;
  final String? token;
  final String? error;
  final String? email;

  AuthState({this.isLoading = false, this.token, this.error, this.email});

  AuthState copyWith({
    bool? isLoading,
    String? token,
    String? error,
    String? email,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: token ?? this.token,
      error: error,
      email: email ?? this.email,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  AuthState _state = AuthState();

  AuthState get state => _state;

  bool get isLoading => _state.isLoading;
  String? get token => _state.token;
  String? get error => _state.error;
  String? get email => _state.email;

  Future<void> login(String username, String password) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final response = await http
          .post(
            Uri.parse('${Api.base}/api/v1/authorize/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (kDebugMode) debugPrint('Login response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        await prefs.setString('email', data['email']);

        await saveUsername(username.trim());

        await _ensureDeviceId(prefs);

        _state = _state.copyWith(
          isLoading: false,
          token: data['access'],
          email: data['email'],
        );
        notifyListeners();

        // Authentication is complete once the tokens are persisted. These
        // integrations must never delay the user's first dashboard frame.
        unawaited(_enableBiometricsOnServer(enabled: true));
        unawaited(PushNotificationService.instance.syncTokenWithBackend());
        unawaited(NotificationStore.instance.rebindToCurrentUser());
        return;
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: data['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Login failed: $e');
      _state = _state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Check your network.',
      );
    }

    notifyListeners();
  }

  Future<bool> signup({
    required String fullName,
    required String username,
    required String email,
    required String phone,
    required String address,
    String? referralUsername,
    required String password,
    String? baseUrlOverride,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final uri = Uri.parse('${Api.base}/api/registration/');
      final payload = <String, dynamic>{
        'FullName': fullName.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'Phone': phone.trim(),
        'Address': address.trim(),
        'referer_username': (referralUsername ?? '').trim(),
        'password': password,
      };
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        return true;
      } else {
        String message = 'Sign up failed';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body.isNotEmpty) {
            message = body.values.first.toString();
          } else if (body is String) {
            message = body;
          }
        } catch (_) {}
        _state = _state.copyWith(isLoading: false, error: message);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Check your network.',
      );
      notifyListeners();
      return false;
    }
  }

  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('saved_username');
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_username', username);
  }

  Future<void> clearSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_username');
  }

  Future<bool> biometricLogin() async {
    _state = _state.copyWith(isLoading: true, error: null);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString('refresh_token');
      if (refresh == null || refresh.isEmpty) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'No saved session. Login with password.',
        );
        notifyListeners();
        return false;
      }

      final resp = await http
          .post(
            Uri.parse('${Api.base}/api/v1/token/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final body = jsonDecode(resp.body);
        final newAccess = body['access'] ?? body['access_token'] ?? '';
        if (newAccess is String && newAccess.isNotEmpty) {
          await prefs.setString('access_token', newAccess);
          final rotatedRefresh = body['refresh']?.toString();
          if (rotatedRefresh != null && rotatedRefresh.isNotEmpty) {
            await prefs.setString('refresh_token', rotatedRefresh);
          }
          _state = _state.copyWith(isLoading: false, token: newAccess);
          notifyListeners();

          unawaited(_enableBiometricsOnServer(enabled: true));
          unawaited(PushNotificationService.instance.syncTokenWithBackend());
          unawaited(NotificationStore.instance.rebindToCurrentUser());
          return true;
        } else {
          _state = _state.copyWith(
            isLoading: false,
            error: 'Invalid token refresh response',
          );
          notifyListeners();
          return false;
        }
      } else {
        String message = 'Token refresh failed';
        try {
          final body = jsonDecode(resp.body);
          message =
              body['detail']?.toString() ??
              body['message']?.toString() ??
              message;
        } catch (_) {}
        _state = _state.copyWith(isLoading: false, error: message);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Biometric login failed: $e',
      );
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> fetchUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        if (kDebugMode) {
          debugPrint('No access token found');
        }
        return null;
      }

      final response = await http.get(
        Uri.parse('${Api.base}/api/v1/user-data/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        debugPrint('User data response status: ${response.statusCode}');
        debugPrint('User data response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        if (kDebugMode) {
          debugPrint('Failed to fetch user data: ${response.statusCode}');
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching user data: $e');
      }
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await PushNotificationService.instance.unregisterToken();
    } catch (_) {}
    await prefs.clear();
    await NotificationStore.instance.rebindToCurrentUser();
    _state = AuthState();
    notifyListeners();
  }

  Future<void> _enableBiometricsOnServer({required bool enabled}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final access = prefs.getString('access_token');
      if (access == null || access.isEmpty) return;
      final deviceId = await _ensureDeviceId(prefs);
      await http
          .post(
            Uri.parse('${Api.base}/api/v1/biometrics-login/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $access',
            },
            body: jsonEncode({'biometrics': enabled, 'user_device': deviceId}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  Future<String> _ensureDeviceId([SharedPreferences? existing]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    final current = prefs.getString('device_id');
    if (current != null && current.isNotEmpty) return current;
    final rand = Random();
    final seed = DateTime.now().microsecondsSinceEpoch ^ rand.nextInt(1 << 32);
    final generated = seed.toRadixString(16).padLeft(16, '0');
    await prefs.setString('device_id', generated);
    return generated;
  }
}
