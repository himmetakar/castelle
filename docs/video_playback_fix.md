# Firebase Storage Video Oynatma Sorunu ve Çözümü

## Sorun
Gelen audition (başvuru) videoları açılmak istendiğinde Android tarafında (ExoPlayer) şu hata alınıyordu:
`PlatformException(VideoError, Video player had error g0.j: Source error, null, null)` veya `Video sunucudan yüklenemedi.`

### Hatanın Nedeni
Firebase Storage REST API üzerinden video yüklendikten sonra oluşturulan indirme bağlantısı (download URL) şu şekilde üretiliyordu:
`https://firebasestorage.googleapis.com/v0/b/castelle-9ab2c.firebasestorage.app/o/auditions/projectId/filename.mp4?alt=media&token=token_degeri`

Firebase Storage API kurallarına göre, dosya yolunun (`auditions/projectId/filename.mp4`) URL içinde tek bir segment olması gerekir. Yani içerideki tüm bölü (`/`) işaretlerinin `%2F` olarak kodlanmış olması zorunludur. `Uri.encodeFull` fonksiyonu `/` karakterlerini kodlamadığı için URL geçersiz oluyordu ve video oynatıcı dosyayı sunucudan çekemiyordu.

---

## Çözüm

### 1. Yeni Yüklemeler İçin (Geleceğe Yönelik Çözüm)
`lib/core/services/audition_service.dart` içerisinde dosya yolu kodlanırken `Uri.encodeFull` yerine `/` karakterlerini de `%2F` formatına dönüştüren **`Uri.encodeComponent`** kullanılmaya başlandı:
- **Dosya:** [audition_service.dart](file:///d:/Mobil%20Projeler/Castelle/lib/core/services/audition_service.dart)
```dart
// Eski Hatalı Kod:
final encodedPath = Uri.encodeFull(storagePath);
// Yeni Doğru Kod:
final encodedPath = Uri.encodeComponent(storagePath);
```

### 2. Eski Kayıtlar İçin (Çalışma Zamanında Düzeltme)
Veritabanında önceden hatalı (bölü işaretli) URL ile kaydedilmiş videoların da sorunsuz oynatılması için `audition_review_screen.dart` dosyasına çalışma zamanında URL düzelten bir regex/substring mantığı eklendi. Video yüklenmeden önce hatalı URL otomatik olarak algılanıp `%2F` formatına dönüştürülüyor:
- **Dosya:** [audition_review_screen.dart](file:///d:/Mobil%20Projeler/Castelle/lib/features/director/screens/audition_review_screen.dart)
```dart
if (videoUrl.startsWith('http') && videoUrl.contains('/o/')) {
  final oIndex = videoUrl.indexOf('/o/');
  final queryIndex = videoUrl.indexOf('?', oIndex);
  final baseUrl = videoUrl.substring(0, oIndex + 3);
  final queryParams = queryIndex != -1 ? videoUrl.substring(queryIndex) : '';
  final rawPath = queryIndex != -1 
      ? videoUrl.substring(oIndex + 3, queryIndex) 
      : videoUrl.substring(oIndex + 3);
  
  if (rawPath.contains('/') && !rawPath.contains('%2F')) {
    final encodedPath = Uri.encodeComponent(rawPath);
    videoUrl = '$baseUrl$encodedPath$queryParams';
  }
}
```
Bu sayede hem eski hem de yeni tüm videolar hem emülatörde hem de gerçek cihazlarda sorunsuz bir şekilde oynatılabilmektedir.
