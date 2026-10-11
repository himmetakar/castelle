import 'dart:io' show File;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// Castelle - Web + mobil uyumlu medya yardımcıları
///
/// Web'de `dart:io` File sınıfı ÇALIŞMAZ: `File(path)`, `putFile`,
/// `VideoPlayerController.file`, `Image.file`, `getApplicationDocumentsDirectory`
/// gibi çağrılar tarayıcıda hata fırlatır. Ayrıca web'de seçilen dosyanın
/// `path` değeri bir `blob:` adresidir ve dosya uzantısı içermez.
///
/// Bu sınıf, seçilen dosyayı her yerde [XFile] olarak taşır:
/// - Web'de dosya baytlarını okuyup `putData` ile yükler,
/// - Mobilde eskisi gibi `putFile` ile (belleğe almadan) yükler.
class MediaUpload {
  MediaUpload._();

  /// Adres uzak/tarayıcı adresi mi? (http, https, blob)
  static bool isRemote(String pathOrUrl) =>
      pathOrUrl.startsWith('http://') ||
      pathOrUrl.startsWith('https://') ||
      pathOrUrl.startsWith('blob:');

  /// file_picker sonucunu XFile'a çevirir. Web'de `path` yoktur, baytlar
  /// kullanılır (pickFiles çağrısında `withData: kIsWeb` verilmelidir).
  static XFile? fromPlatformFile(PlatformFile file) {
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) return null;
      return XFile.fromData(bytes, name: file.name, length: file.size);
    }
    final path = file.path;
    if (path == null) return null;
    return XFile(path, name: file.name, length: file.size);
  }

  /// Dosyanın bayt cinsinden boyutu.
  static Future<int> length(XFile file) => file.length();

  /// Yüklemeye hazırlık: içerik türü, uzantı ve (web'de) baytlar.
  /// [kind]: 'image', 'video' veya 'audio' — tür tespit edilemezse kullanılır.
  static Future<PreparedMedia> prepare(XFile file, {required String kind}) async {
    Uint8List? bytes;
    String? contentType;

    if (kIsWeb) {
      bytes = await file.readAsBytes();
      contentType = _sniff(bytes);
    } else {
      // Mobilde de dosyanın ilk baytlarına bakılır: ör. iPhone'da sıkıştırma
      // başarısız olursa .mp4 adıyla kopyalanan dosya aslında QuickTime
      // (.mov) olabilir. Doğru içerik türü, videonun diğer cihazlarda ve
      // tarayıcıda oynatılabilmesi için önemlidir.
      try {
        final header = BytesBuilder(copy: false);
        await for (final chunk in file.openRead(0, 32)) {
          header.add(chunk);
        }
        contentType = _sniff(header.takeBytes());
      } catch (_) {}
    }

    contentType ??= _nonEmpty(file.mimeType);
    final nameExt = _extensionOf(file.name);
    final pathExt = kIsWeb ? null : _extensionOf(file.path);
    contentType ??= _contentTypeForExtension(nameExt ?? pathExt);
    contentType ??= _defaultContentType(kind);

    final extension = _extensionForContentType(contentType) ??
        nameExt ??
        pathExt ??
        _defaultExtension(kind);

    return PreparedMedia(
      contentType: contentType,
      extension: extension,
      bytes: bytes,
    );
  }

  /// Hazırlanmış dosyayı verilen Storage referansına yükler.
  static UploadTask upload(Reference ref, XFile file, PreparedMedia media) {
    final metadata = SettableMetadata(contentType: media.contentType);
    if (kIsWeb) {
      return ref.putData(media.bytes!, metadata);
    }
    return ref.putFile(File(file.path), metadata);
  }

  /// Hem yerel dosya yolu hem de ağ/blob adresi için video oynatıcı oluşturur.
  static VideoPlayerController videoController(String pathOrUrl) {
    if (kIsWeb || isRemote(pathOrUrl)) {
      return VideoPlayerController.networkUrl(Uri.parse(pathOrUrl));
    }
    final clean = pathOrUrl.replaceFirst(RegExp(r'^file://'), '');
    return VideoPlayerController.file(File(clean));
  }

  /// Hem yerel dosya yolu hem de ağ/blob adresi için görsel widget'ı.
  static Widget image(
    String pathOrUrl, {
    BoxFit? fit,
    double? width,
    double? height,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    if (kIsWeb || isRemote(pathOrUrl)) {
      return Image.network(
        pathOrUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder,
        // Web: Firebase Storage'da CORS ayarı yoksa görsel canvas ile
        // okunamaz ve kırık ikon görünür. Bu durumda tarayıcının kendi
        // <img> etiketiyle gösterilir (bkz. storage_cors.json).
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      );
    }
    return Image.file(File(pathOrUrl),
        fit: fit, width: width, height: height, errorBuilder: errorBuilder);
  }

  /// Web'de klasöre dosya kaydetme (dart:io, getDirectoryPath) yoktur.
  /// Bunun yerine dosyayı yeni sekmede açar; kullanıcı tarayıcıdan kaydeder.
  static Future<bool> openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Gösterim için kısa dosya adı (web'de blob adresi yerine).
  static String displayName(XFile? file, String? fallbackPath) {
    if (file != null && file.name.isNotEmpty) return file.name;
    if (fallbackPath == null) return '';
    final parts = fallbackPath.split(RegExp(r'[\\/]'));
    return parts.isEmpty ? fallbackPath : parts.last;
  }

  // ─── İç yardımcılar ───────────────────────────────────────────────

  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  static String? _extensionOf(String name) {
    if (name.startsWith('blob:')) return null;
    final base = name.split(RegExp(r'[\\/]')).last;
    final dot = base.lastIndexOf('.');
    if (dot <= 0 || dot == base.length - 1) return null;
    final ext = base.substring(dot + 1).toLowerCase();
    return ext.length > 5 ? null : ext;
  }

  /// Dosyanın ilk baytlarına bakarak gerçek türünü bulur.
  static String? _sniff(Uint8List b) {
    bool at(int offset, List<int> sig) {
      if (b.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (b[offset + i] != sig[i]) return false;
      }
      return true;
    }

    if (at(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (at(0, [0x47, 0x49, 0x46, 0x38])) return 'image/gif';
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
      return 'image/webp';
    }
    if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x41, 0x56, 0x45])) {
      return 'audio/wav';
    }
    if (at(0, [0x1A, 0x45, 0xDF, 0xA3])) return 'video/webm';
    if (at(0, [0x4F, 0x67, 0x67, 0x53])) return 'audio/ogg';
    if (at(0, [0x49, 0x44, 0x33]) || at(0, [0xFF, 0xFB]) || at(0, [0xFF, 0xF3])) {
      return 'audio/mpeg';
    }
    if (at(4, [0x66, 0x74, 0x79, 0x70])) {
      // ISO BMFF: mp4 / mov / m4a / heic
      final brand = b.length >= 12 ? String.fromCharCodes(b.sublist(8, 12)) : '';
      if (brand.startsWith('qt')) return 'video/quicktime';
      if (brand.startsWith('M4A')) return 'audio/mp4';
      if (brand.startsWith('heic') || brand.startsWith('heix') || brand.startsWith('mif1')) {
        return 'image/heic';
      }
      return 'video/mp4';
    }
    return null;
  }

  static String? _contentTypeForExtension(String? ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      default:
        return null;
    }
  }

  static String? _extensionForContentType(String contentType) {
    switch (contentType) {
      case 'image/jpeg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/heic':
        return 'heic';
      case 'video/mp4':
        return 'mp4';
      case 'video/quicktime':
        return 'mov';
      case 'video/webm':
        return 'webm';
      case 'audio/mpeg':
        return 'mp3';
      case 'audio/mp4':
        return 'm4a';
      case 'audio/wav':
        return 'wav';
      case 'audio/ogg':
        return 'ogg';
      default:
        return null;
    }
  }

  static String _defaultContentType(String kind) => switch (kind) {
        'video' => 'video/mp4',
        'audio' => 'audio/mpeg',
        _ => 'image/jpeg',
      };

  static String _defaultExtension(String kind) => switch (kind) {
        'video' => 'mp4',
        'audio' => 'mp3',
        _ => 'jpg',
      };
}

/// [MediaUpload.prepare] sonucu.
class PreparedMedia {
  final String contentType;
  final String extension;

  /// Sadece web'de dolu (mobilde dosya diskten doğrudan yüklenir).
  final Uint8List? bytes;

  const PreparedMedia({
    required this.contentType,
    required this.extension,
    this.bytes,
  });
}
