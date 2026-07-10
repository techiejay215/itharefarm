// lib/services/notification_sender.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

class NotificationSender {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // Send notification to all users except the current one
  static Future<void> sendToAllOtherUsers({
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Get all tokens from Firestore
    final tokenDocs = await _firestore
        .collectionGroup('tokens')
        .get();

    final tokens = tokenDocs.docs
        .map((doc) => doc['token'] as String)
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) return;

    // Send notification to each token using FCM
    for (final token in tokens) {
      await _sendFcmMessage(
        token: token,
        title: title,
        body: body,
        type: type,
        payload: payload,
      );
    }
  }

  static Future<void> _sendFcmMessage({
    required String token,
    required String title,
    required String body,
    required String type,
    String? payload,
  }) async {
    try {
      final Map<String, dynamic> message = {
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          'type': type,
          'payload': payload ?? '',
        },
        'token': token,
      };

      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Authorization': 'key=${await _getServerKey()}',
          'Content-Type': 'application/json',
              body: jsonEncode(message),
      );

      print('FCM response: ${response.body}');
    } catch (e) {
      print('Error sending FCM: $e');
    }
  }

  static Future<String> _getServerKey() async {
    // In production, retrieve from Firestore or secure storage
    // For now, we can store it in Firestore under 'config/fcm_server_key'
    try {
      final doc = await _firestore
          .collection('config')
          .doc('fcm_server_key')
          .get();
      return doc.exists ? doc['key'] as String : '';
    } catch (e) {
      print('Error retrieving server key: $e');
      return '';
    }
  }
}