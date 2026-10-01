import 'package:flutter/foundation.dart';

export 'package:flutter/foundation.dart' show kIsWeb;

/// Castelle - Web-güvenli platform kontrolleri
///
/// `dart:io` içindeki `Platform.isAndroid` / `Platform.isIOS` web'de
/// `UnsupportedError` fırlatır. Bu getter'lar web'de `false` döner.
bool get isAndroidApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get isIOSApp => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
