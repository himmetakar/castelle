// Castelle - Firebase Yapılandırma Dosyası
// google-services.json'dan alınan gerçek değerler

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions: $defaultTargetPlatform platformu desteklenmiyor.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-xf-3xJWBwbDErNHkzI51m5nXNvlmrmM',
    appId: '1:58376999425:android:4d164708a5e06fd594a600',
    messagingSenderId: '58376999425',
    projectId: 'castelle-9ab2c',
    storageBucket: 'castelle-9ab2c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBgTqxtxY9Wiyhm3VFow1siYKSITVcSiXc',
    appId: '1:58376999425:ios:a1ec80cead80d17a94a600',
    messagingSenderId: '58376999425',
    projectId: 'castelle-9ab2c',
    storageBucket: 'castelle-9ab2c.firebasestorage.app',
    iosBundleId: 'com.castelle.odiapp',
  );

  // iOS yapılandırması - Firebase Console'dan iOS app eklendiğinde güncellenecek
}