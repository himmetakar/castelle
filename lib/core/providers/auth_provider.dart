import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/services/auth_service.dart';
import 'package:castelle/core/services/push_notification_service.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/services/private_profile_fields.dart';


/// Castelle - Auth Provider
/// Kimlik doğrulama durumu yönetimi

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;
  GoogleAgeVerificationRequired? _pendingGoogleUser;

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  UserRole? get userRole => _user?.role;

  /// Google ile ilk kez giriş yapan ve yaş doğrulaması bekleyen kullanıcı bilgisi.
  /// Bu null değilse, UI katmanı yaş/veli bilgisi dialog'unu göstermelidir.
  GoogleAgeVerificationRequired? get pendingGoogleUser => _pendingGoogleUser;

  /// Oturum açık olan Firebase Auth kullanıcısının e-postası doğrulanmış mı?
  /// [UserModel.emailVerificationRequired] false ise (örn. Google ile giriş)
  /// bu değer önem taşımaz.
  bool get isEmailVerified => _authService.isEmailVerified;

  /// Uygulama içeriğine erişmeden önce e-posta aktivasyonu bekleniyor mu?
  bool get needsEmailVerification =>
      isAuthenticated && (_user?.emailVerificationRequired ?? false) && !isEmailVerified;

  // Rol bazlı kontroller
  bool get isAdmin => _user?.role == UserRole.admin;
  bool get isModerator => _user?.role == UserRole.moderator;
  bool get isActor => _user?.role == UserRole.actor;
  bool get isAdminOrModerator => isAdmin || isModerator;

  /// Uygulama açılışında auth durumunu kontrol et
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;

      final firebaseUser = _authService.currentUser;
      if (firebaseUser != null && isLoggedIn) {
        try {
          _user = await _authService.getUserData(firebaseUser.uid);
        } catch (_) {
          _user = UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            fullName: firebaseUser.displayName ?? '',
            phone: firebaseUser.phoneNumber ?? '',
            role: UserRole.actor,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }
        _status = AuthStatus.authenticated;
        _errorMessage = null;

        // Aktivasyon bekleyen bir hesapsa, emailVerified durumunu sunucudan
        // tazele (kullanıcı linke başka bir cihazda/oturumda tıklamış olabilir;
        // Firebase Auth bu bilgiyi yerelde önbelleğe alır ve reload() olmadan
        // güncellenmez).
        if (_user?.emailVerificationRequired == true) {
          try {
            await _authService.reloadCurrentUserAndCheckVerified();
          } catch (_) {}
        }

        // Admin hesapları (Yağmur ve Alican) rol kontrolü ve ikilik senkronizasyonu
        // Sadece authenticated durumda çalıştır (Firestore güvenlik kuralları gerektirir)
        try {
          await _authService.syncAndPromoteAdminUsers();
        } catch (_) {}
      } else {
        if (firebaseUser != null && !isLoggedIn) {
          await _authService.signOut();
        }
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
    }

    notifyListeners();
  }

  /// Email ile kayıt
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.registerWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
        isUnder18: isUnder18,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
      );
      _status = AuthStatus.authenticated;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Email ile giriş — sadece Firebase Auth
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      _status = AuthStatus.authenticated;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Google / Gmail ile Giriş Yap / Kayıt Ol
  Future<bool> signInWithGoogle({
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _pendingGoogleUser = null;
    notifyListeners();

    try {
      final userModel = await _authService.signInWithGoogle(
        isUnder18: isUnder18,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
      );
      if (userModel == null) {
        // Giriş kullanıcı tarafından iptal edildi
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        notifyListeners();
        return false;
      }

      _user = userModel;
      _status = AuthStatus.authenticated;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      notifyListeners();
      return true;
    } on GoogleAgeVerificationRequired catch (e) {
      // Firebase Auth oturumu açıldı ama Firestore kaydı henüz yok —
      // UI, yaş/veli bilgisini toplayıp completeGoogleRegistration'ı çağırmalı.
      _pendingGoogleUser = e;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// [pendingGoogleUser] doldurulduktan sonra, yaş/veli bilgisi toplanıp
  /// Google kaydını tamamlamak için çağrılır.
  Future<bool> completeGoogleRegistration({
    required bool isUnder18,
    String? guardianName,
    String? guardianPhone,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.completeGoogleRegistration(
        isUnder18: isUnder18,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
      );
      _status = AuthStatus.authenticated;
      _pendingGoogleUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Kullanıcı yaş doğrulama dialog'unu iptal ederse, yarım kalan Google
  /// oturumunu güvenli şekilde kapatır.
  Future<void> cancelPendingGoogleRegistration() async {
    _pendingGoogleUser = null;
    try {
      await _authService.signOut();
    } catch (_) {}
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Apple ile Giriş Yap / Kayıt Ol
  Future<bool> signInWithApple({
    bool isUnder18 = false,
    String? guardianName,
    String? guardianPhone,
  }) {
    return _signInWithSocial(() => _authService.signInWithApple(
          isUnder18: isUnder18,
          guardianName: guardianName,
          guardianPhone: guardianPhone,
        ));
  }

  Future<bool> _signInWithSocial(Future<UserModel?> Function() signIn) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final userModel = await signIn();
      if (userModel == null) {
        // Giriş kullanıcı tarafından iptal edildi
        _status = AuthStatus.unauthenticated;
        _errorMessage = null;
        notifyListeners();
        return false;
      }

      _user = userModel;
      _status = AuthStatus.authenticated;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);

      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// E-posta ve Profil Detaylarını Kaydet / Güncelle
  Future<bool> saveEmailAndDetails({
    required String email,
    required String fullName,
    required UserRole role,
  }) async {
    if (_user == null) {
      _errorMessage = 'Giriş yapmış kullanıcı bulunamadı.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.updateUserEmailAndDetails(
        uid: _user!.uid,
        email: email,
        fullName: fullName,
        role: role.value,
      );

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Çıkış yap
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (_) {}
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    PushNotificationService().reset();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
    } catch (_) {}

    notifyListeners();
  }

  /// Şifre sıfırlama
  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Aktivasyon e-postasını yeniden gönder
  Future<bool> resendVerificationEmail() async {
    try {
      await _authService.resendVerificationEmail();
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Kullanıcı aktivasyon linkine tıkladıktan sonra doğrulama durumunu yeniden kontrol et
  Future<bool> refreshEmailVerification() async {
    final verified = await _authService.reloadCurrentUserAndCheckVerified();
    if (verified) {
      notifyListeners();
    }
    return verified;
  }

  /// FCM Token güncelle
  Future<void> updateFcmToken(String token) async {
    if (_user != null) {
      await _authService.updateFcmToken(_user!.uid, token);
    }
  }

  /// Kullanıcı verisini yenile
  Future<void> refreshUserData() async {
    if (_user != null) {
      try {
        _user = await _authService.getUserData(_user!.uid);
        notifyListeners();
      } catch (e) {
        _errorMessage = e.toString();
      }
    }
  }

  /// Hesabı kalıcı olarak sil (KVKK & Hesap Silme gereksinimleri)
  Future<bool> deleteAccount() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final firebaseUser = _authService.currentUser;
      if (firebaseUser == null) {
        throw Exception('Giriş yapmış kullanıcı bulunamadı.');
      }
      final uid = firebaseUser.uid;

      // 0. Apple ile giriş yapmışsa Apple token'ını iptal et (App Store 5.1.1(v)).
      // Kullanıcı Apple onayını iptal ederse hesap silinmez.
      await _authService.revokeAppleTokenIfNeeded();

      // 1. Önce kullanıcının kendi dokümanındaki tüm kişisel verileri temizle ve inaktif/pending yap
      try {
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .set({
          'uid': uid,
          'email': firebaseUser.email ?? '',
          'fullName': 'Silinmiş Kullanıcı',
          'role': 'actor',
          'isActive': false,
          'approvalStatus': 'pending',
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ [DeleteAccount] Firestore set uyarısı: $e');
      }

      // 2. Ardından Firestore dokümanını silmeyi dene.
      // Alt koleksiyon otomatik silinmez — hassas alanların dokümanı önce silinir.
      try {
        await privateProfileRef(FirebaseFirestore.instance, uid).delete();
      } catch (e) {
        debugPrint('⚠️ [DeleteAccount] Private doküman silme uyarısı: $e');
      }
      try {
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .delete();
      } catch (e) {
        debugPrint('⚠️ [DeleteAccount] Firestore delete uyarısı: $e');
      }

      // 3. Firebase Auth kullanıcısını sil
      try {
        await firebaseUser.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          debugPrint('⚠️ [DeleteAccount] Re-auth gerekebilir: $e');
        }
      } catch (_) {}

      // 4. Lokal oturum durumunu tamamen temizle
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      try {
        await _authService.signOut();
      } catch (_) {}

      notifyListeners();
      return true;
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }
}
