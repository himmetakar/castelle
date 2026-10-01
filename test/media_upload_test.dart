import 'package:flutter_test/flutter_test.dart';
import 'package:castelle/core/services/media_upload.dart';

void main() {
  test('mobil dosya yolundan uzantı', () {
    expect(fileExtension('/data/user/0/cache/IMG_01.JPG'), 'jpg');
    expect(fileExtension('/tmp/video.mp4', fallback: 'mp4'), 'mp4');
  });

  test('web blob URL için isimden uzantı, yoksa varsayılan', () {
    expect(fileExtension('blob:https://castelle-web.web.app/1f2e', name: 'foto.png'), 'png');
    expect(fileExtension('blob:https://castelle-web.web.app/1f2e'), 'jpg');
    expect(fileExtension('blob:https://x/1', name: 'ses', fallback: 'mp3'), 'mp3');
  });
}
