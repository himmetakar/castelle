import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Seçilen/kaydedilen yerel video için platforma uygun controller.
/// Web'de `VideoPlayerController.file` desteklenmez; image_picker orada
/// `blob:` URL döndürür, o yüzden ağ controller'ı kullanılır.
VideoPlayerController localVideoController(String path) {
  if (kIsWeb) return VideoPlayerController.networkUrl(Uri.parse(path));
  return VideoPlayerController.file(File(path.replaceFirst(RegExp(r'^file://'), '')));
}
