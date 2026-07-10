// lib/services/notification_service.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static String? _fcmToken;
  static bool _isInitialized = false;
  static GlobalKey<NavigatorState>? navigatorKey;

  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  static String? getFCMToken() => _fcmToken;

  // -----------------------------------------------------------------
  //  Initialize (foreground)
  // -----------------------------------------------------------------
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('Push notifications not authorized');
        return;
      }

      _fcmToken = await _fcm.getToken();
      print('FCM Token: $_fcmToken');

      // Create the Android channel (once)
      await _createNotificationChannel();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        saveTokenToServer();
      });

      // Foreground message listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        _showPopupNotification(message);
      });

      // Handle taps when app is opened from a notification
      FirebaseMessaging.instance.getInitialMessage().then(_handleMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);

      _isInitialized = true;
    } catch (e) {
      print('Notification initialization error: $e');
    }
  }

  // -----------------------------------------------------------------
  //  Background handler (called from main.dart)
  // -----------------------------------------------------------------
  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    // Re‑initialize the local notifications plugin
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);

    // IMPORTANT: recreate the channel (background doesn't have it)
    await _createNotificationChannel();

    // Show the notification
    await _showPopupNotification(message);
  }

  // -----------------------------------------------------------------
  //  Helper: create Android notification channel
  // -----------------------------------------------------------------
  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ithare_farm_channel',
      'Ithare Farm Notifications',
      description: 'Important alerts and reminders from Ithare Farm',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      enableLights: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // -----------------------------------------------------------------
  //  Display a heads‑up notification (foreground & background)
  // -----------------------------------------------------------------
  static Future<void> _showPopupNotification(RemoteMessage message) async {
    // Use data fields if notification is null, otherwise use notification
    final title = message.data['title'] ?? message.notification?.title ?? 'Ithare Farm';
    final body = message.data['body'] ?? message.notification?.body ?? '';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ithare_farm_channel',
      'Ithare Farm Notifications',
      channelDescription: 'Important alerts and reminders from Ithare Farm',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: jsonEncode(message.data),
    );
  }

  // Optional: use this method to show a custom notification from code
  static Future<void> showPopupNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'ithare_farm_channel',
      'Ithare Farm Notifications',
      channelDescription: 'Important alerts and reminders from Ithare Farm',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  // -----------------------------------------------------------------
  //  Handle notification tap
  // -----------------------------------------------------------------
  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null && navigatorKey?.currentContext != null) {
      final data = response.payload;
      if (data?.contains('vaccination') == true ||
          data?.contains('health') == true) {
        navigatorKey?.currentState?.pushNamed('/health');
      } else if (data?.contains('calving') == true ||
          data?.contains('breeding') == true) {
        navigatorKey?.currentState?.pushNamed('/breeding');
      } else if (data?.contains('low_stock') == true ||
          data?.contains('inventory') == true) {
        navigatorKey?.currentState?.pushNamed('/inventory');
      } else if (data?.contains('payment') == true ||
          data?.contains('sales') == true) {
        navigatorKey?.currentState?.pushNamed('/sales');
      } else {
        navigatorKey?.currentState?.pushNamed('/notifications');
      }
    }
  }

  static void _handleMessage(RemoteMessage? message) {
    if (message == null) return;
    print('Notification clicked: ${message.data['title'] ?? message.notification?.title}');

    final type = message.data['type'];
    if (type == 'vaccination' || type == 'health') {
      navigatorKey?.currentState?.pushNamed('/health');
    } else if (type == 'calving' || type == 'breeding') {
      navigatorKey?.currentState?.pushNamed('/breeding');
    } else if (type == 'low_stock' || type == 'inventory') {
      navigatorKey?.currentState?.pushNamed('/inventory');
    } else if (type == 'payment' || type == 'sales') {
      navigatorKey?.currentState?.pushNamed('/sales');
    } else {
      navigatorKey?.currentState?.pushNamed('/notifications');
    }
  }

  // -----------------------------------------------------------------
  //  Token management (fixed: creates user document)
  // -----------------------------------------------------------------
  static Future<void> saveTokenToServer() async {
    if (_fcmToken == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    // 1. Create/update the user document (ensures parent exists)
    await userDocRef.set({
      'uid': user.uid,
      'email': user.email,
      'name': user.displayName ?? 'Farmer',
      'last_active': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Save the token as a subcollection
    await userDocRef.collection('tokens').doc(_fcmToken).set({
      'token': _fcmToken,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // -----------------------------------------------------------------
  //  Topic management (optional)
  // -----------------------------------------------------------------
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }
}