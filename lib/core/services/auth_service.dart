import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/services/notification_service.dart';
import 'package:castelle/core/services/private_profile_fields.dart';

/// Castelle - Firebase Auth Service
/// Kimlik doğrulama ve kullanıcı yönetim servisi (Gmail & E-posta Kimlik Doğrulama)

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

  /// Tanımlı Özel Admin Kullanıcı Listesi
  static const List<Map<String, String>> designatedAdmins = [
    {
      'name': 'Castelle Yazılım',
      'phone': '',
      'cleanPhone': '',
      'email': 'casttelleyazilim@gmail.com',
    },
    {
      'name': 'Castelle App',
      'phone': '',
      'cleanPhone': '',
      'email': 'castelleapp@gmail.com',
    },
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

  /// Firestore'daki özel tanımlı Admin rollerini senkronize et
  /// İkilik (duplicate) kayıtları temizler, yoksa oluşturur, varsa admin yapar.
  Future<void> syncAndPromoteAdminUsers() async {
    try {
      final snap = await _firestore.collection(AppConstants.usersCollection).get();
      final allDocs = snap.docs;

      for (final admin in designatedAdmins) {
        final adminClean = admin['cleanPhone'] ?? '';
        final adminName = admin['name'] ?? 'Admin';
        final adminPhone = admin['phone'] ?? '';
        final adminEmail = (admin['email'] ?? '').toLowerCase();

        // 1. Bu telefon numarasına veya e-postaya uyan tüm kayıtları bul
        final matches = allDocs.where((doc) {
          final data = doc.data();
          final p = data['phone'] as String? ?? '';
          final e = (data['email'] as String? ?? '').toLowerCase();

          final matchByPhone = adminClean.isNotEmpty && normalizePhone(p) == adminClean;
          final matchByEmail = adminEmail.isNotEmpty && e == adminEmail;

          return matchByPhone || matchByEmail;
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
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(primaryDoc.id)
              .set(updateData, SetOptions(merge: true));

          if (adminPhone.isNotEmpty) {
            // Başka kullanıcının private dokümanı — oturum admin değilse kurallar reddeder.
            try {
              await writePrivateFields(_firestore, primaryDoc.id, {'phone': adminPhone});
            } catch (_) {}
          }
        } else if (adminEmail.isNotEmpty) {
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

          final newData = <String, dynamic>{
            ...newUser.toMap(),
            'isActive': true,
            'approvalStatus': 'approved',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          final private = takePrivateFields(newData);
          await newDocRef.set(newData);
          try {
            await writePrivateFields(_firestore, newDocRef.id, private);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

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
    String? guardianName,
    String? guardianPhone,
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

      final isDesignatedAdmin = designatedAdmins.any(
        (a) => a['email']!.toLowerCase() == email.trim().toLowerCase(),
      );
      final assignedRole = isDesignatedAdmin ? UserRole.admin : UserRole.fromString(role);

      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        fullName: fullName.trim(),
        phone: phone.trim(),
        role: assignedRole,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        birthDate: birthDate,
        age: calculatedAge,
        isUnder18: under18,
        guardianName: under18 ? guardianName?.trim() : null,
        guardianPhone: under18 ? guardianPhone?.trim() : null,
        isGuardianApproved: !under18,
        guardianApprovalStatus: under18 ? 'pending' : 'approved',
        hasAcceptedTerms: hasAcceptedTerms,
        acceptedTermsAt: DateTime.now(),
        isActive: isDesignatedAdmin || !under18,
      );

      await _writeUser(user.uid, {
        ...userModel.toMap(),
        'isActive': isDesignatedAdmin || !under18,
        'isHidden': under18,
        'approvalStatus': isDesignatedAdmin ? 'approved' : (under18 ? 'pending_guardian' : 'pending'),
        if (isDesignatedAdmin) 'approvedAt': FieldValue.serverTimestamp(),
      });

      // Admin kullanıcılarına yeni üye bildirimi gönder
      try {
        final roleLabel = assignedRole.displayName;
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

      final isDesignatedAdmin = designatedAdmins.any(
        (a) => a['email']!.toLowerCase() == email.trim().toLowerCase(),
      );

      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        if (isDesignatedAdmin) {
          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(user.uid)
              .update({
            'role': UserRole.admin.value,
            'isActive': true,
            'approvalStatus': 'approved',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return await getUserData(user.uid);
      } else {
        final userModel = UserModel(
          uid: user.uid,
          email: email.trim(),
          fullName: user.displayName ?? email.split('@').first,
          phone: '',
          role: isDesignatedAdmin ? UserRole.admin : UserRole.actor,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: isDesignatedAdmin,
        );
        await _writeUser(user.uid, {
          ...userModel.toMap(),
          'isActive': isDesignatedAdmin,
          'approvalStatus': isDesignatedAdmin ? 'approved' : 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Google / Gmail ile Giriş Yap / Kayıt Ol
  Future<UserModel?> signInWithGoogle({
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
  }) {
    return _signInWithSocial(
      label: 'Google',
      isUnder18: isUnder18,
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      signIn: () async {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId: '977939722051-78bh3stbhgh85rsub18ra2c0566l1gq7.apps.googleusercontent.com',
        );
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        return _auth.signInWithCredential(GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        ));
      },
    );
  }

  /// Apple ile Giriş Yap / Kayıt Ol (iOS native akış)
  Future<UserModel?> signInWithApple({
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
  }) {
    return _signInWithSocial(
      label: 'Apple',
      isUnder18: isUnder18,
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      signIn: () => _auth.signInWithProvider(
        AppleAuthProvider()
          ..addScope('email')
          ..addScope('name'),
      ),
    );
  }

  /// Sosyal giriş sonrası ortak akış: kullanıcı dokümanını bul/taşı/oluştur.
  /// [signIn] null dönerse kullanıcı iptal etmiştir.
  Future<UserModel?> _signInWithSocial({
    required String label,
    required Future<UserCredential?> Function() signIn,
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
  }) async {
    final placeholderName = '$label Kullanıcısı';
    try {
      final UserCredential? userCredential = await signIn();
      if (userCredential == null) return null;
      final user = userCredential.user;
      if (user == null) {
        throw Exception('$label ile giriş gerçekleştirilemedi.');
      }

      final uid = user.uid;
      final email = user.email ?? '';
      final fullName = user.displayName ?? placeholderName;
      final photoUrl = user.photoURL;

      // Özel Admin listesinde bu e-posta adresi var mı?
      final designatedAdmin = designatedAdmins.firstWhere(
        (a) => a['email']!.toLowerCase() == email.toLowerCase(),
        orElse: () => {},
      );
      final isDesignatedAdmin = designatedAdmin.isNotEmpty;

      // 1. Önce UID ile Firestore dokümanını kontrol et
      var doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      // 2. Bulunamadıysa e-posta adresine göre arama yap
      if (!doc.exists && email.isNotEmpty) {
        final snap = await _firestore
            .collection(AppConstants.usersCollection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          doc = snap.docs.first;
        }
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final updateData = <String, dynamic>{
          'email': email,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if ((data['fullName'] as String? ?? '').isEmpty || data['fullName'] == placeholderName) {
          updateData['fullName'] = isDesignatedAdmin
              ? (fullName.isNotEmpty && fullName != placeholderName ? fullName : designatedAdmin['name']!)
              : fullName;
        }

        if (photoUrl != null && photoUrl.isNotEmpty && (data['profilePhotoUrl'] as String? ?? '').isEmpty) {
          updateData['profilePhotoUrl'] = photoUrl;
        }

        if (isDesignatedAdmin) {
          updateData['role'] = UserRole.admin.value;
          updateData['approvalStatus'] = 'approved';
          updateData['isActive'] = true;
        }

        // Eğer eski doküman farklı ID ile bulunduysa (e-posta araması), veriyi yeni UID'ye taşı
        if (doc.id != uid) {
          final migratedData = Map<String, dynamic>.from(data);
          migratedData.addAll(updateData);
          migratedData['uid'] = uid;

          // Eski dokümanın hassas alanları da yeni UID'ye taşınır
          migratedData.addAll(await readPrivateFields(_firestore, doc.id));

          await _writeUser(uid, migratedData);
          try { await privateProfileRef(_firestore, doc.id).delete(); } catch (_) {}
          try { await _firestore.collection(AppConstants.usersCollection).doc(doc.id).delete(); } catch (_) {}

          return await getUserData(uid);
        } else {
          await _firestore.collection(AppConstants.usersCollection).doc(uid).set(updateData, SetOptions(merge: true));
          return await getUserData(uid);
        }
      } else {
        // Yeni kullanıcı dokümanı oluştur
        final assignedRole = isDesignatedAdmin ? UserRole.admin : UserRole.actor;
        final assignedName = fullName.isNotEmpty && fullName != placeholderName
            ? fullName
            : (isDesignatedAdmin ? designatedAdmin['name']! : fullName);

        final userModel = UserModel(
          uid: uid,
          email: email,
          fullName: assignedName,
          phone: user.phoneNumber ?? '',
          role: assignedRole,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          profilePhotoUrl: photoUrl,
          isUnder18: isUnder18,
          guardianName: isUnder18 ? guardianName?.trim() : null,
          guardianPhone: isUnder18 ? guardianPhone?.trim() : null,
          isGuardianApproved: !isUnder18,
          guardianApprovalStatus: isUnder18 ? 'pending' : 'approved',
          hasAcceptedTerms: true,
          acceptedTermsAt: DateTime.now(),
        );

        await _writeUser(uid, {
          ...userModel.toMap(),
          'isActive': isDesignatedAdmin || !isUnder18,
          'isHidden': isUnder18,
          'approvalStatus': isDesignatedAdmin ? 'approved' : (isUnder18 ? 'pending_guardian' : 'pending'),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      // Apple sayfası kapatıldı (ASAuthorizationError 1001)
      if (e.code.contains('cancel') || (e.message ?? '').contains('1001')) return null;
      throw _handleAuthError(e);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('sign_in_canceled') || errStr.contains('canceled')) {
        return null;
      }
      throw Exception('$label ile giriş gerçekleştirilemedi: $e');
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

    final data = Map<String, dynamic>.from(doc.data()!);
    // Eski kayıtlarda telefon/banka kök dokümanda duruyor olabilir —
    // kullanıcı kendi oturumunda bir kez alt dokümana taşınır.
    if (uid == _auth.currentUser?.uid) {
      await migratePrivateFields(_firestore, uid, data);
    }
    data.addAll(await readPrivateFields(_firestore, uid));

    return UserModel.fromMap(data, uid);
  }

  /// Kullanıcı dokümanını yazar; hassas alanlar private alt dokümana gider.
  Future<void> _writeUser(String uid, Map<String, dynamic> data) async {
    final private = takePrivateFields(data);
    await _firestore.collection(AppConstants.usersCollection).doc(uid).set(data);
    await writePrivateFields(_firestore, uid, private);
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

  /// Şifre sıfırlama
  Future<void> resetPassword(String emailOrRecoveryEmail) async {
    try {
      final input = emailOrRecoveryEmail.trim().toLowerCase();
      
      // 1. Sistem e-posta adreslerini kontrol et (@example.com veya @castelle.com)
      if (input.endsWith('@castelle.com') || input.endsWith('@example.com')) {
        throw Exception('Bu e-posta adresi şifre sıfırlama için uygun değildir. Lütfen gerçek bir e-posta adresi kullanın.');
      }

      // 2. Doğrudan Firebase Auth üzerinden şifre sıfırlama e-postası gönder
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
    final errStr = e.toString();
    if (errStr.contains('api.j: 10') || errStr.contains('10:') || (errStr.contains('sign_in_failed') && errStr.contains('10'))) {
      return Exception('Google Sign-In SHA-1 sertifika uyuşmazlığı (Hata 10). Lütfen Google Play Console\'daki "App Signing SHA-1" parmak izini Firebase Console -> Proje Ayarları -> Android Uygulaması altına ekleyin.');
    }

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
        case 'app-not-authorized':
          return Exception('Uygulama yetkilendirilmemiş. Lütfen destek ile iletişime geçin.');
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
    return Exception('Bir hata oluştu: ${errStr.replaceAll("Exception: ", "")}');
  }
}
