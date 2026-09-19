import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/services/notification_service.dart';

/// Castelle - Firebase Auth Service
/// Kimlik doğrulama ve kullanıcı yönetim servisi (Gmail & E-posta Kimlik Doğrulama)

/// Google ile ilk kez giriş yapan bir kullanıcı için yaş doğrulaması henüz
/// yapılmadığında fırlatılır. Firebase Auth oturumu zaten açılmıştır;
/// UI katmanı yaş/veli bilgisini topladıktan sonra
/// [AuthService.completeGoogleRegistration] ile kaydı tamamlamalıdır.
class GoogleAgeVerificationRequired implements Exception {
  final String uid;
  final String email;
  final String fullName;
  final String? photoUrl;

  GoogleAgeVerificationRequired({
    required this.uid,
    required this.email,
    required this.fullName,
    this.photoUrl,
  });

  @override
  String toString() => 'GoogleAgeVerificationRequired($email)';
}

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
          if ((data['phone'] as String? ?? '').isEmpty && adminPhone.isNotEmpty) {
            updateData['phone'] = adminPhone;
          }

          await _firestore
              .collection(AppConstants.usersCollection)
              .doc(primaryDoc.id)
              .set(updateData, SetOptions(merge: true));
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

      // Aktivasyon (e-posta doğrulama) e-postası gönder.
      // Kullanıcı linke tıklayıp e-postasını doğrulamadan uygulama verisine erişemez.
      try {
        await user.sendEmailVerification();
      } catch (e) {
        // Doğrulama e-postası gönderilemese bile kayıt akışını durdurmuyoruz;
        // kullanıcı doğrulama ekranından "Tekrar Gönder" ile yeniden deneyebilir.
      }

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
        // Google ile değil, normal e-posta/şifre ile kaydolan kullanıcılar
        // e-postalarını doğrulamadan uygulama içine giremez.
        emailVerificationRequired: !isDesignatedAdmin,
      );

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
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
        final updatedDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();
        return UserModel.fromMap(updatedDoc.data()!, user.uid);
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
        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set({
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
  /// [ageVerified] true değilse ve bu Google hesabıyla ilişkili bir Firestore
  /// kaydı yoksa (yani ilk kez kaydoluyorsa), [GoogleAgeVerificationRequired]
  /// fırlatılır — UI katmanı yaş/veli bilgisini topladıktan sonra
  /// [completeGoogleRegistration] ile kaydı tamamlamalıdır.
  Future<UserModel?> signInWithGoogle({
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
    bool ageVerified = false,
  }) async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '977939722051-78bh3stbhgh85rsub18ra2c0566l1gq7.apps.googleusercontent.com',
      );
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('Google ile giriş gerçekleştirilemedi.');
      }

      final uid = user.uid;
      final email = user.email ?? googleUser.email;
      final fullName = user.displayName ?? googleUser.displayName ?? 'Google Kullanıcısı';
      final photoUrl = user.photoURL ?? googleUser.photoUrl;

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

        if ((data['fullName'] as String? ?? '').isEmpty || data['fullName'] == 'Google Kullanıcısı') {
          updateData['fullName'] = isDesignatedAdmin
              ? (fullName.isNotEmpty && fullName != 'Google Kullanıcısı' ? fullName : designatedAdmin['name']!)
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

          await _firestore.collection(AppConstants.usersCollection).doc(uid).set(migratedData);
          try { await _firestore.collection(AppConstants.usersCollection).doc(doc.id).delete(); } catch (_) {}

          final newDoc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
          return UserModel.fromMap(newDoc.data()!, uid);
        } else {
          await _firestore.collection(AppConstants.usersCollection).doc(uid).set(updateData, SetOptions(merge: true));
          final updatedDoc = await _firestore.collection(AppConstants.usersCollection).doc(uid).get();
          return UserModel.fromMap(updatedDoc.data()!, uid);
        }
      } else {
        // Yeni kullanıcı — Firestore'da hiç kaydı yok.
        // ÖNEMLİ: Firestore dokümanını platformdan bağımsız her zaman HEMEN
        // oluşturuyoruz (web/mobil popup akışındaki farklılıklara güvenmemek
        // için). Yaş doğrulaması henüz yapılmadıysa hesap 'incomplete'
        // durumunda ve admin onay kuyruğunun DIŞINDA oluşturulur —
        // kullanıcı Profilini Düzenle ekranından bu bilgiyi doldurmadan
        // hesabı admin onayına düşmez. Ayrıca UI'a da haber veriyoruz ki
        // (mümkünse) girişin hemen ardından bir dialog ile de sorulabilsin.
        final userModel = await _createGoogleUserDocument(
          uid: uid,
          email: email,
          fullName: fullName,
          phone: user.phoneNumber,
          photoUrl: photoUrl,
          isDesignatedAdmin: isDesignatedAdmin,
          designatedAdminName: isDesignatedAdmin ? designatedAdmin['name'] : null,
          isUnder18: isUnder18,
          guardianName: guardianName,
          guardianPhone: guardianPhone,
          ageConfirmed: ageVerified,
        );

        if (!ageVerified) {
          throw GoogleAgeVerificationRequired(
            uid: uid,
            email: email,
            fullName: fullName,
            photoUrl: photoUrl,
          );
        }

        return userModel;
      }
    } on GoogleAgeVerificationRequired {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('sign_in_canceled') || errStr.contains('canceled')) {
        return null;
      }
      throw Exception('Google ile giriş gerçekleştirilemedi: $e');
    }
  }

  /// Yaş doğrulaması (ve gerekliyse veli bilgisi) toplandıktan sonra,
  /// Google ile ilk kez giriş yapan bir kullanıcının Firestore kaydını oluşturur.
  /// Firebase Auth oturumu [signInWithGoogle] tarafından zaten açılmış olmalıdır.
  Future<UserModel> completeGoogleRegistration({
    required bool isUnder18,
    String? guardianName,
    String? guardianPhone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı. Lütfen Gmail ile girişi tekrar deneyin.');
    }

    final uid = user.uid;
    final email = user.email ?? '';
    final fullName = user.displayName ?? 'Google Kullanıcısı';
    final photoUrl = user.photoURL;

    final designatedAdmin = designatedAdmins.firstWhere(
      (a) => a['email']!.toLowerCase() == email.toLowerCase(),
      orElse: () => {},
    );
    final isDesignatedAdmin = designatedAdmin.isNotEmpty;

    return _createGoogleUserDocument(
      uid: uid,
      email: email,
      fullName: fullName,
      phone: user.phoneNumber,
      photoUrl: photoUrl,
      isDesignatedAdmin: isDesignatedAdmin,
      designatedAdminName: isDesignatedAdmin ? designatedAdmin['name'] : null,
      isUnder18: isUnder18,
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      ageConfirmed: true,
    );
  }

  /// Google ile ilk kayıt olan bir kullanıcı için Firestore dokümanını oluşturur.
  /// [ageConfirmed] false ise (yaş sorusu henüz cevaplanmadıysa), hesap
  /// 'incomplete' durumunda ve admin onay kuyruğunun (streamPendingActors)
  /// DIŞINDA oluşturulur; admin'e "Yeni Üye Kaydı" bildirimi de o ana kadar
  /// GÖNDERİLMEZ. Kullanıcı Profilini Düzenle ekranından yaş bilgisini
  /// tamamladığında hesap normal onay akışına girer.
  Future<UserModel> _createGoogleUserDocument({
    required String uid,
    required String email,
    required String fullName,
    String? phone,
    String? photoUrl,
    required bool isDesignatedAdmin,
    String? designatedAdminName,
    required bool isUnder18,
    String? guardianName,
    String? guardianPhone,
    required bool ageConfirmed,
  }) async {
    final assignedRole = isDesignatedAdmin ? UserRole.admin : UserRole.actor;
    final assignedName = fullName.isNotEmpty && fullName != 'Google Kullanıcısı'
        ? fullName
        : (isDesignatedAdmin ? (designatedAdminName ?? fullName) : fullName);

    final userModel = UserModel(
      uid: uid,
      email: email,
      fullName: assignedName,
      phone: phone ?? '',
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
      // Google hesabının e-postası zaten Google tarafından doğrulanmıştır,
      // ayrıca bir aktivasyon e-postasına gerek yoktur.
      emailVerificationRequired: false,
      ageConfirmed: ageConfirmed,
    );

    final String approvalStatus = isDesignatedAdmin
        ? 'approved'
        : (!ageConfirmed
            ? 'incomplete' // Yaş sorusu cevaplanmadan admin onay kuyruğuna DÜŞMEZ
            : (isUnder18 ? 'pending_guardian' : 'pending'));

    await _firestore.collection(AppConstants.usersCollection).doc(uid).set({
      ...userModel.toMap(),
      'isActive': isDesignatedAdmin || (!isUnder18 && ageConfirmed),
      'isHidden': isUnder18 || !ageConfirmed,
      'approvalStatus': approvalStatus,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Admin kullanıcılarına yeni üye bildirimi gönder — SADECE yaş bilgisi
    // gerçekten doğrulanmışsa (yani hesap fiilen onaya sunulabilir durumdaysa).
    if (ageConfirmed) {
      try {
        final roleLabel = assignedRole.displayName;
        final extraTag = isUnder18 ? ' (18 Yaş Altı - Veli Onayı Bekliyor)' : '';
        await NotificationService().sendBulkNotification(
          title: 'Yeni Üye Kaydı 👤',
          body: '$assignedName ($roleLabel)$extraTag platforma yeni kayıt oldu.',
          type: NotificationType.systemMessage,
          target: NotificationTarget.admins,
        );
      } catch (_) {}
    }

    return userModel;
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

  /// Mevcut Firebase Auth kullanıcısının e-posta adresi doğrulanmış mı?
  /// (Google ile giriş yapan kullanıcıların e-postası zaten doğrulanmış sayılır.)
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? true;

  /// Aktivasyon (e-posta doğrulama) e-postasını yeniden gönder
  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Oturum bulunamadı.');
    }
    if (user.emailVerified) return;
    await user.sendEmailVerification();
  }

  /// Firebase Auth kullanıcı bilgisini sunucudan yeniden yükle
  /// (kullanıcı aktivasyon linkine tıkladıktan sonra emailVerified durumunu
  /// güncel olarak okuyabilmek için gereklidir).
  Future<bool> reloadCurrentUserAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
    } catch (_) {}
    return _auth.currentUser?.emailVerified ?? false;
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
