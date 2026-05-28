import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

Future<void> _initializeFirebaseApp() async {
  FirebaseOptions? dartOptions;
  try {
    dartOptions = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    dartOptions = null;
  }

  try {
    if (dartOptions != null) {
      await Firebase.initializeApp(options: dartOptions);
    } else {
      // Native-only setup: GoogleService-Info.plist / google-services.json.
      await Firebase.initializeApp();
    }
  } catch (e, st) {
    final msg = e.toString();
    final looksUnsetUp =
        msg.contains('not-initialized') ||
        msg.contains('not been correctly initialized') ||
        msg.contains('[core/not-initialized]');
    // Push is optional; don't spam the console when plist/json aren't added yet.
    if (kDebugMode && !looksUnsetUp) {
      debugPrint('Firebase init failed: $e\n$st');
    }
    rethrow;
  }
}

@pragma('vm:entry-point')
Future<void> nyusFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await _initializeFirebaseApp();
  } catch (_) {
    // No-op: push optional until Firebase files exist.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final StreamController<String> _articleTapController =
      StreamController<String>.broadcast();

  static Stream<String> get articleTapStream => _articleTapController.stream;

  static Future<void> initialize({
    required Future<void> Function(String token) onToken,
  }) async {
    try {
      await _initializeFirebaseApp();
    } catch (_) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(nyusFirebaseBackgroundHandler);
    final messaging = FirebaseMessaging.instance;

    // Session 2: permission is requested from the in-app nudge, not at startup.
    await _syncTokenIfAuthorized(messaging, onToken);

    messaging.onTokenRefresh.listen((token) async {
      try {
        await onToken(token);
      } catch (e, st) {
        debugPrint('onTokenRefresh handler failed: $e\n$st');
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenMessage);
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      _handleOpenMessage(initial);
    }
  }

  /// User-initiated permission prompt (Session 2 nudge).
  static Future<bool> requestUserPermission({
    required Future<void> Function(String token) onToken,
  }) async {
    try {
      await _initializeFirebaseApp();
    } catch (_) {
      return false;
    }

    final messaging = FirebaseMessaging.instance;
    try {
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (allowed) {
        await _syncTokenIfAuthorized(messaging, onToken);
      }
      return allowed;
    } catch (e, st) {
      debugPrint('requestUserPermission failed: $e\n$st');
      return false;
    }
  }

  static Future<void> _syncTokenIfAuthorized(
    FirebaseMessaging messaging,
    Future<void> Function(String token) onToken,
  ) async {
    try {
      final settings = await messaging.getNotificationSettings();
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!allowed) return;

      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await onToken(token);
      }
    } catch (e, st) {
      debugPrint('syncTokenIfAuthorized failed: $e\n$st');
    }
  }

  static void _handleOpenMessage(RemoteMessage message) {
    final data = message.data;
    final url = (data['article_url'] ?? data['url'] ?? '').toString().trim();
    if (url.isNotEmpty) {
      _articleTapController.add(url);
    }
  }
}
