import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not supported.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not supported.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCN_mER9R15WAfw8pns7Aj_IOi-LA-8Y40',
    appId: '1:259457815318:android:dc97dd5ff0aa5b968cb637',
    messagingSenderId: '259457815318',
    projectId: 'mindspace-bdd68',
    storageBucket: 'mindspace-bdd68.firebasestorage.app',
  );
}