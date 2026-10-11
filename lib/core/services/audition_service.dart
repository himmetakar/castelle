import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:castelle/core/utils/media_upload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/services/notification_service.dart';

// Castelle - Audition Service
// Video yükleme, Firestore CRUD ve sorgulama — saf Firebase, yerel depolama yok

class AuditionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'auditions';

  /// Durum tarihçesine eklenecek kayıt (Firestore dizilerinde
  /// serverTimestamp kullanılamadığı için istemci zamanı kullanılır).
  static Map<String, dynamic> historyEntry({
    required String status,
    String? by,
    String? note,
  }) {
    return {
      'status': status,
      'at': Timestamp.now(),
      if (by != null && by.isNotEmpty) 'by': by,
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }

  // Firebase Storage bucket

  /// Video'yu Firebase Storage SDK ile güvenli şekilde yükle ve URL döndür
  Future<String> uploadVideo({
    required XFile videoFile,
    required String actorId,
    required String projectId,
    required Function(double) onProgress,
  }) async {
    // Web'de tarayıcı kaydı webm olabilir; tür dosyanın kendisinden tespit edilir.
    final media = await MediaUpload.prepare(videoFile, kind: 'video');
    final fileName =
        '${actorId}_${projectId}_${DateTime.now().millisecondsSinceEpoch}.${media.extension}';
    final storagePath = 'auditions/$projectId/$fileName';

    debugPrint('📤 [Storage Upload] Audition videosu yükleniyor: $storagePath');

    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = MediaUpload.upload(ref, videoFile, media);

      // İlerleme takibi
      uploadTask.snapshotEvents.listen(
        (snapshot) {
          if (snapshot.totalBytes > 0) {
            final progress = (snapshot.bytesTransferred / snapshot.totalBytes).clamp(0.0, 1.0);
            onProgress(progress);
          }
        },
        onError: (e) {
          debugPrint('⚠️ [Storage Upload Progress Error]: $e');
        },
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('✅ [Storage Upload OK]: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('⚠️ [Storage Upload Error]: $e');
      // Progress tamamla ki UI donmasın
      for (double p = 0.1; p <= 1.0; p += 0.15) {
        await Future.delayed(const Duration(milliseconds: 150));
        onProgress(p);
      }
      onProgress(1.0);
      rethrow;
    }
  }

  /// Tek bir audition getir — Firestore
  Future<AuditionModel?> getAudition(String auditionId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(auditionId).get();
      if (!doc.exists) return null;
      return AuditionModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      debugPrint('⚠️ [AuditionService.getAudition] Error: $e');
      return null;
    }
  }

  /// Audition oluştur — direkt Firestore
  Future<String> createAudition(AuditionModel audition) async {
    final docRef = _firestore.collection(_collection).doc();
    final data = audition.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['id'] = docRef.id;
    data['isDeleted'] = false;
    data['statusHistory'] = [
      historyEntry(status: AuditionStatus.submitted.value, by: audition.actorName),
    ];

    await docRef.set(data);

    // Bildirimler gönder
    try {
      final notifService = NotificationService();
      const title = 'Yeni Audition Başvurusu';
      final body = '${audition.actorName}, "${audition.projectTitle}" projesinin "${audition.roleName}" rolü için audition gönderdi. 🎬';

      await notifService.sendBulkNotification(
        title: title,
        body: body,
        type: NotificationType.newAudition,
        target: NotificationTarget.admins,
        senderId: audition.actorId,
        senderName: audition.actorName,
        projectId: audition.projectId,
        data: {'auditionId': docRef.id},
      );

      await notifService.sendBulkNotification(
        title: title,
        body: body,
        type: NotificationType.newAudition,
        target: NotificationTarget.moderators,
        senderId: audition.actorId,
        senderName: audition.actorName,
        projectId: audition.projectId,
        data: {'auditionId': docRef.id},
      );
    } catch (e) {
      debugPrint('⚠️ [AuditionService.createAudition] Notification error: $e');
    }

    return docRef.id;
  }

  /// Audition durumunu güncelle (inceleme) — direkt Firestore
  Future<void> reviewAudition({
    required String auditionId,
    required AuditionStatus status,
    String? reviewerNote,
    String? reviewerId,
    String? reviewerName,
  }) async {
    // Önce mevcut audition'ı al (bildirim için)
    AuditionModel? audition;
    try {
      audition = await getAudition(auditionId);
    } catch (_) {}

    // Firestore'u güncelle (durum tarihçesi korunur)
    await _firestore.collection(_collection).doc(auditionId).update({
      'status': status.value,
      'reviewerNote': reviewerNote,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewedAt': FieldValue.serverTimestamp(),
      if (status == AuditionStatus.revision)
        'revisionRequestedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        historyEntry(status: status.value, by: reviewerName, note: reviewerNote),
      ]),
    });

    if (audition == null) return;

    // 1. Oyuncuya bildirim gönder
    try {
      String title = 'Audition Güncellemesi';
      String body = '"${audition.projectTitle}" projesindeki başvurunuz güncellendi.';

      if (status == AuditionStatus.approved) {
        title = 'Audition Başvurunuz Onaylandı! 🎉';
        body = '"${audition.projectTitle}" projesindeki "${audition.roleName}" rolü için audition başvurunuz onaylandı.';
      } else if (status == AuditionStatus.revision) {
        title = 'Revize Talebi: ${audition.projectTitle} 🔄';
        body = '"${audition.projectTitle}" projesindeki "${audition.roleName}" rolü için videonuzu tekrar çekmeniz istendi.'
            '${reviewerNote != null && reviewerNote.isNotEmpty ? "\n📝 $reviewerNote" : ""}';
      } else if (status == AuditionStatus.rejected) {
        title = 'Audition Başvurusu Sonucu 🎬';
        body = '"${audition.projectTitle}" projesindeki "${audition.roleName}" rolü için audition başvurunuz olumsuz değerlendirildi.';
      }

      final notif = NotificationModel(
        id: 'aud_rev_${DateTime.now().millisecondsSinceEpoch}',
        recipientId: audition.actorId,
        title: title,
        body: body,
        type: NotificationType.auditionResult,
        isRead: false,
        senderId: reviewerId,
        senderName: reviewerName,
        projectId: audition.projectId,
        createdAt: DateTime.now(),
        data: {
          'auditionId': auditionId,
          'status': status.value,
          if (status == AuditionStatus.revision) 'isRevision': 'true',
        },
      );

      await NotificationService().sendNotification(notif);
    } catch (err) {
      debugPrint('⚠️ [AuditionService.reviewAudition] Actor notification error: $err');
    }

    // 2. İşveren bildirim — proje sahibini bul ve bildir
    if (status == AuditionStatus.approved || status == AuditionStatus.rejected) {
      try {
        final projectDoc = await _firestore
            .collection('projects')
            .doc(audition.projectId)
            .get();
        final employerId = projectDoc.data()?['employerId'] as String?;

        if (employerId != null && employerId.isNotEmpty) {
          final empTitle = status == AuditionStatus.approved
              ? '${audition.actorName} Onaylandı ✅'
              : '${audition.actorName} Reddedildi';
          final empBody = '"${audition.projectTitle}" projesinin '
              '"${audition.roleName}" rolü için ${audition.actorName} '
              '${status == AuditionStatus.approved ? "onaylandı." : "reddedildi."}';

          final empNotif = NotificationModel(
            id: 'emp_aud_${DateTime.now().millisecondsSinceEpoch}',
            recipientId: employerId,
            title: empTitle,
            body: empBody,
            type: NotificationType.auditionResult,
            isRead: false,
            senderId: reviewerId,
            senderName: reviewerName,
            projectId: audition.projectId,
            createdAt: DateTime.now(),
          );
          await NotificationService().sendNotification(empNotif);
          debugPrint('✅ [AuditionService] İşveren bildirimi gönderildi: $employerId');
        }
      } catch (err) {
        debugPrint('⚠️ [AuditionService.reviewAudition] Employer notification error: $err');
      }
    }
  }

  /// Audition'ı "İnceleniyor" durumuna al
  /// PDF ya da profil indirildiğinde otomatik çağrılır
  Future<void> markAsReviewing({
    required String auditionId,
    String? reviewerId,
    String? reviewerName,
  }) async {
    try {
      final doc = await _firestore.collection(_collection).doc(auditionId).get();
      if (!doc.exists) return;
      final current = AuditionStatus.fromString(doc.data()?['status'] ?? 'submitted');
      // Sadece submitted durumundaysa reviewing'e geç
      if (current != AuditionStatus.submitted) return;

      await _firestore.collection(_collection).doc(auditionId).update({
        'status': AuditionStatus.reviewing.value,
        'reviewerId': reviewerId,
        'reviewerName': reviewerName,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ [AuditionService] markAsReviewing: $auditionId → reviewing');
    } catch (e) {
      debugPrint('⚠️ [AuditionService.markAsReviewing] Error: $e');
    }
  }


  Future<List<AuditionModel>> getActorAuditions(String actorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('actorId', isEqualTo: actorId)
          .get();

      final list = snapshot.docs
          .map((doc) => AuditionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [AuditionService.getActorAuditions] Error: $e');
      return [];
    }
  }

  /// Projeye ait audition'ları getir — Firestore (index gerektirmez)
  Future<List<AuditionModel>> getProjectAuditions(String projectId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('projectId', isEqualTo: projectId)
          .get();

      final list = snapshot.docs
          .map((doc) => AuditionModel.fromMap(doc.data(), doc.id))
          .where((a) => !a.isDeleted)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [AuditionService.getProjectAuditions] Error: $e');
      return [];
    }
  }

  /// Tüm audition'ları getir (Admin/Yönetmen/Moderatör)
  /// [projectIds] verilirse sadece bu projelere ait auditionlar gelir.
  /// [statuses] verilirse bu durumlardan herhangi birindekiler gelir
  /// (ör. "Gönderildi" sekmesi = submitted + reviewing).
  /// Panelden silinen (Silinenler'deki) kayıtlar listelenmez.
  Future<List<AuditionModel>> getAllAuditions({
    AuditionStatus? status,
    List<AuditionStatus>? statuses,
    int limit = 100,
    List<String>? projectIds,
  }) async {
    final statusValues = <String>{
      if (status != null) status.value,
      ...?statuses?.map((s) => s.value),
    }.toList();

    try {
      final results = <AuditionModel>[];

      if (projectIds != null && projectIds.isNotEmpty) {
        // Firestore whereIn en fazla 10 eleman — parçalara böl, durum
        // filtresi istemci tarafında uygulanır.
        for (var i = 0; i < projectIds.length; i += 10) {
          final chunk = projectIds.sublist(
              i, i + 10 > projectIds.length ? projectIds.length : i + 10);
          final snap = await _firestore
              .collection(_collection)
              .where('projectId', whereIn: chunk)
              .get();
          results.addAll(
              snap.docs.map((d) => AuditionModel.fromMap(d.data(), d.id)));
        }
      } else {
        Query<Map<String, dynamic>> query = _firestore.collection(_collection);
        if (statusValues.length == 1) {
          query = query.where('status', isEqualTo: statusValues.first);
        } else if (statusValues.length > 1) {
          query = query.where('status', whereIn: statusValues);
        }
        final snapshot = await query.limit(limit * 2).get();
        results.addAll(
            snapshot.docs.map((doc) => AuditionModel.fromMap(doc.data(), doc.id)));
      }

      final filtered = results
          .where((a) => !a.isDeleted)
          .where((a) => statusValues.isEmpty || statusValues.contains(a.status.value))
          .toList();
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return filtered.take(limit).toList();
    } catch (e) {
      debugPrint('⚠️ [AuditionService.getAllAuditions] Error: $e');
      // Hatayı yutma: AuditionListScreen hata durumunu (Tekrar Dene) göstersin
      rethrow;
    }
  }

  /// Oyuncunun audition'ları için gerçek zamanlı stream — Firestore
  Stream<List<AuditionModel>> streamActorAuditions(String actorId) {
    return _firestore
        .collection(_collection)
        .where('actorId', isEqualTo: actorId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AuditionModel.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Bekleyen audition stream (Yönetmen/Admin) — Firestore (index gerektirmez)
  Stream<List<AuditionModel>> streamPendingAuditions() {
    return _firestore
        .collection(_collection)
        .where('status', isEqualTo: AuditionStatus.submitted.value)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => AuditionModel.fromMap(doc.data(), doc.id))
              .where((a) => !a.isDeleted)
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Audition sil — YUMUŞAK SİLME.
  ///
  /// Kayıt ve video kalıcı olarak silinmez; "Silinenler" (çöp kutusu)
  /// alanına taşınır ve oradan geri yüklenebilir. Oyuncunun kendi
  /// başvuru geçmişinde kayıt görünmeye devam eder.
  Future<void> deleteAudition(
    String auditionId,
    String videoUrl, {
    String? deletedById,
    String? deletedByName,
  }) async {
    await _firestore.collection(_collection).doc(auditionId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletedById': deletedById,
      'deletedByName': deletedByName,
      'statusHistory': FieldValue.arrayUnion([
        historyEntry(status: 'deleted', by: deletedByName, note: 'Panelden silindi (Silinenler)'),
      ]),
    });
  }

  /// Silinenler'den geri yükle
  Future<void> restoreAudition(String auditionId, {String? restoredByName}) async {
    await _firestore.collection(_collection).doc(auditionId).update({
      'isDeleted': false,
      'deletedAt': null,
      'deletedById': null,
      'deletedByName': null,
      'restoredAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        historyEntry(status: 'restored', by: restoredByName, note: 'Silinenler\'den geri yüklendi'),
      ]),
    });
  }

  /// Silinenler (çöp kutusu) listesi — gerçek zamanlı
  Stream<List<AuditionModel>> streamDeletedAuditions({List<String>? projectIds}) {
    return _firestore
        .collection(_collection)
        .where('isDeleted', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      var list = snapshot.docs
          .map((doc) => AuditionModel.fromMap(doc.data(), doc.id))
          .toList();
      if (projectIds != null) {
        list = list.where((a) => projectIds.contains(a.projectId)).toList();
      }
      list.sort((a, b) => (b.deletedAt ?? b.createdAt).compareTo(a.deletedAt ?? a.createdAt));
      return list;
    });
  }

  /// Revize talebinden sonra oyuncunun AYNI başvuruya yeni video yüklemesi.
  /// Eski video "previousVersions" altında saklanır (yedek), durum tekrar
  /// "Gönderildi" olur ve panele bildirim gider.
  Future<void> resubmitAudition({
    required String auditionId,
    required String newVideoUrl,
    int? videoDurationSec,
    int? videoSizeBytes,
    int? originalSizeBytes,
    String? note,
    double? requestedBudget,
    String? scriptUsed,
  }) async {
    final ref = _firestore.collection(_collection).doc(auditionId);
    final snap = await ref.get();
    if (!snap.exists) throw Exception('Başvuru bulunamadı');
    final old = AuditionModel.fromMap(snap.data()!, snap.id);

    await ref.update({
      'previousVersions': FieldValue.arrayUnion([
        {
          'videoUrl': old.videoUrl,
          'uploadedAt': Timestamp.fromDate(old.resubmittedAt ?? old.createdAt),
          'reviewerNote': old.reviewerNote,
          'replacedAt': Timestamp.now(),
        }
      ]),
      'videoUrl': newVideoUrl,
      'videoDurationSec': videoDurationSec,
      'videoSizeBytes': videoSizeBytes,
      'originalSizeBytes': originalSizeBytes,
      if (note != null) 'note': note,
      if (requestedBudget != null) 'requestedBudget': requestedBudget,
      if (scriptUsed != null) 'scriptUsed': scriptUsed,
      'status': AuditionStatus.submitted.value,
      'revisionCount': FieldValue.increment(1),
      'resubmittedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([
        historyEntry(
          status: AuditionStatus.submitted.value,
          by: old.actorName,
          note: 'Revize sonrası yeni video yüklendi',
        ),
      ]),
    });

    try {
      final notifService = NotificationService();
      final title = 'Revize Video Yüklendi 🔁';
      final body = '${old.actorName}, "${old.projectTitle}" projesinin "${old.roleName}" rolü için revize edilmiş videosunu gönderdi.';
      for (final target in [NotificationTarget.admins, NotificationTarget.moderators]) {
        await notifService.sendBulkNotification(
          title: title,
          body: body,
          type: NotificationType.newAudition,
          target: target,
          senderId: old.actorId,
          senderName: old.actorName,
          projectId: old.projectId,
          data: {'auditionId': auditionId},
        );
      }
    } catch (e) {
      debugPrint('⚠️ [AuditionService.resubmitAudition] Notification error: $e');
    }
  }

  /// Audition'a opsiyon talebi gönder (Yönetmen/Admin)
  Future<void> sendOptionRequest({
    required String auditionId,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> questions,
    String? reviewerId,
    String? reviewerName,
  }) async {
    await _firestore.collection(_collection).doc(auditionId).update({
      'statusHistory': FieldValue.arrayUnion([
        historyEntry(status: AuditionStatus.options.value, by: reviewerName),
      ]),
      'status': AuditionStatus.options.value,
      'optionStartDate': Timestamp.fromDate(startDate),
      'optionEndDate': Timestamp.fromDate(endDate),
      'optionQuestions': questions,
      'optionAnswers': null,
      'optionAvailable': null,
      'optionExplanation': null,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    try {
      final audition = await getAudition(auditionId);
      if (audition != null) {
        final pTitle = audition.projectTitle.toUpperCase().startsWith('OPSİYON')
            ? audition.projectTitle.toUpperCase()
            : 'OPSİYON ${audition.projectTitle.toUpperCase()}';

        final notif = NotificationModel(
          id: 'aud_opt_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: audition.actorId,
          title: pTitle,
          body: '${audition.projectTitle} reklam projesi için size bir opsiyon gönderildi. Detayları inceleyip cevap verebilirsiniz.',
          type: NotificationType.auditionResult,
          isRead: false,
          senderId: reviewerId,
          senderName: reviewerName,
          projectId: audition.projectId,
          createdAt: DateTime.now(),
          data: {
            'auditionId': auditionId,
            'isOption': 'true',
          },
        );
        await NotificationService().sendNotification(notif);
      }
    } catch (e) {
      debugPrint('⚠️ Send option request notification error: $e');
    }
  }

  /// Oyuncu opsiyon talebini yanıtlar
  Future<void> submitOptionResponse({
    required String auditionId,
    required bool available,
    String? explanation,
    required Map<String, String> answers,
  }) async {
    await _firestore.collection(_collection).doc(auditionId).update({
      'optionAvailable': available,
      'optionExplanation': explanation,
      'optionAnswers': answers,
      'optionResponseAt': FieldValue.serverTimestamp(),
    });

    try {
      final audition = await getAudition(auditionId);
      if (audition != null) {
        final notifService = NotificationService();
        final title = 'Opsiyon Talebi Yanıtlandı 🎭';
        final body = '${audition.actorName}, "${audition.projectTitle}" projesinin "${audition.roleName}" rolü için opsiyon talebini yanıtladı.';

        if (audition.reviewerId != null && audition.reviewerId!.isNotEmpty) {
          final notif = NotificationModel(
            id: 'opt_resp_${DateTime.now().millisecondsSinceEpoch}',
            recipientId: audition.reviewerId!,
            title: title,
            body: body,
            type: NotificationType.newAudition,
            isRead: false,
            senderId: audition.actorId,
            senderName: audition.actorName,
            projectId: audition.projectId,
            createdAt: DateTime.now(),
            data: {
              'auditionId': auditionId,
            },
          );
          await notifService.sendNotification(notif);
        } else {
          await notifService.sendBulkNotification(
            title: title,
            body: body,
            type: NotificationType.newAudition,
            target: NotificationTarget.admins,
            senderId: audition.actorId,
            senderName: audition.actorName,
            projectId: audition.projectId,
            data: {'auditionId': auditionId},
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Submit option response notification error: $e');
    }
  }
}
