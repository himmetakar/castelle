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
    appId: '1:977939722051:android:0933e402731f08098a49f6',
    messagingSenderId: '977939722051',
    projectId: 'castelle-ce64b',
    storageBucket: 'castelle-ce64b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDkiCwK6XeiyosXYuYfS33QoBgpioFgCWs',
    appId: '1:977939722051:ios:25cb7b9c0340f4ec8a49f6',
    messagingSenderId: '977939722051',
    projectId: 'castelle-ce64b',
    storageBucket: 'castelle-ce64b.firebasestorage.app',
    iosBundleId: 'com.castelleapp.app',
  );

  // iOS yapılandırması - Firebase Console'dan iOS app eklendiğinde güncellenecek
}