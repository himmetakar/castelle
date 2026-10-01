/// Castelle - Türkçe metin karşılaştırma yardımcıları
///
/// Dart'ın `toLowerCase()` fonksiyonu Türkçe'ye duyarlı değildir
/// ('İ' → 'i̇', 'I' → 'i'). Arama için harfleri aksansız ASCII karşılığına
/// indiriyoruz: "yagmur" yazınca "Yağmur", "IŞIK" yazınca "ışık" bulunur.
String normalizeTurkish(String text) {
  final buffer = StringBuffer();
  for (final rune in text.trim().runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_turkishFold[ch] ?? ch.toLowerCase());
  }
  // Birden fazla boşluğu teke indir
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
}

const Map<String, String> _turkishFold = {
  'İ': 'i', 'I': 'i', 'ı': 'i',
  'Ş': 's', 'ş': 's',
  'Ğ': 'g', 'ğ': 'g',
  'Ü': 'u', 'ü': 'u',
  'Ö': 'o', 'ö': 'o',
  'Ç': 'c', 'ç': 'c',
  'Â': 'a', 'â': 'a',
  'Ê': 'e', 'ê': 'e',
  'Î': 'i', 'î': 'i',
  'Ô': 'o', 'ô': 'o',
  'Û': 'u', 'û': 'u',
  // 'İ'.toLowerCase() bazı platformlarda 'i' + birleşik nokta üretir
  '̇': '',
};
