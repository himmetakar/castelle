import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/services/notification_service.dart';


// Castelle - Actor Profile Service
// Oyuncu profil CRUD operasyonları — Firebase Storage SDK + Firestore

class ActorProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // ─────────────────────────────────────────────────────────
  // MEDYA YÜKLEME — Firebase Storage SDK (auth otomatik)
  // ─────────────────────────────────────────────────────────

  /// Profil dosyalarını (Fotoğraf/Video) Firebase Storage'a yükle.
  /// Firebase Storage SDK kullanır → auth token otomatik eklenir.
  Future<String> uploadProfileMedia({
    required File file,
    required String uid,
    required String type,   // 'photo' veya 'video'
    required String key,    // 'profile_photo', 'gallery_0', 'intro_video' vb.
    Function(double)? onProgress,
  }) async {
    final extension = file.path.split('.').last.toLowerCase();
    final fileName = '${uid}_${key}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storagePath = 'profiles/$uid/$type/$fileName';

    // MIME type — uzantıya göre belirle
    final mimeType = _mimeType(type, extension);

    debugPrint('📤 [Storage Upload] Başlıyor: $storagePath ($mimeType)');

    try {
      final ref = _storage.ref().child(storagePath);

      final metadata = SettableMetadata(contentType: mimeType);
      final uploadTask = ref.putFile(file, metadata);

      // İlerleme takibi
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen(
          (snapshot) {
            if (snapshot.totalBytes > 0) {
              final progress =
                  (snapshot.bytesTransferred / snapshot.totalBytes)
                      .clamp(0.0, 1.0);
              onProgress(progress);
            }
          },
          onError: (_) {},
        );
      }

      await uploadTask;

      final downloadUrl = await ref.getDownloadURL();
      debugPrint('✅ [Storage Upload OK]: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('❌ [Storage Upload FirebaseException]: ${e.code} — ${e.message}');
      throw Exception('Medya yüklenemedi: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('❌ [Storage Upload Error]: $e');
      rethrow;
    }
  }

  /// Uzantı ve türe göre doğru MIME type döndür
  String _mimeType(String type, String ext) {
    if (type == 'video') {
      switch (ext) {
        case 'mp4':  return 'video/mp4';
        case 'mov':  return 'video/quicktime';
        case 'avi':  return 'video/x-msvideo';
        case 'mkv':  return 'video/x-matroska';
        default:     return 'video/mp4';
      }
    } else {
      switch (ext) {
        case 'jpg':
        case 'jpeg': return 'image/jpeg';
        case 'png':  return 'image/png';
        case 'webp': return 'image/webp';
        case 'heic': return 'image/heic';
        case 'gif':  return 'image/gif';
        default:     return 'image/jpeg';
      }
    }
  }

  // ─────────────────────────────────────────────────────────
  // FIRESTORE CRUD
  // ─────────────────────────────────────────────────────────

  /// Oyuncu profilini getir — direkt Firestore
  Future<ActorProfileModel?> getActorProfile(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return ActorProfileModel.fromMap(doc.data()!, uid);
    } catch (e) {
      debugPrint('⚠️ [ActorProfileService.getActorProfile] Error: $e');
      return null;
    }
  }

  /// Oyuncu profilini kaydet/güncelle — direkt Firestore
  Future<void> saveActorProfile(ActorProfileModel profile) async {
    final data = profile.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['role'] = 'actor';
    data['isProfileComplete'] = profile.completionPercentage >= 70;
    data['completionPercentage'] = profile.completionPercentage;
    data['isActive'] = true;

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(profile.uid)
        .set(data, SetOptions(merge: true));
  }

  /// Oyuncu profilini stream olarak dinle
  Stream<ActorProfileModel?> streamActorProfile(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ActorProfileModel.fromMap(doc.data()!, uid);
    });
  }

  /// Yetenek ekle
  Future<void> addSkill(String uid, String skill) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'skills': FieldValue.arrayUnion([skill]),
      'skillsLowercase': FieldValue.arrayUnion([skill.toLowerCase()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Yetenek sil
  Future<void> removeSkill(String uid, String skill) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'skills': FieldValue.arrayRemove([skill]),
      'skillsLowercase': FieldValue.arrayRemove([skill.toLowerCase()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toplu yetenek güncelle
  Future<void> updateSkills(String uid, List<String> skills) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'skills': skills,
      'skillsLowercase': skills.map((s) => s.toLowerCase()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Tüm oyuncuları getir (Admin/Moderatör için)
  Future<List<ActorProfileModel>> getAllActors({
    int limit = 30,
    DocumentSnapshot? startAfter,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'actor')
        .orderBy('fullName');

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => ActorProfileModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Yeteneklere göre oyuncu filtrele
  Future<List<ActorProfileModel>> filterActorsBySkills({
    required List<String> skills,
    int? minAge,
    int? maxAge,
    int? minHeight,
    int? maxHeight,
    Gender? gender,
    int limit = 30,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'actor');

    if (skills.isNotEmpty) {
      final querySkills = skills
          .take(10)
          .map((s) => s.toLowerCase())
          .toList();
      query = query.where('skillsLowercase', arrayContainsAny: querySkills);
    }

    if (gender != null) {
      query = query.where('gender', isEqualTo: gender.value);
    }

    query = query.limit(limit);

    final snapshot = await query.get();
    var results = snapshot.docs
        .map((doc) => ActorProfileModel.fromMap(doc.data(), doc.id))
        .toList();

    if (minAge != null) {
      results = results.where((a) => a.age != null && a.age! >= minAge).toList();
    }
    if (maxAge != null) {
      results = results.where((a) => a.age != null && a.age! <= maxAge).toList();
    }
    if (minHeight != null) {
      results = results.where((a) => a.heightCm != null && a.heightCm! >= minHeight).toList();
    }
    if (maxHeight != null) {
      results = results.where((a) => a.heightCm != null && a.heightCm! <= maxHeight).toList();
    }

    if (skills.length > 1) {
      final lowerSkills = skills.map((s) => s.toLowerCase()).toSet();
      results = results.where((actor) {
        final actorSkillsLower = actor.skills.map((s) => s.toLowerCase()).toSet();
        return lowerSkills.every((skill) => actorSkillsLower.contains(skill));
      }).toList();
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────
  // ADMIN ONAY SİSTEMİ
  // ─────────────────────────────────────────────────────────

  /// Bekleyen onay oyuncularını stream olarak getir
  Stream<List<ActorProfileModel>> streamPendingActors() {
    return _firestore
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: 'actor')
        .where('approvalStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ActorProfileModel.fromMap(doc.data(), doc.id))
            .toList()
          ..sort((a, b) => b.uid.compareTo(a.uid)));
  }

  /// Oyuncuyu onayla
  Future<void> approveActor(String uid) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'approvalStatus': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'adminNote': null,
    });

    // Oyuncuya bildirim gönder
    try {
      final notif = NotificationModel(
        id: 'approval_${uid}_${DateTime.now().millisecondsSinceEpoch}',
        recipientId: uid,
        title: 'Profiliniz Onaylandı! 🎉',
        body: 'Profiliniz yönetici tarafından onaylandı. Artık tüm özelliklere erişebilirsiniz!',
        type: NotificationType.systemMessage,
        isRead: false,
        createdAt: DateTime.now(),
      );
      await NotificationService().sendNotification(notif);
    } catch (e) {
      debugPrint('⚠️ [approveActor] Notification error: $e');
    }
  }

  /// Oyuncuyu reddet
  Future<void> rejectActor(String uid, {String? reason}) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .update({
        'approvalStatus': 'rejected',
        'adminNote': reason ?? 'Profiliniz yöneticilerimiz tarafından yapılan inceleme sonucunda onaylanmamıştır.',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Oyuncuya bildirim gönder
      try {
        final notif = NotificationModel(
          id: 'rejection_${uid}_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: uid,
          title: 'Başvurunuz Onaylanmadı 😔',
          body: reason ?? 'Profiliniz yöneticilerimiz tarafından yapılan inceleme sonucunda onaylanmamıştır.',
          type: NotificationType.systemMessage,
          isRead: false,
          createdAt: DateTime.now(),
        );
        await NotificationService().sendNotification(notif);
      } catch (e) {
        debugPrint('⚠️ [rejectActor] Notification error: $e');
      }
    } catch (e) {
      debugPrint('❌ [rejectActor] Error: $e');
      rethrow;
    }
  }

  /// Düzenleme talebi gönder
  Future<void> requestEdit(String uid, String message) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'adminNote': message,
      'approvalStatus': 'pending', // Hâlâ pending kalır
    });

    // Oyuncuya bildirim gönder
    try {
      final notif = NotificationModel(
        id: 'edit_req_${uid}_${DateTime.now().millisecondsSinceEpoch}',
        recipientId: uid,
        title: 'Profil Düzenleme Talebi',
        body: 'Yönetici profilinizde düzenleme talep etti: $message',
        type: NotificationType.systemMessage,
        isRead: false,
        createdAt: DateTime.now(),
      );
      await NotificationService().sendNotification(notif);
    } catch (e) {
      debugPrint('⚠️ [requestEdit] Notification error: $e');
    }
  }
}

