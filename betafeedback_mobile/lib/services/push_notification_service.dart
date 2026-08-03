import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../screens/project_detail_screen.dart';
import 'api_client.dart';

/// Background handler must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Registers FCM tokens with the backend and routes notification taps.
class PushNotificationService {
  PushNotificationService({required ApiClient api}) : _api = api;

  final ApiClient _api;
  GlobalKey<NavigatorState>? navigatorKey;

  String? _currentToken;
  bool _initialized = false;
  VoidCallback? onForegroundMessage;

  Future<void> init() async {
    if (_initialized || !DefaultFirebaseOptions.isConfigured) {
      return;
    }
    _initialized = true;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen((_) {
      onForegroundMessage?.call();
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleMessage(initial);
    }

    messaging.onTokenRefresh.listen(_registerToken);
  }

  Future<void> registerForSignedInUser() async {
    if (!_initialized) return;
    final token = await _fetchFcmToken();
    if (token != null) {
      await _registerToken(token);
    }
  }

  Future<void> unregister() async {
    if (!_initialized) return;
    final token = _currentToken;
    if (token != null) {
      try {
        await _api.delete('/v1/devices', {'token': token});
      } catch (_) {}
      _currentToken = null;
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  /// On iOS, FCM requires an APNs token before [getToken] will succeed.
  Future<String?> _fetchFcmToken() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        final apnsReady = await _waitForApnsToken();
        if (!apnsReady) {
          debugPrint('APNs token unavailable; skipping FCM registration');
          return null;
        }
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  /// Polls until iOS hands us an APNs device token (or we give up).
  Future<bool> _waitForApnsToken({
    int attempts = 10,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    final messaging = FirebaseMessaging.instance;
    for (var i = 0; i < attempts; i++) {
      final apns = await messaging.getAPNSToken();
      if (apns != null) return true;
      await Future<void>.delayed(delay);
    }
    return false;
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    final platform = _platform;
    if (platform == null) return;
    try {
      await _api.post('/v1/devices', {'token': token, 'platform': platform});
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  void _handleMessage(RemoteMessage message) {
    final projectId = message.data['project_id'];
    if (projectId == null || projectId.isEmpty) return;
    final nav = navigatorKey?.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    );
  }

  String? get _platform {
    if (kIsWeb) return null;
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return null;
  }
}
