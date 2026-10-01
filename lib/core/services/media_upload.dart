import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Castelle - Platformdan bağımsız medya yükleme / önizleme
///
/// Mobilde seçilen dosyalar diskte bir yol (`/data/...`) olarak gelir ve
/// `putFile(File)` ile yüklenir. Web'de `dart:io` dosyası yoktur:
/// image_picker / file_picker bir `blob:` URL döndürür ve `putFile` hata
/// verir ("Dosya yüklemeleri başarısız oldu"). Web'de dosya baytları
/// okunup `putData` ile yüklenir.

/// [path] mobilde dosya yolu, web'de `blob:` URL'sidir. Web'de baytlar
/// hazırsa [bytes] verilebilir (file_picker `withData: true`).
Future<UploadTask> startUpload(
  Reference ref,
  String path, {
  SettableMetadata? metadata,
  Uint8List? bytes,
}) async {
  if (kIsWeb) {
    final data = bytes ?? await XFile(path).readAsBytes();
    return ref.putData(data, metadata);
  }
  return ref.putFile(File(path), metadata);
}

/// Dosyanın bayt cinsinden boyutu (web'de blob'dan okunur).
Future<int> localFileLength(String path) => XFile(path).length();

/// Dosya uzantısı. Web'de `blob:` URL'sinde uzantı olmadığından önce
/// [name] (XFile.name / PlatformFile.name) kullanılır.
String fileExtension(String path, {String? name, String fallback = 'jpg'}) {
  for (final candidate in [name, path]) {
    if (candidate == null || candidate.startsWith('blob:')) continue;
    final last = candidate.split('/').last;
    final dot = last.lastIndexOf('.');
    if (dot > 0 && dot < last.length - 1) {
      return last.substring(dot + 1).toLowerCase();
    }
  }
  return fallback;
}

/// Henüz yüklenmemiş yerel görselin önizlemesi.
Widget localImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  if (kIsWeb) {
    return Image.network(path,
        fit: fit, width: width, height: height, errorBuilder: errorBuilder);
  }
  return Image.file(File(path),
      fit: fit, width: width, height: height, errorBuilder: errorBuilder);
}
