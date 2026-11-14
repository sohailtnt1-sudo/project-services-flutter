// FCM push notifications for Project Services.
// - Requests permission, saves the device token to Supabase (device_tokens)
//   and keeps it fresh on refresh.
// - Foreground messages are shown as a SnackBar via the app's
//   ScaffoldMessenger key (see main.dart).
// - Background / terminated messages are delivered by the system tray
//   automatically (notification payload); the background handler only
//   initialises Firebase so the isolate is ready.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../repository.dart';

/// Must be a top-level function for background messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  /// Set by main.dart so foreground messages can show a SnackBar anywhere.
  static GlobalKey<ScaffoldMessengerState>? messengerKey;

  /// Initialise Firebase + FCM. Safe to call even when google-services.json
  /// is not configured yet — it logs the failure and the app keeps working
  /// without push notifications.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init failed (push disabled): $e');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await saveDeviceToken(token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        await saveDeviceToken(t);
      });
      FirebaseMessaging.onMessage.listen(_showForegroundMessage);
    } catch (e) {
      debugPrint('FCM setup failed (push disabled): $e');
    }
  }

  static void _showForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Project Services';
    final body = message.notification?.body ?? '';
    final key = messengerKey;
    if (key?.currentState == null) return;
    key!.currentState!.showSnackBar(
      SnackBar(
        content: Text(body.isEmpty ? title : '$title: $body'),
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
