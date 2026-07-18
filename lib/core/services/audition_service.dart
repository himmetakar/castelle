import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  // Firebase Storage bucket
  static const _storageBucket = 'castelle-9ab2c.firebasestorage.app';

  /// Video'yu Firebase Storage SDK ile güvenli şekilde yükle ve URL döndür
  Future<String> uploadVideo({
    required File videoFile,
    required String actorId,
    required String projectId,
    required Function(double) onProgress,
  }) async {
    final fileName =
        '${actorId}_${projectId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final storagePath = 'auditions/$projectId/$fileName';

    debugPrint('📤 [Storage Upload] Audition videosu yükleniyor: $storagePath');

    try {
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'video/mp4');
      final uploadTask = ref.putFile(videoFile, metadata);

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

    // Firestore'u güncelle
    await _firestore.collection(_collection).doc(auditionId).update({
      'status': status.value,
      'reviewerNote': reviewerNote,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewedAt': FieldValue.serverTimestamp(),
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
        title = 'Audition Revizyon Talebi 🔄';
        body = '"${audition.projectTitle}" projesindeki "${audition.roleName}" rolü için revizyon talep edildi.'
            '${reviewerNote != null && reviewerNote.isNotEmpty ? " Not: $reviewerNote" : ""}';
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
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [AuditionService.getProjectAuditions] Error: $e');
      return [];
    }
  }

  /// Tüm audition'ları getir (Admin/Yönetmen/Moderatör)
  /// [projectIds] verilirse sadece bu projelere ait auditionlar gelir
  Future<List<AuditionModel>> getAllAuditions({
    AuditionStatus? status,
    int limit = 50,
    List<String>? projectIds,
  }) async {
    try {
      // Firestore whereIn maks 10 eleman destekliyor
      // Daha fazla proje varsa birden fazla sorgu + merge gerekir
      if (projectIds != null && projectIds.isNotEmpty) {
        final chunks = <List<String>>[];
        for (var i = 0; i < projectIds.length; i += 10) {
          chunks.add(projectIds.sublist(
              i, i + 10 > projectIds.length ? projectIds.length : i + 10));
        }
        final results = <AuditionModel>[];
        for (final chunk in chunks) {
          Query<Map<String, dynamic>> q = _firestore
              .collection(_collection)
              .where('projectId', whereIn: chunk);
          if (status != null) {
            q = q.where('status', isEqualTo: status.value);
          }
          final snap = await q.limit(limit).get();
          results.addAll(
              snap.docs.map((d) => AuditionModel.fromMap(d.data(), d.id)));
        }
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return results.take(limit).toList();
      }

      Query<Map<String, dynamic>> query = _firestore.collection(_collection);
      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }
      query = query.limit(limit);
      final snapshot = await query.get();
      final list = snapshot.docs
          .map((doc) => AuditionModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('⚠️ [AuditionService.getAllAuditions] Error: $e');
      return [];
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
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Audition sil — Firestore (Storage temizliği Firebase Console'dan yapılabilir)
  Future<void> deleteAudition(String auditionId, String videoUrl) async {
    await _firestore.collection(_collection).doc(auditionId).delete();
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
        final notif = NotificationModel(
          id: 'aud_opt_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: audition.actorId,
          title: 'Opsiyon Talebi 🎭',
          body: '"${audition.projectTitle}" projesi için size bir opsiyon talebi gönderildi. Lütfen detayları yanıtlayın.',
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
