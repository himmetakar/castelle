import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/services/private_profile_fields.dart';
import 'package:castelle/core/constants/user_roles.dart';

/// Castelle - Firebase Auth Service
/// Kimlik doğrulama ve kullanıcı yönetim servisi

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current Firebase User
  User? get currentUser => _auth.currentUser;

  // Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Kullanıcı kaydı (Email + Password)
  Future<UserModel> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Kullanıcı oluşturulamadı.');

      await user.updateDisplayName(fullName);

      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: UserRole.fromString(role),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final data = <String, dynamic>{
        ...userModel.toMap(),
        'isActive': true,
        // Oyuncu kayıtları admin onayı bekler
        if (role == 'actor') ...{
          'approvalStatus': 'pending',
          'approvedAt': null,
        },
      };
      final private = takePrivateFields(data);

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(data);
      await writePrivateFields(_firestore, user.uid, private);

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Email ile giriş — Firestore dokümanı yoksa otomatik oluşturur
  Future<UserModel> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) throw Exception('Giriş yapılamadı.');

      // Firestore dokümanı var mı kontrol et
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        // Eski kayıtlarda telefon/banka kök dokümanda duruyor olabilir —
        // kullanıcı kendi oturumunda bir kez alt dokümana taşınır.
        await migratePrivateFields(_firestore, user.uid, data);
        data.addAll(await readPrivateFields(_firestore, user.uid));
        return UserModel.fromMap(data, user.uid);
      } else {
        // Firestore dokümanı yoksa otomatik oluştur (Firebase Console'dan eklenen hesaplar için)
        final role = _guessRoleFromEmail(email.trim());
        final userModel = UserModel(
          uid: user.uid,
          email: email.trim(),
          fullName: user.displayName ?? _fullNameFromEmail(email.trim()),
          phone: '',
          role: UserRole.fromString(role),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final data = <String, dynamic>{
          ...userModel.toMap(),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        final private = takePrivateFields(data);

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set(data);
        await writePrivateFields(_firestore, user.uid, private);
        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// E-postadan rol tahmini (demo hesaplar için)
  String _guessRoleFromEmail(String email) {
    final prefix = email.split('@').first.toLowerCase();
    switch (prefix) {
      case 'admin': return 'admin';
      case 'moderator': return 'moderator';
      case 'actor': return 'actor';
      default: return 'actor';
    }
  }

  /// E-postadan görünen ad tahmini
  String _fullNameFromEmail(String email) {
    final prefix = email.split('@').first;
    switch (prefix) {
      case 'admin': return 'Demo Admin';
      case 'moderator': return 'Demo Moderatör';
      case 'actor': return 'Can Demir';
      default: return prefix;
    }
  }


  /// Anonim giriş
  Future<User?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential.user;
    } catch (_) {
      return null;
    }
  }

  /// Firestore'dan kullanıcı verisini al
  Future<UserModel> getUserData(String uid) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists) {
      throw Exception('Kullanıcı verisi bulunamadı.');
    }

    final data = Map<String, dynamic>.from(doc.data()!);
    if (uid == _auth.currentUser?.uid) {
      await migratePrivateFields(_firestore, uid, data);
    }
    data.addAll(await readPrivateFields(_firestore, uid));

    return UserModel.fromMap(data, uid);
  }

  /// Kullanıcı verisini güncelle
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    final private = takePrivateFields(data);
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update(data);
    await writePrivateFields(_firestore, uid, private);
  }

  /// Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Hesabı kalıcı olarak sil.
  /// Firestore verisi + Storage dosyaları + Firebase Auth kaydı.
  /// Şifre ile yeniden kimlik doğrulama zorunlu (Firebase 'requires-recent-login').
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Oturum bulunamadı.');

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw Exception('Bu hesap e-posta ile giriş yapmadığı için silinemiyor.');
    }

    final uid = user.uid;

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }

    await _deleteUserContent(uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Kullanıcıya ait Firestore dokümanlarını ve Storage dosyalarını sil.
  Future<void> _deleteUserContent(String uid) async {
    // Aynı doküman iki sorgudan da gelebilir — path ile tekilleştir.
    final refs = <String, DocumentReference>{};

    final queries = [
      _firestore
          .collection(AppConstants.auditionsCollection)
          .where('actorId', isEqualTo: uid),
      _firestore
          .collection(AppConstants.notificationsCollection)
          .where('userId', isEqualTo: uid),
      _firestore
          .collection(AppConstants.notificationsCollection)
          .where('recipientId', isEqualTo: uid),
    ];

    for (final query in queries) {
      final snap = await query.get();
      for (final doc in snap.docs) {
        refs[doc.reference.path] = doc.reference;
      }
    }

    // Alt koleksiyon otomatik silinmez — hassas alanların dokümanını da ekle.
    final privateRef = privateProfileRef(_firestore, uid);
    refs[privateRef.path] = privateRef;

    final userRef =
        _firestore.collection(AppConstants.usersCollection).doc(uid);
    refs[userRef.path] = userRef;

    // ponytail: tek batch, 500 yazma limiti. Kullanıcı başına doküman sayısı
    // bunu aşmaya başlarsa parça parça commit'e geç.
    final batch = _firestore.batch();
    for (final ref in refs.values) {
      batch.delete(ref);
    }
    await batch.commit();

    // Storage temizliği kritik değil — başarısız olursa hesap silme devam eder.
    try {
      await _deleteStorageFolder(
          FirebaseStorage.instance.ref().child('profiles/$uid'));
    } catch (e) {
      debugPrint('⚠️ [DeleteAccount] Storage temizliği atlandı: $e');
    }
  }

  /// Storage klasörünü alt klasörleriyle birlikte sil.
  Future<void> _deleteStorageFolder(Reference ref) async {
    final list = await ref.listAll();
    await Future.wait([
      ...list.items.map((item) => item.delete()),
      ...list.prefixes.map(_deleteStorageFolder),
    ]);
  }

  /// Şifre sıfırlama
  Future<void> resetPassword(String emailOrRecoveryEmail) async {
    final input = emailOrRecoveryEmail.trim().toLowerCase();
    
    // Firestore'da recoveryEmail alanını sorgula
    final queryByRecovery = await _firestore
        .collection(AppConstants.usersCollection)
        .where('recoveryEmail', isEqualTo: input)
        .limit(1)
        .get();

    String targetEmail = input;
    if (queryByRecovery.docs.isNotEmpty) {
      final userDoc = queryByRecovery.docs.first.data();
      final primaryEmail = userDoc['email'];
      if (primaryEmail != null && primaryEmail.toString().isNotEmpty) {
        targetEmail = primaryEmail.toString();
      }
    }
    
    await _auth.sendPasswordResetEmail(email: targetEmail);
  }

  /// FCM Token güncelle
  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update({
      'fcmToken': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Firebase Auth Hata İşleme (Türkçe)
  Exception _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return Exception('Bu e-posta adresi zaten kullanımda.');
      case 'invalid-email':
        return Exception('Geçersiz e-posta adresi.');
      case 'weak-password':
        return Exception('Şifre çok zayıf. En az 6 karakter kullanın.');
      case 'user-not-found':
        return Exception('Bu e-posta ile kayıtlı kullanıcı bulunamadı.');
      case 'wrong-password':
        return Exception('Yanlış şifre.');
      case 'user-disabled':
        return Exception('Bu hesap devre dışı bırakılmış.');
      case 'too-many-requests':
        return Exception('Çok fazla deneme yaptınız. Lütfen bekleyin.');
      case 'network-request-failed':
        return Exception('İnternet bağlantınızı kontrol edin.');
      default:
        return Exception('Bir hata oluştu: ${e.message}');
    }
  }

  /// Demo oyuncu profilini Firestore'a seed'le
  /// E-postadan UID'yi bulur ve profil datasını merge eder.
  Future<void> seedActorProfile(String email) async {
    try {
      final snap = await _firestore
          .collection(AppConstants.usersCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      final uid = snap.docs.first.id;
      final existingData = snap.docs.first.data();

      // Profil zaten dolu ise atla
      if (existingData['isProfileComplete'] == true &&
          existingData['filmography'] != null) {
        return;
      }

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(_demoActorProfile(email), SetOptions(merge: true));
    } catch (_) {}
  }

  Map<String, dynamic> _demoActorProfile(String email) => {
    'fullName': 'Can Demir',
    'email': email,
    'phone': '0555 333 4455',
    'age': 25,
    'birthYear': 1999,
    'gender': 'male',
    'heightCm': 182,
    'weightKg': 78,
    'eyeColor': 'brown',
    'hairColor': 'black',
    'city': 'İzmir',
    'country': 'Türkiye',
    'bio': 'Profesyonel oyuncu ve dublör. Aksiyon sahnelerinde uzman, paraşüt lisansına sahibim. Tiyatro eğitimi aldım ve çeşitli sinema projelerinde rol aldım.',
    'experienceLevel': 'professional',
    'skills': ['Eskrim', 'At Binme', 'Boks', 'Araba Kullanma', 'Paraşüt', 'Yüzme', 'Modern Dans'],
    'skillsLowercase': ['eskrim', 'at binme', 'boks', 'araba kullanma', 'paraşüt', 'yüzme', 'modern dans'],
    'categorizedSkills': {
      'Spor': ['Eskrim', 'At Binme', 'Boks', 'Yüzme'],
      'Diğer': ['Araba Kullanma', 'Paraşüt'],
      'Dans': ['Modern Dans'],
    },
    'education': ['İstanbul Üniversitesi Devlet Konservatuvarı - Tiyatro Bölümü (2021)'],
    'hobbies': ['Fotoğrafçılık', 'Dağ Yürüyüşü', 'Motosiklet'],
    'filmography': [
      {'year': '2024', 'projectType': 'film', 'projectTitle': 'Gökyüzü Macerası', 'director': 'Demo Yönetmen'},
      {'year': '2023', 'projectType': 'dizi', 'projectTitle': 'Anadolu Kartalları', 'director': 'Murat Arslan'},
      {'year': '2022', 'projectType': 'reklam', 'projectTitle': 'Turkcell Gençlik Reklamı', 'director': 'Selim Can'},
    ],
    'galleryPhotoUrls': [],
    'introVideoUrl': null,
    'showreelVideoUrl': null,
    'performanceVideoUrl': null,
    'expressionVideoUrl': null,
    'lockedSections': {},
    'isHidden': false,
    'acceptedNdas': [],
    'isProfileComplete': true,
    'completionPercentage': 95,
    'role': 'actor',
    'isActive': true,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}
