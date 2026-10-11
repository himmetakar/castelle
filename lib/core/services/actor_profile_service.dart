import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:castelle/core/utils/media_upload.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/services/notification_service.dart';
import 'package:castelle/core/services/private_profile_fields.dart';


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
  /// [file] mobilde disk yolu, web'de blob URL taşır; ikisi de desteklenir.
  Future<String> uploadProfileMedia({
    required XFile file,
    required String uid,
    required String type,   // 'photo' veya 'video'
    required String key,    // 'profile_photo', 'gallery_0', 'intro_video' vb.
    Function(double)? onProgress,
  }) async {
    // Web'de path bir blob: adresidir ve uzantı içermez; tür ve uzantı
    // dosyanın kendisinden tespit edilir.
    final media = await MediaUpload.prepare(
      file,
      kind: type == 'video' ? 'video' : 'image',
    );
    final fileName = '${uid}_${key}_${DateTime.now().millisecondsSinceEpoch}.${media.extension}';
    final storagePath = 'profiles/$uid/$type/$fileName';

    debugPrint('📤 [Storage Upload] Başlıyor: $storagePath (${media.contentType})');

    try {
      final ref = _storage.ref().child(storagePath);

      final uploadTask = MediaUpload.upload(ref, file, media);

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

  // ─────────────────────────────────────────────────────────
  // FIRESTORE CRUD
  // ─────────────────────────────────────────────────────────

  /// Oyuncu profilini getir — direkt Firestore
  /// Belge yoksa null döner. Okuma HATASI (ağ, yetki...) durumunda fırlatır —
  /// eskiden hata yutulup null dönüyordu; üst katman bunu "profil yok" sanıp
  /// BOŞ bir profil oluşturuyor, kullanıcı her şeyin silindiğini görüyor ve
  /// kaydedince gerçekten siliniyordu.
  Future<ActorProfileModel?> getActorProfile(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    // Özel alanlar (telefon, IBAN, veli...) okunamazsa profil yine de
    // kamu alanlarıyla yüklensin; tüm profil boşa düşmesin.
    try {
      data.addAll(await readPrivateFields(_firestore, uid));
    } catch (e) {
      debugPrint('⚠️ [ActorProfileService.getActorProfile] private okunamadı: $e');
    }
    return ActorProfileModel.fromMap(data, uid);
  }

  /// Oyuncu profilini kaydet/güncelle — direkt Firestore
  Future<void> saveActorProfile(ActorProfileModel profile) async {
    final data = profile.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['isProfileComplete'] = profile.completionPercentage >= 70;
    data['completionPercentage'] = profile.completionPercentage;
    // GÜVENLİK: Rol, aktiflik ve admin notu profil kaydıyla değiştirilmez.
    // (Önceden her kayıtta role='actor' ve isActive=true yazılıyordu; bu,
    // veli onayı bekleyen 18 yaş altı hesapları aktif hale getiriyor ve
    // admin notunu eski değerle ezebiliyordu.)
    data.remove('role');
    data.remove('isActive');
    data.remove('adminNote');
    data.remove('approvedAt');
    data.remove('rejectedAt');
    data.remove('isGuardianApproved');
    data.remove('guardianApprovalStatus');
    // Onay durumu: yalnızca henüz onaya gönderilmemiş (taslak/eksik) ya da
    // reddedilmiş bir profil 'pending'e geçebilir. Onaylanmış hesap, eski bir
    // profil kopyasıyla kaydedilip 'pending'e geri döndürülemez (admin onayı
    // ezilmesin).
    final userRef = _firestore
        .collection(AppConstants.usersCollection)
        .doc(profile.uid);
    Map<String, dynamic> current = const {};
    try {
      current = (await userRef.get()).data() ?? const {};
    } catch (_) {}
    final currentStatus = current['approvalStatus'] as String?;
    // Güvenlik kurallarının zaten reddedeceği alanları istemciden göndermeyelim;
    // aksi halde tüm kayıt "permission-denied" ile düşüyor ve kullanıcı hiçbir
    // şeyi kaydedemiyordu.
    // • 18 yaş altı olarak kayıtlı hesap kendini yetişkin yapamaz
    if (current['isUnder18'] == true && data['isUnder18'] != true) {
      data.remove('isUnder18');
    }
    // • Veli onayı olmayan 18 yaş altı profil herkese açılamaz
    final minorBlocked =
        current['isUnder18'] == true && current['isGuardianApproved'] != true;
    if (minorBlocked && data['isHidden'] == false) {
      data.remove('isHidden');
    }
    final canMoveToPending = data['approvalStatus'] == 'pending' &&
        (currentStatus == null ||
            currentStatus == 'draft' ||
            currentStatus == 'incomplete' ||
            currentStatus == 'rejected');
    if (!canMoveToPending) data.remove('approvalStatus');

    // Profil henüz yüklenmeden (örn. hemen fotoğraf yüklendiğinde) oluşturulan
    // boş iskelet model, gerçek ad/e-posta/telefonu boş string ile ezmesin.
    for (final k in ['fullName', 'email', 'phone']) {
      final v = data[k];
      if (v == null || (v is String && v.trim().isEmpty)) data.remove(k);
    }
    final private = takePrivateFields(data);

    await userRef
        .set(data, SetOptions(merge: true));
    await writePrivateFields(_firestore, profile.uid, private);
  }

  /// Oyuncu profilini stream olarak dinle
  Stream<ActorProfileModel?> streamActorProfile(String uid) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        // ponytail: her snapshot'ta private dokümanı yeniden okuyor. Kendi
        // profilini dinlemek için kullanılıyor, hacim düşük. Sıklık artarsa
        // iki snapshot stream'ini birleştir.
        .asyncMap((doc) async {
      if (!doc.exists) return null;
      final data = Map<String, dynamic>.from(doc.data()!);
      data.addAll(await readPrivateFields(_firestore, uid));
      return ActorProfileModel.fromMap(data, uid);
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
        // actor_hidden: gizli (isHidden != false) yeni üyeler de onay kuyruğunda görünsün
        .where('role', whereIn: ['actor', 'actor_hidden'])
        // pending_guardian: 18 yaş altı, veli onayı bekleyen yeni üyeler de
        // kuyrukta görünsün (admin veli ile görüşüp onayı işaretleyebilsin)
        .where('approvalStatus', whereIn: ['pending', 'pending_guardian'])
        .snapshots()
        // Admin ekranı telefonu gösteriyor — bekleyen her oyuncu için private okunur.
        .asyncMap((snap) async => (await Future.wait(snap.docs.map((doc) async =>
                ActorProfileModel.fromMap({
                  ...doc.data(),
                  ...await readPrivateFields(_firestore, doc.id),
                }, doc.id))))
          ..sort((a, b) => b.uid.compareTo(a.uid)));
  }

  /// Oyuncuyu onayla
  Future<void> approveActor(String uid) async {
    final userRef =
        _firestore.collection(AppConstants.usersCollection).doc(uid);
    final current = (await userRef.get()).data() ?? <String, dynamic>{};
    // Veli onayı bekleyen 18 yaş altı hesap, admin onayıyla otomatik yayına alınmaz.
    final blockedMinor =
        current['isUnder18'] == true && current['isGuardianApproved'] != true;
    if (blockedMinor) {
      // Sessizce "onaylı ama gizli" bırakmak kafa karıştırıyordu; admin ne
      // yapması gerektiğini görsün.
      throw Exception(
          '18 yaş altı üye: önce veli ile görüşüp "Veli Onayı Alındı" işaretleyin, sonra onaylayın.');
    }
    await userRef.update({
      'approvalStatus': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'adminNote': null,
      'isActive': true,
      'isHidden': false,
      'updatedAt': FieldValue.serverTimestamp(),
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

  /// Veli onayını kaydet (admin/moderatör, veli ile telefonla görüşüp onay aldıktan sonra).
  ///
  /// 18 yaş altı hesap `pending_guardian` durumundan normal onay kuyruğuna
  /// (`pending`) geçer; ardından [approveActor] ile yayına alınabilir.
  Future<void> approveGuardian(String uid, {String? approvedByName, String? note}) async {
    final userRef =
        _firestore.collection(AppConstants.usersCollection).doc(uid);
    final current = (await userRef.get()).data() ?? <String, dynamic>{};
    await userRef.update({
      'isGuardianApproved': true,
      'guardianApprovalStatus': 'approved',
      'guardianApprovedAt': FieldValue.serverTimestamp(),
      if (approvedByName != null && approvedByName.isNotEmpty)
        'guardianApprovedBy': approvedByName,
      if (note != null && note.isNotEmpty) 'guardianApprovalNote': note,
      if (current['approvalStatus'] == 'pending_guardian') 'approvalStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

