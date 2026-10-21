import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:favouritesub/services/session_http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:favouritesub/services/notification_store.dart';
import 'package:favouritesub/utils/api.dart';

/// Background message handler (must remain a top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService.instance.persistRemoteMessage(message);
  if (kDebugMode) {
    debugPrint('Background notification: ${message.messageId}');
  }
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleInteraction);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      if (kDebugMode) {
        debugPrint('Push permission denied; the in-app inbox remains active.');
      }
    }

    await _setupLocalNotifications();
    await _refreshAndPersistToken();

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await persistRemoteMessage(initialMessage);
    }

    _messaging.onTokenRefresh.listen((token) async {
      await _cacheToken(token);
      await syncTokenWithBackend();
    });
  }

  Future<void> _refreshAndPersistToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) debugPrint('No FCM token returned yet.');
        return;
      }
      await _cacheToken(token);
      await syncTokenWithBackend();
    } catch (error) {
      if (kDebugMode) debugPrint('Could not refresh FCM token: $error');
    }
  }

  Future<void> syncTokenWithBackend() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      final accessToken = prefs.getString('access_token');

      if (token == null || accessToken == null || accessToken.isEmpty) {
        if (kDebugMode) {
          debugPrint('Skipping token sync: missing FCM token or auth token');
        }
        return;
      }

      final platform = Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
          ? 'android'
          : 'web';
      final deviceName = Platform.isIOS
          ? 'iOS Device'
          : Platform.isAndroid
          ? 'Android Device'
          : 'Web';

      final response = await http
          .post(
            Api.uri('/api/device-tokens/register/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'token': token,
              'platform': platform,
              'device_name': deviceName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (kDebugMode) debugPrint('FCM token registered with backend.');
      } else if (kDebugMode) {
        debugPrint('FCM token registration failed: ${response.statusCode}');
      }
    } catch (error) {
      if (kDebugMode) debugPrint('Could not sync FCM token: $error');
    }
  }

  Future<void> unregisterToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('fcm_token');
    final accessToken = prefs.getString('access_token');

    if (token != null && accessToken != null && accessToken.isNotEmpty) {
      try {
        await http
            .post(
              Api.uri('/api/device-tokens/unregister/'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
              body: jsonEncode({'token': token}),
            )
            .timeout(const Duration(seconds: 5));
      } catch (error) {
        if (kDebugMode) debugPrint('Could not unregister FCM token: $error');
      }
    }

    await prefs.remove('fcm_token');
  }

  Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == null) return;
        try {
          jsonDecode(response.payload!);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to parse notification payload: $e');
          }
        }
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'Used for important notifications',
        importance: Importance.max,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    await persistRemoteMessage(message);
    final content = _contentOf(message);
    if (content == null) return;

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Used for important notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.messageId?.hashCode ?? content.title.hashCode,
      content.title,
      content.body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  /// Displays an app-generated notification, for example after a transaction
  /// finishes while the confirmation flow is open.
  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Used for important notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _localNotifications.show(
        id ?? DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title,
        body,
        details,
        payload: payload,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('Could not show local notification: $error');
    }
  }

  Future<void> persistRemoteMessage(RemoteMessage message) async {
    final content = _contentOf(message);
    if (content == null) return;
    final eventId = _firstNonEmpty([
      message.data['event_id'],
      message.data['notification_id'],
      message.messageId,
    ]);
    final fallbackId = Object.hash(
      content.title,
      content.body,
      message.sentTime?.millisecondsSinceEpoch,
    ).toUnsigned(32).toRadixString(16);

    await NotificationStore.instance.add(
      id: eventId ?? 'remote_$fallbackId',
      title: content.title,
      body: content.body,
      kind: notificationKindFromName(message.data['kind']?.toString()),
      createdAt: message.sentTime,
      meta: Map<String, dynamic>.from(message.data),
    );
  }

  Future<void> _handleInteraction(RemoteMessage message) async {
    await persistRemoteMessage(message);
    if (kDebugMode) {
      debugPrint('Notification interaction payload: ${message.data}');
    }
  }

  _RemoteNotificationContent? _contentOf(RemoteMessage message) {
    final title = _firstNonEmpty([
      message.notification?.title,
      message.data['title'],
      message.data['notification_title'],
    ]);
    final body = _firstNonEmpty([
      message.notification?.body,
      message.data['body'],
      message.data['message'],
      message.data['description'],
    ]);
    if (title == null && body == null) return null;
    return _RemoteNotificationContent(
      title: title ?? 'FavoriteSub update',
      body: body ?? 'You have a new notification.',
    );
  }

  String? _firstNonEmpty(Iterable<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  Future<void> _cacheToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }
}

class _RemoteNotificationContent {
  final String title;
  final String body;

  const _RemoteNotificationContent({required this.title, required this.body});
}
