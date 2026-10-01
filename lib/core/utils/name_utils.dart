/// Castelle - İsim yardımcıları

/// Avatarlarda gösterilecek baş harfleri döndürür (en fazla 2 harf).
///
/// Boş, sadece boşluktan oluşan veya kelimeler arasında birden fazla boşluk
/// içeren isimlerde de güvenlidir. Eski kopyalar `split(' ')` sonrası boş
/// parçaya `[0]` ile eriştiği için RangeError fırlatıyor ve release/web'de
/// tüm ekranı griye çeviriyordu.
String initialsOf(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return parts[0][0].toUpperCase();
}
