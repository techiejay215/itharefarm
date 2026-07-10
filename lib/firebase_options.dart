import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not supported');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC-Gup8AwM8g-mwdlGpva3H95P1gb0dW3w',
    appId: '1:191876069585:android:fc2d0c444d071b49186df0',
    messagingSenderId: '191876069585',
    projectId: 'itharefarmsync-a57ff',
    storageBucket: 'itharefarmsync-a57ff.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '191876069585',
    projectId: 'itharefarmsync-a57ff',
    storageBucket: 'itharefarmsync-a57ff.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'YOUR_IOS_BUNDLE_ID',
  );
}