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
    apiKey: 'AIzaSyCWojyTDMo7dMFF5xQrQOkRfNSjcbooIMg',
    appId: '1:977939722051:android:26e1b5da9273acfc8a49f6',
    messagingSenderId: '977939722051',
    projectId: 'castelle-ce64b',
    storageBucket: 'castelle-ce64b.firebasestorage.app',
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