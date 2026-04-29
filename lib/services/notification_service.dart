import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'runtime_config_service.dart';

/// Top-level background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'pulsecity_notifications';
  static const _channelName = 'PulseCity Bildirimleri';
  static const _channelDescription = 'Mesajlar, eşleşmeler ve sosyal bildirimler';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

    // Setup local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Handle notification open (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

    // Check if app was launched from notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationData(initialMessage.data);
    }

    // Register token with backend
    await _registerToken();

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_onTokenRefresh);

    _initialized = true;
  }

  Future<void> _registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null && token.isNotEmpty) {
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    debugPrint('[FCM] Token refreshed');
    await _sendTokenToBackend(token);
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      final authService = AuthService();
      if (!authService.isLoggedIn) return;

      final baseUrl = RuntimeConfigService.backendBaseUrl.trim();
      if (baseUrl.isEmpty) return;

      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/device-tokens',
      );
      final headers = await authService.authorizedHeaders();
      headers['Content-Type'] = 'application/json';
      headers['ngrok-skip-browser-warning'] = 'true';

      await http.post(
        uri,
        headers: headers,
        body: json.encode({'token': token, 'platform': 'android'}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Failed to send token to backend: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) return;

      final authService = AuthService();
      if (!authService.isLoggedIn) return;

      final baseUrl = RuntimeConfigService.backendBaseUrl.trim();
      if (baseUrl.isEmpty) return;

      final uri = Uri.parse(
        '${baseUrl.replaceFirst(RegExp(r'/$'), '')}/api/device-tokens',
      );
      final headers = await authService.authorizedHeaders();
      headers['Content-Type'] = 'application/json';
      headers['ngrok-skip-browser-warning'] = 'true';

      await http.delete(
        uri,
        headers: headers,
        body: json.encode({'token': token}),
      ).timeout(const Duration(seconds: 10));

      await _fcm.deleteToken();
      debugPrint('[FCM] Token unregistered');
    } catch (e) {
      debugPrint('[FCM] Failed to unregister token: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: json.encode(message.data),
    );
  }

  void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('[FCM] Notification opened app: ${message.data}');
    _handleNotificationData(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[FCM] Notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!) as Map<String, dynamic>;
        _handleNotificationData(data);
      } catch (_) {}
    }
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    final type = data['type'];
    debugPrint('[FCM] Handling notification type: $type, data: $data');
    // Navigation can be added here later using rootNavigatorKey
    // For now, just logging. The app will open to the appropriate screen
    // based on the notification type when full navigation is wired up.
  }
}
