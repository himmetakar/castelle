import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/services/notification_service.dart';

/// Castelle - Firebase Auth Service
/// Kimlik doğrulama ve kullanıcı yönetim servisi (SMS / Telefon Kimlik Doğrulama)

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService() {
    _auth.setLanguageCode('tr');
  }

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
    DateTime? birthDate,
    int? age,
    bool isUnder18 = false,
    bool hasAcceptedTerms = true,
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

      final calculatedAge = age ?? (birthDate != null ? (DateTime.now().year - birthDate.year) : null);
      final under18 = isUnder18 || (calculatedAge != null && calculatedAge < 18);

      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: UserRole.fromString(role),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        birthDate: birthDate,
        age: calculatedAge,
        isUnder18: under18,
        isGuardianApproved: !under18,
        guardianApprovalStatus: under18 ? 'pending' : 'approved',
        hasAcceptedTerms: hasAcceptedTerms,
        acceptedTermsAt: DateTime.now(),
        isActive: !under18, // 18 yaş altı kullanıcı veli onayı alınana kadar inaktif
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        ...userModel.toMap(),
        'isActive': !under18,
        'isHidden': under18, // 18 yaş altı listede saklanır
        'approvalStatus': role == UserRole.admin.value ? 'approved' : (under18 ? 'pending_guardian' : 'pending'),
        if (role == UserRole.admin.value) 'approvedAt': FieldValue.serverTimestamp(),
      });

      // Admin kullanıcılarına yeni üye bildirimi gönder
      try {
        final roleLabel = UserRole.fromString(role).displayName;
        final extraTag = under18 ? ' (18 Yaş Altı - Veli Onayı Bekliyor)' : '';
        await NotificationService().sendBulkNotification(
          title: 'Yeni Üye Kaydı 👤',
          body: '${fullName.trim()} ($roleLabel)$extraTag platforma yeni kayıt oldu.',
          type: NotificationType.systemMessage,
          target: NotificationTarget.admins,
        );
      } catch (_) {}

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Yasal Sözleşmeler ve KVKK Onayını Güncelle
  Future<void> acceptLegalConsent(
    String uid, {
    DateTime? birthDate,
    int? age,
    bool? isUnder18,
  }) async {
    final calculatedAge = age ?? (birthDate != null ? (DateTime.now().year - birthDate.year) : null);
    final under18 = (isUnder18 == true) || (calculatedAge != null && calculatedAge < 18);

    final updateData = <String, dynamic>{
      'hasAcceptedTerms': true,
      'acceptedTermsAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (birthDate != null) updateData['birthDate'] = birthDate.toIso8601String();
    if (calculatedAge != null) updateData['age'] = calculatedAge;
    if (isUnder18 != null || calculatedAge != null) {
      updateData['isUnder18'] = under18;
      if (under18) {
        updateData['isActive'] = false;
        updateData['isHidden'] = true;
        updateData['isGuardianApproved'] = false;
        updateData['guardianApprovalStatus'] = 'pending';
      }
    }

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .set(updateData, SetOptions(merge: true));
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
        return UserModel.fromMap(doc.data()!, user.uid);
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
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set({
          ...userModel.toMap(),
          'isActive': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
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

  /// Tanımlı Özel Admin Kullanıcı Listesi
  static const List<Map<String, String>> designatedAdmins = [
    {
      'name': 'Yağmur',
      'phone': '+905540216815',
      'cleanPhone': '5540216815',
      'email': 'yagmur@castelle.com',
    },
    {
      'name': 'Alican',
      'phone': '+905322402113',
      'cleanPhone': '5322402113',
      'email': 'alican@castelle.com',
    },
  ];

  /// Telefon Numarası Temizleme & Alan Kodu Esnekliği Yardımcısı (Son 10 Hane)
  static String normalizePhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Firestore'daki Yağmur ve Alican dahil tüm Admin rollerini senkronize et
  /// İkilik (duplicate) kayıtları temizler, yoksa oluşturur, varsa admin yapar.
  Future<void> syncAndPromoteAdminUsers() async {
    try {
      final snap = await _firestore.collection(AppConstants.usersCollection).get();
      final allDocs = snap.docs;

      for (final admin in designatedAdmins) {
        final adminClean = admin['cleanPhone']!;
        final adminName = admin['name']!;
        final adminPhone = admin['phone']!;
        final adminEmail = admin['email']!;

        // 1. Bu telefon numarasına uyan tüm kayıtları bul (alan kodlu/kodsuz esnek eşleşme)
        final matches = allDocs.where((doc) {
          final p = doc.data()['phone'] as String? ?? '';
          return normalizePhone(p) == adminClean;
        }).toList();

        if (matches.isNotEmpty) {
          // İkilik (duplicate) temizleme: İlk dokümanı sakla, diğer mükerrer kayıtları temizle
          final primaryDoc = matches.first;
          for (int i = 1; i < matches.length; i++) {
            try {
              await _firestore.collection(AppConstants.usersCollection).doc(matches[i].id).delete();
            } catch (_) {}
          }

          final data = primaryDoc.data();
          final updateData = <String, dynamic>{
            'role': UserRole.admin.value,
            'isActive': true,
            'approvalStatus': 'approved',
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if ((data['fullName'] as String? ?? '').isEmpty ||
              data['fullName'] == 'Google Kullanıcısı' ||
              data['fullName'] == 'Oyuncu') {
            updateData['fullName'] = adminName;
          }
          if ((data['phone'] as String? ?? '').isEmpty) {
            updateData['phone'] = adminPhone;
          }

          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(primaryDoc.id)
              .set(updateData, SetOptions(merge: true));
        } else {
          // Sistemde hiç yoksa yeni Admin oluştur
          final newDocRef = _firestore.collection(AppConstants.usersCollection).doc();
          final newUser = UserModel(
            uid: newDocRef.id,
            email: adminEmail,
            fullName: adminName,
            phone: adminPhone,
            role: UserRole.admin,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            isActive: true,
            isGuardianApproved: true,
            guardianApprovalStatus: 'approved',
            hasAcceptedTerms: true,
          );

          await newDocRef.set({
            ...newUser.toMap(),
            'isActive': true,
            'approvalStatus': 'approved',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  /// Telefon Numarasına SMS Doğrulama Kodu Gönder
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(Exception error) onError,
    void Function(PhoneAuthCredential credential)? onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (onAutoVerify != null) {
            onAutoVerify(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_handleAuthError(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(Exception('SMS kodu gönderilemedi: $e'));
    }
  }

  /// SMS Kodu ile Giriş Yap / Doğrula
  Future<UserModel> signInWithPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Telefon doğrulaması başarısız.');
      }

      final uid = user.uid;
      final phone = user.phoneNumber ?? '';
      final cleanPhone = normalizePhone(phone);

      final designatedAdmin = designatedAdmins.firstWhere(
        (a) => a['cleanPhone'] == cleanPhone,
        orElse: () => {},
      );
      final isDesignatedAdmin = designatedAdmin.isNotEmpty;

      // 1. Önce UID ile Firestore dokümanını ara
      var doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      // 2. UID ile bulunamadıysa telefon numarasına göre esnek (alan kodlu/kodsuz) arama yap
      if (!doc.exists && cleanPhone.isNotEmpty) {
        final snap = await _firestore.collection(AppConstants.usersCollection).get();
        final matches = snap.docs.where((d) {
          final p = d.data()['phone'] as String? ?? '';
          return normalizePhone(p) == cleanPhone;
        }).toList();

        if (matches.isNotEmpty) {
          doc = matches.first;
        }
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final currentRole = data['role'] as String? ?? 'actor';

        // Eğer doküman farklı ID ile bulunduysa (telefon aramasıyla) — veriyi doğru UID'ye taşı
        if (doc.id != uid) {
          final migratedData = Map<String, dynamic>.from(data);
          migratedData['uid'] = uid;
          migratedData['phone'] = phone;
          migratedData['updatedAt'] = FieldValue.serverTimestamp();

          if (isDesignatedAdmin && currentRole != UserRole.admin.value) {
            migratedData['role'] = UserRole.admin.value;
            migratedData['approvalStatus'] = 'approved';
            migratedData['isActive'] = true;
            if ((migratedData['fullName'] as String? ?? '').isEmpty) {
              migratedData['fullName'] = designatedAdmin['name'];
            }
          }

          // Yeni UID dokümanına yaz
          await _firestore.collection(AppConstants.usersCollection).doc(uid).set(migratedData);
          // Eski dokümanı sil
          try { await _firestore.collection(AppConstants.usersCollection).doc(doc.id).delete(); } catch (_) {}

          final newDoc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
          return UserModel.fromMap(newDoc.data()!, uid);
        }

        // Tanımlı admin ise ve rolü henüz admin değilse admin yap
        if (isDesignatedAdmin && currentRole != UserRole.admin.value) {
          final updateData = <String, dynamic>{
            'role': UserRole.admin.value,
            'approvalStatus': 'approved',
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          };
          if ((data['fullName'] as String? ?? '').isEmpty) {
            updateData['fullName'] = designatedAdmin['name'];
          }
          await _firestore.collection(AppConstants.usersCollection).doc(doc.id).update(updateData);
          final updated = await _firestore.collection(AppConstants.usersCollection).doc(doc.id).get();
          return UserModel.fromMap(updated.data()!, doc.id);
        }

        return UserModel.fromMap(data, doc.id);
      } else {
        // Yeni kullanıcı oluştur
        final assignedRole = isDesignatedAdmin ? UserRole.admin : UserRole.actor;
        final assignedName = isDesignatedAdmin ? designatedAdmin['name']! : '';
        final assignedEmail = isDesignatedAdmin ? designatedAdmin['email']! : '';

        final userModel = UserModel(
          uid: uid,
          email: assignedEmail,
          fullName: assignedName,
          phone: phone,
          role: assignedRole,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .set({
          ...userModel.toMap(),
          'isActive': true,
          'approvalStatus': isDesignatedAdmin ? 'approved' : 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('SMS doğrulaması başarısız: $e');
    }
  }

  /// Kullanıcı E-posta ve Profil Bilgilerini Güncelle (Giriş Sonrası)
  Future<UserModel> updateUserEmailAndDetails({
    required String uid,
    required String email,
    required String fullName,
    required String role,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user != null && email.isNotEmpty && user.email != email) {
        try {
          await user.verifyBeforeUpdateEmail(email.trim());
        } catch (_) {}
      }

      final updateData = <String, dynamic>{
        'email': email.trim(),
        'fullName': fullName.trim(),
        'role': role,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(updateData, SetOptions(merge: true));

      return await getUserData(uid);
    } catch (e) {
      throw Exception('E-posta güncellenirken hata oluştu: $e');
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

    return UserModel.fromMap(doc.data()!, uid);
  }

  /// Kullanıcı verisini güncelle
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .update(data);
  }

  /// Çıkış yap
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Şifre sıfırlama
  Future<void> resetPassword(String emailOrRecoveryEmail) async {
    try {
      final input = emailOrRecoveryEmail.trim().toLowerCase();
      
      // 1. Demo e-posta adresi mi kontrol et (@example.com veya @castelle.com)
      if (input.endsWith('@castelle.com') || input.endsWith('@example.com')) {
        throw Exception('Demo hesaplara (@castelle.com / @example.com) gerçek e-posta gönderilemez. Lütfen gerçek bir e-posta adresi kullanın veya ana ekrandaki demo giriş butonlarını deneyin.');
      }

      // 2. Doğrudan Firebase Auth üzerinden şifre sıfırlama e-postası gönder
      // Unauthenticated (giriş yapmamış) kullanıcıların Firestore 'users' koleksiyonunu okuma yetkisi güvenlik kuralları gereği yoktur.
      await _auth.sendPasswordResetEmail(email: input);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception(e.toString().replaceAll("Exception: ", ""));
    }
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

  /// Firebase Auth & Firestore Hata İşleme (Türkçe)
  Exception _handleAuthError(dynamic e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return Exception('Erişim engellendi: Bu işlemi gerçekleştirmek için yetkiniz bulunmuyor.');
      }
    }
    if (e is FirebaseAuthException) {
      if (e.message != null && e.message!.contains('CONFIGURATION_NOT_FOUND')) {
        return Exception('Firebase Console\'da E-posta/Şifre giriş yöntemi etkinleştirilmemiş. Lütfen Firebase Console -> Authentication -> Sign-in method altından E-posta/Şifre seçeneğini etkinleştirin.');
      }
      switch (e.code) {
        case 'configuration-not-found':
          return Exception('Firebase Console\'da E-posta/Şifre giriş yöntemi etkinleştirilmemiş. Lütfen Firebase Console -> Authentication -> Sign-in method altından E-posta/Şifre seçeneğini etkinleştirin.');
        case 'email-already-in-use':
          return Exception('Bu e-posta adresi zaten kullanımda.');
        case 'invalid-email':
        case 'auth/invalid-email':
          return Exception('Geçersiz bir e-posta adresi girdiniz.');
        case 'missing-email':
        case 'auth/missing-email':
          return Exception('Lütfen bir e-posta adresi girin.');
        case 'weak-password':
          return Exception('Şifre çok zayıf. En az 6 karakter kullanın.');
        case 'user-not-found':
        case 'auth/user-not-found':
          return Exception('Bu e-posta adresi ile kayıtlı kullanıcı bulunamadı.');
        case 'wrong-password':
          return Exception('Yanlış şifre.');
        case 'user-disabled':
          return Exception('Bu hesap devre dışı bırakılmış.');
        case 'invalid-phone-number':
        case 'auth/invalid-phone-number':
          return Exception('Geçersiz bir telefon numarası girdiniz.');
        case 'quota-exceeded':
          return Exception('SMS gönderme kotası aşıldı. Lütfen daha sonra deneyin.');
        case 'captcha-check-failed':
          return Exception('Güvenlik doğrulaması (reCAPTCHA) başarısız oldu.');
        case 'app-not-authorized':
          return Exception('Uygulama Firebase Phone Auth için yetkilendirilmemiş. SHA-1 / SHA-256 fingerprint gereklidir.');
        case 'invalid-verification-code':
        case 'auth/invalid-verification-code':
          return Exception('Girdiğiniz 6 haneli SMS kodu yanlış. Lütfen tekrar deneyin.');
        case 'invalid-verification-id':
          return Exception('Doğrulama kimliği geçersiz. Lütfen tekrar SMS kodu isteyin.');
        case 'session-expired':
          return Exception('SMS kodunun geçerlilik süresi doldu. Lütfen tekrar SMS kodu isteyin.');
        case 'too-many-requests':
          return Exception('Çok fazla deneme yaptınız. Lütfen bir süre bekleyin.');
        case 'network-request-failed':
          return Exception('İnternet bağlantınızı kontrol edin.');
        case 'channel-error':
          return Exception('Lütfen geçerli bilgileri girdiğinizden emin olun.');
        default:
          return Exception('Bir hata oluştu: ${e.message ?? e.code}');
      }
    }
    return Exception('Bir hata oluştu: ${e.toString().replaceAll("Exception: ", "")}');
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
