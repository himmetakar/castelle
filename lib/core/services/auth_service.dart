import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Onaylatılan yasal metinlerin (KVKK aydınlatma, açık rıza, kullanım
/// koşulları) sürümü. Metinler değiştiğinde güncellenmelidir.
const String kLegalTextsVersion = '2026-08-13';

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
  ///
  /// GÜVENLİK: Bu listedeki e-postalar ancak e-posta adresi DOĞRULANMIŞ
  /// oturumlarda admin yetkisi alır (bkz. [isVerifiedDesignatedAdmin]).
  /// Aynı liste firestore.rules içindeki isDesignatedAdmin() fonksiyonunda
  /// da tanımlıdır; ikisi birlikte güncellenmelidir.
  /// (KVKK: kişilere ait telefon numaraları kaynak koddan kaldırıldı.)
  static const List<Map<String, String>> designatedAdmins = [
    {'name': 'Castelle Yazılım', 'email': 'casttelleyazilim@gmail.com'},
    {'name': 'Castelle App', 'email': 'castelleapp@gmail.com'},
    // GÜVENLİK: "@castelle.com" adresleri listeden çıkarıldı. Bu alan adı
    // şirkete ait değilse, alan adının sahibi bu adreslerle kayıt olup
    // e-postasını doğrulayarak otomatik admin olabilirdi. Bu adreslerle
    // zaten admin olan hesaplar yetkisini korur; yeni admin gerekiyorsa
    // mevcut bir admin, panelden rol ataması yapmalıdır.
  ];

  /// Oturum açmış kullanıcı, e-postası doğrulanmış bir tanımlı admin mi?
  /// Doğrulanmamış bir e-posta ile kayıt olan biri admin olamaz.
  static bool isVerifiedDesignatedAdmin(User? user) {
    if (user == null || !user.emailVerified) return false;
    final email = (user.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return false;
    return designatedAdmins.any((a) => a['email']!.toLowerCase() == email);
  }

  static String? _designatedAdminName(String email) {
    final e = email.trim().toLowerCase();
    for (final a in designatedAdmins) {
      if (a['email']!.toLowerCase() == e) return a['name'];
    }
    return null;
  }

  /// Telefon Numarası Temizleme & Alan Kodu Esnekliği Yardımcısı (Son 10 Hane)
  static String normalizePhone(String rawPhone) {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Oturum açan kullanıcı, e-postası doğrulanmış tanımlı bir admin ise
  /// SADECE KENDİ belgesinde admin rolünü garanti eder.
  ///
  /// GÜVENLİK: Önceki sürüm tüm kullanıcıları okuyup telefon/e-posta
  /// eşleşmesiyle başkalarının belgelerini admin yapıyor ve "mükerrer"
  /// kayıtları istemciden siliyordu. Telefon numarası kullanıcı tarafından
  /// girildiği için bu yolla herkes kendini admin yapabiliyordu.
  Future<void> syncAndPromoteAdminUsers() async {
    final user = _auth.currentUser;
    if (!isVerifiedDesignatedAdmin(user)) return;
    try {
      final ref = _firestore.collection(AppConstants.usersCollection).doc(user!.uid);
      final doc = await ref.get();
      final data = doc.data();
      if (data != null &&
          data['role'] == UserRole.admin.value &&
          data['approvalStatus'] == 'approved') {
        return;
      }
      await ref.set({
        'role': UserRole.admin.value,
        'isActive': true,
        'approvalStatus': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    Map<String, bool>? consents,
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

      // GÜVENLİK: Kayıt anında e-posta henüz doğrulanmamıştır; bu yüzden
      // hiçbir hesap kayıt olurken admin olamaz ve kayıt ekranından gelen rol
      // değerine güvenilmez. Tanımlı admin, e-postasını doğrulayıp giriş
      // yaptığında [syncAndPromoteAdminUsers] ile yetkilendirilir.
      const isDesignatedAdmin = false;
      const assignedRole = UserRole.actor;

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

      await _writeUser(user.uid, {
        ...userModel.toMap(),
        'isActive': isDesignatedAdmin || !under18,
        'isHidden': under18,
        'approvalStatus': under18 ? 'pending_guardian' : 'pending',
        // KVKK: onaylanan metinler ve rızalar ispat için saklanır
        if (consents != null)
          'consents': {
            ...consents,
            'acceptedAt': FieldValue.serverTimestamp(),
            'textVersion': kLegalTextsVersion,
          },
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

      // Sadece e-postası doğrulanmış tanımlı adminler yetki alır
      final isDesignatedAdmin = isVerifiedDesignatedAdmin(user);

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
  /// [ageVerified] true değilse ve bu Google hesabıyla ilişkili bir Firestore
  /// kaydı yoksa (yani ilk kez kaydoluyorsa), [GoogleAgeVerificationRequired]
  /// fırlatılır — UI katmanı yaş/veli bilgisini topladıktan sonra
  /// [completeGoogleRegistration] ile kaydı tamamlamalıdır.
  Future<UserModel?> signInWithGoogle({
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
    bool ageVerified = false,
  }) {
    return _signInWithSocial(
      label: 'Google',
      isUnder18: isUnder18,
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      signIn: () async {
        // Web'de google_sign_in paketi serverClientId desteklemez ve
        // "Assertion failed: serverClientId is not supported on Web" hatası
        // verir. Web'de Firebase Auth'un kendi Google açılır penceresi kullanılır.
        if (kIsWeb) {
          final provider = GoogleAuthProvider()
            ..addScope('email')
            ..setCustomParameters({'prompt': 'select_account'});
          return _auth.signInWithPopup(provider);
        }

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
      // Google ile ilk kez kaydolan kullanıcı için yaş doğrulaması zorunlu:
      // doğrulanmamışsa hesap 'incomplete' durumunda oluşturulur ve UI'a
      // GoogleAgeVerificationRequired ile haber verilir.
      onCreateNewUser: ({
        required String uid,
        required String email,
        required String fullName,
        String? phone,
        String? photoUrl,
        required bool isDesignatedAdmin,
        String? designatedAdminName,
      }) async {
        final userModel = await _createGoogleUserDocument(
          uid: uid,
          email: email,
          fullName: fullName,
          phone: phone,
          photoUrl: photoUrl,
          isDesignatedAdmin: isDesignatedAdmin,
          designatedAdminName: designatedAdminName,
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

  /// Apple ile bağlı hesapta Apple token'ını iptal eder (hesap silmeden önce).
  /// Yeni authorization code için Apple ile yeniden onay istenir.
  Future<void> revokeAppleTokenIfNeeded() async {
    final user = _auth.currentUser;
    if (user == null || !user.providerData.any((p) => p.providerId == 'apple.com')) return;

    try {
      final credential = await user.reauthenticateWithProvider(AppleAuthProvider());
      final code = credential.additionalUserInfo?.authorizationCode;
      if (code != null) await _auth.revokeTokenWithAuthorizationCode(code);
    } on FirebaseAuthException catch (e) {
      if (e.code.contains('cancel') || (e.message ?? '').contains('1001')) {
        throw Exception('Hesap silme iptal edildi.');
      }
      throw _handleAuthError(e);
    }
  }

  /// Sosyal giriş sonrası ortak akış: kullanıcı dokümanını bul/taşı/oluştur.
  /// [signIn] null dönerse kullanıcı iptal etmiştir.
  Future<UserModel?> _signInWithSocial({
    required String label,
    required Future<UserCredential?> Function() signIn,
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
    // Sağlanırsa, yeni kullanıcı dokümanı oluşturma akışını devralır
    // (örn. Google için yaş doğrulama zorunluluğu). Sağlanmazsa varsayılan
    // (Apple'ın bugüne kadarki) davranış kullanılır.
    Future<UserModel> Function({
      required String uid,
      required String email,
      required String fullName,
      String? phone,
      String? photoUrl,
      required bool isDesignatedAdmin,
      String? designatedAdminName,
    })? onCreateNewUser,
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

      // Özel Admin listesinde bu e-posta var mı? (sadece doğrulanmış e-posta)
      final isDesignatedAdmin = isVerifiedDesignatedAdmin(user);
      final designatedAdmin = <String, String>{
        if (isDesignatedAdmin) 'name': _designatedAdminName(email) ?? fullName,
      };

      // Kullanıcının belgesi yalnızca kendi UID'si ile aranır.
      // GÜVENLİK: Önceki sürüm aynı e-postaya sahip BAŞKA bir belgeyi bulup
      // verisini bu hesaba taşıyor ve eski belgeyi siliyordu (hesap/veri
      // devralma riski).
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final updateData = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        // E-posta hassas alan → private alt doküman
        if (email.isNotEmpty) {
          try {
            await writePrivateFields(_firestore, uid, {'email': email});
          } catch (_) {}
        }

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

        await _firestore.collection(AppConstants.usersCollection).doc(uid).set(updateData, SetOptions(merge: true));
        return await getUserData(uid);
      } else {
        if (onCreateNewUser != null) {
          return await onCreateNewUser(
            uid: uid,
            email: email,
            fullName: fullName,
            phone: user.phoneNumber,
            photoUrl: photoUrl,
            isDesignatedAdmin: isDesignatedAdmin,
            designatedAdminName: isDesignatedAdmin ? designatedAdmin['name'] : null,
          );
        }

        // Yeni kullanıcı dokümanı oluştur (varsayılan davranış — Apple)
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
    } on GoogleAgeVerificationRequired {
      rethrow;
    } on FirebaseAuthException catch (e) {
      // Apple sayfası kapatıldı (ASAuthorizationError 1001)
      if (e.code.contains('cancel') ||
          e.code == 'popup-closed-by-user' ||
          (e.message ?? '').contains('1001')) {
        return null;
      }
      throw _handleAuthError(e);
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('sign_in_canceled') || errStr.contains('canceled')) {
        return null;
      }
      throw Exception('$label ile giriş gerçekleştirilemedi: $e');
    }
  }

  /// [pendingGoogleUser] doldurulduktan sonra, yaş/veli bilgisi toplanıp
  /// Google kaydını tamamlamak için çağrılır.
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

    final isDesignatedAdmin = isVerifiedDesignatedAdmin(user);
    final designatedAdmin = <String, String>{
      if (isDesignatedAdmin) 'name': _designatedAdminName(email) ?? fullName,
    };

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

    // Doğum tarihi hassas alandır → private alt doküman
    if (birthDate != null) {
      await writePrivateFields(_firestore, uid, {'birthDate': birthDate.toIso8601String()});
    }
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

      // GÜVENLİK: Rol bu yolla değiştirilemez (yalnızca admin paneli).
      // E-posta hassas alan olarak private alt dokümanda tutulur.
      final updateData = <String, dynamic>{
        'fullName': fullName.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .set(updateData, SetOptions(merge: true));
      await writePrivateFields(_firestore, uid, {'email': email.trim()});

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
