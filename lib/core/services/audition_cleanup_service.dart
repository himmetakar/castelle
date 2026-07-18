import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

/// Audition Temizleme Servisi
/// Proje'nin çekim tarihinden (shootDate) 10 gün sonra
/// o projeye ait tüm audition video URL'lerini Storage'dan siler,
/// Firestore'daki audition belgesinde videoUrl'yi null yapar.
class AuditionCleanupService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Tüm projeleri tarar ve süresi geçmiş auditionları temizler.
  /// Bu metot uygulama başlatıldığında veya admin paneli açıldığında çağrılabilir.
  static Future<void> runCleanup() async {
    try {
      final now = DateTime.now();

      // Tüm aktif projeleri al
      final projectsSnap = await _db.collection('projects').get();

      for (final projectDoc in projectsSnap.docs) {
        final data = projectDoc.data();
        final shootDateStr = data['shootDate'] as String?;
        if (shootDateStr == null || shootDateStr.isEmpty) continue;

        // shootDate parse et (dd.MM.yyyy veya yyyy-MM-dd formatı)
        DateTime? shootDate;
        try {
          if (shootDateStr.contains('.')) {
            shootDate = DateFormat('dd.MM.yyyy').parse(shootDateStr);
          } else {
            shootDate = DateTime.parse(shootDateStr);
          }
        } catch (_) {
          continue;
        }

        // Çekim tarihinden 10 gün geçtiyse temizle
        final cutoff = shootDate.add(const Duration(days: 10));
        if (now.isBefore(cutoff)) continue;

        await _cleanProjectAuditions(projectDoc.id);
      }
    } catch (e) {
      // Hata loglama — crash'e izin verme
    }
  }

  static Future<void> _cleanProjectAuditions(String projectId) async {
    final auditionsSnap = await _db
        .collection('auditions')
        .where('projectId', isEqualTo: projectId)
        .get();

    for (final auditionDoc in auditionsSnap.docs) {
      final data = auditionDoc.data();
      final videoUrl = data['videoUrl'] as String?;

      if (videoUrl == null || videoUrl.isEmpty) continue;

      // Storage'dan sil
      try {
        final ref = _storage.refFromURL(videoUrl);
        await ref.delete();
      } catch (_) {
        // Dosya zaten silinmiş olabilir
      }

      // Firestore'da videoUrl'yi temizle, silindiğini işaretle
      await auditionDoc.reference.update({
        'videoUrl': FieldValue.delete(),
        'videoDeletedAt': FieldValue.serverTimestamp(),
        'videoDeletedReason': 'auto_cleanup_10days',
      });
    }
  }
}
