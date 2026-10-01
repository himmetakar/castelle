import 'package:flutter_test/flutter_test.dart';
import 'package:castelle/core/utils/turkish_text.dart';

void main() {
  test('aksansız arama Türkçe karakterli ismi bulur', () {
    expect(normalizeTurkish('Yağmur'), 'yagmur');
    expect(normalizeTurkish('YAĞMUR'), 'yagmur');
    expect(normalizeTurkish('yağmur').contains(normalizeTurkish('yagmur')), isTrue);
  });

  test('İ/I/ı aynı kabul edilir', () {
    expect(normalizeTurkish('İLAYDA IŞIK'), 'ilayda isik');
    expect(normalizeTurkish('ılgın'), 'ilgin');
    expect(normalizeTurkish('İ'.toLowerCase()), 'i');
  });

  test('baş/son ve çoklu boşluk temizlenir', () {
    expect(normalizeTurkish('  Ayşe   Öztürk '), 'ayse ozturk');
  });
}
