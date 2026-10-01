import 'package:flutter_test/flutter_test.dart';
import 'package:castelle/core/utils/name_utils.dart';

void main() {
  group('initialsOf', () {
    test('iki kelimeden baş harfleri alır', () {
      expect(initialsOf('Ali Veli'), 'AV');
      expect(initialsOf('ali veli yılmaz'), 'AV');
    });

    test('tek kelime', () {
      expect(initialsOf('Ali'), 'A');
    });

    test('boş / sadece boşluk / null', () {
      expect(initialsOf(''), '?');
      expect(initialsOf('   '), '?');
      expect(initialsOf(null), '?');
    });

    test('kelimeler arasında birden fazla boşluk RangeError fırlatmaz', () {
      expect(initialsOf('Ali  Veli'), 'AV');
      expect(initialsOf('  Ali \t Veli  '), 'AV');
    });
  });
}
