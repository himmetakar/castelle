import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/services/auth_service.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:castelle/core/constants/app_constants.dart';


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

  // Phone Auth State
  String? _verificationId;
  bool _codeSent = false;
  String? _phoneNumber;

  // Getters
  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  UserRole? get userRole => _user?.role;
  String? get verificationId => _verificationId;
  bool get codeSent => _codeSent;
  String? get phoneNumber => _phoneNumber;

  // Rol bazlı kontroller
  bool get isAdmin => _user?.role == UserRole.admin;
  bool get isModerator => _user?.role == UserRole.moderator;
  bool get isActor => _user?.role == UserRole.actor;
  bool get isAdminOrModerator => isAdmin || isModerator;

  // Demo hesap şifresi
  static const String demoPassword = 'Castelle2024!';

  /// Demo hesap e-posta adresi döndür
  static String demoEmail(UserRole role) => '${role.value}@castelle.com';

  /// Demo hesap adı
  static String _demoFullName(UserRole role) {
    switch (role) {
      case UserRole.actor:     return 'Can Demir';
      case UserRole.admin:     return 'Demo Admin';
      case UserRole.moderator: return 'Demo Moderatör';
    }
  }

  /// Demo ve Admin hesaplarını Firebase Auth + Firestore'da oluştur ve senkronize et.
  static Future<void> seedDemoAccounts() async {
    final authService = AuthService();
    await authService.syncAndPromoteAdminUsers();

    for (final role in UserRole.values) {
      final email = demoEmail(role);
      final fullName = _demoFullName(role);
      try {
        await authService.registerWithEmail(
          email: email,
          password: demoPassword,
          fullName: fullName,
          phone: '05555555555',
          role: role.value,
        );
        debugPrint('✅ [Seed] Hesap oluşturuldu: $email');

        // Oyuncu için ek profil verisi ekle
        if (role == UserRole.actor) {
          await authService.seedActorProfile(email);
        }
      } catch (e) {
        final err = e.toString();
        if (err.contains('email-already-in-use') ||
            err.contains('Bu e-posta adresi zaten kullanımda')) {
          debugPrint('ℹ️  [Seed] Zaten var: $email');
          // Oyuncu profili eksikse tamamla
          if (role == UserRole.actor) {
            await authService.seedActorProfile(email);
          }
        } else {
          debugPrint('⚠️  [Seed] $email hatası: $err');
        }
      }
    }

    // Gerçek moderatör demo hesapları — Merve Çelik & Burak Öztürk
    final namedModerators = [
      {'email': 'merve@example.com', 'fullName': 'Merve Çelik', 'phone': '05455798600'},
      {'email': 'burak@example.com', 'fullName': 'Burak Öztürk', 'phone': '05366667788'},
    ];

    for (final mod in namedModerators) {
      try {
        await authService.registerWithEmail(
          email: mod['email']!,
          password: demoPassword,
          fullName: mod['fullName']!,
          phone: mod['phone']!,
          role: UserRole.moderator.value,
        );
        debugPrint('✅ [Seed] Moderatör oluşturuldu: ${mod['email']}');
      } catch (e) {
        final err = e.toString();
        if (err.contains('email-already-in-use') ||
            err.contains('Bu e-posta adresi zaten kullanımda')) {
          debugPrint('ℹ️  [Seed] Zaten var: ${mod['email']}');
        } else {
          debugPrint('⚠️  [Seed] ${mod['email']} hatası: $err');
        }
      }
    }
  }

  /// 8 gerçek oyuncu hesabı oluştur — Firebase Auth + zengin Firestore profil
  static Future<void> seedMockActors() async {
    final authService = AuthService();
    final firestore = FirebaseFirestore.instance;

    final actors = [
      {
        'email': 'canan@example.com',
        'fullName': 'Canan Yılmaz',
        'phone': '05321112233',
        'age': 26, 'gender': 'female', 'heightCm': 168, 'weightKg': 54,
        'eyeColor': 'hazel', 'hairColor': 'auburn', 'city': 'İstanbul',
        'experienceLevel': 'advanced',
        'bio': 'Profesyonel tiyatro oyuncusuyum. Reklam ve sinema projelerinde yer almak istiyorum.',
        'skills': ['İngilizce', 'Modern Dans', 'Araba Kullanma', 'Tiyatro'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/women/10.jpg',
      },
      {
        'email': 'kaan@example.com',
        'fullName': 'Kaan Demir',
        'phone': '05332223344',
        'age': 31, 'gender': 'male', 'heightCm': 184, 'weightKg': 78,
        'eyeColor': 'brown', 'hairColor': 'black', 'city': 'İstanbul',
        'experienceLevel': 'professional',
        'bio': 'Birçok dizide yardımcı oyuncu olarak rol aldım. Aksiyon ve dram sahnelerinde tecrübeliyim.',
        'skills': ['Boks', 'Ata Binme', 'Motor Kullanma', 'Eskrim'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/men/12.jpg',
      },
      {
        'email': 'emre@example.com',
        'fullName': 'Emre Kaya',
        'phone': '05454445566',
        'age': 28, 'gender': 'male', 'heightCm': 178, 'weightKg': 72,
        'eyeColor': 'green', 'hairColor': 'brown', 'city': 'İstanbul',
        'experienceLevel': 'intermediate',
        'bio': 'Model ve oyuncuyum. Marka tanıtımları ve televizyon reklamları için işbirliklerine açığım.',
        'skills': ['Yüzme', 'Gitar', 'İngilizce', 'Futbol'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/men/32.jpg',
      },
      {
        'email': 'dilek@example.com',
        'fullName': 'Dilek Soydan',
        'phone': '05355556677',
        'age': 35, 'gender': 'female', 'heightCm': 170, 'weightKg': 60,
        'eyeColor': 'brown', 'hairColor': 'black', 'city': 'İstanbul',
        'experienceLevel': 'professional',
        'bio': '10 yıllık tiyatro ve dizi oyunculuğu geçmişim var. Seslendirme sanatçılığı da yapmaktayım.',
        'skills': ['Seslendirme', 'Sunuculuk', 'Almanca', 'Piyano'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/women/44.jpg',
      },
      {
        'email': 'elif@example.com',
        'fullName': 'Elif Aslan',
        'phone': '05377778899',
        'age': 29, 'gender': 'female', 'heightCm': 165, 'weightKg': 52,
        'eyeColor': 'brown', 'hairColor': 'brown', 'city': 'İstanbul',
        'experienceLevel': 'advanced',
        'bio': 'Dram ve dönem dizilerinde rol aldım. Disiplinli ve gelişime açığım.',
        'skills': ['Ata Binme', 'Eskrim', 'İngilizce', 'Fransızca'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/women/60.jpg',
      },
      {
        'email': 'yigit@example.com',
        'fullName': 'Yiğit Şen',
        'phone': '05388889900',
        'age': 42, 'gender': 'male', 'heightCm': 188, 'weightKg': 85,
        'eyeColor': 'blue', 'hairColor': 'gray', 'city': 'İstanbul',
        'experienceLevel': 'professional',
        'bio': 'Karakter oyuncusu. Sinema ve dizi sektöründe uzun yıllardır yer alıyorum.',
        'skills': ['Araba Kullanma', 'Yüzme', 'Dubbing', 'Motosiklet'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/men/78.jpg',
      },
      {
        'email': 'selin@example.com',
        'fullName': 'Selin Arslan',
        'phone': '05311112233',
        'age': 24, 'gender': 'female', 'heightCm': 162, 'weightKg': 49,
        'eyeColor': 'blue', 'hairColor': 'blonde', 'city': 'Ankara',
        'experienceLevel': 'intermediate',
        'bio': 'Dans ve müzik konusunda kendimi geliştiriyorum. Komedi ve müzikal türlere ilgi duyuyorum.',
        'skills': ['Bale', 'Şarkı Söyleme', 'Piyano', 'İngilizce'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/women/22.jpg',
      },
      {
        'email': 'tolga@example.com',
        'fullName': 'Tolga Çetin',
        'phone': '05366667788',
        'age': 33, 'gender': 'male', 'heightCm': 180, 'weightKg': 80,
        'eyeColor': 'hazel', 'hairColor': 'black', 'city': 'İzmir',
        'experienceLevel': 'advanced',
        'bio': 'Belgesel ve kısa film projelerinde deneyim sahibiyim. Sahne önü ve kamera önü oyunculuğunda ustalık geliştirdim.',
        'skills': ['Akrobasi', 'Yüzme', 'Boks', 'Araba Kullanma'],
        'profilePhotoUrl': 'https://randomuser.me/api/portraits/men/55.jpg',
      },
    ];

    for (final actor in actors) {
      final email = actor['email'] as String;
      final fullName = actor['fullName'] as String;
      final phone = actor['phone'] as String;

      String? uid;
      try {
        final userModel = await authService.registerWithEmail(
          email: email,
          password: demoPassword,
          fullName: fullName,
          phone: phone,
          role: UserRole.actor.value,
        );
        uid = userModel.uid;
        debugPrint('✅ [Seed] Oyuncu Auth oluşturuldu: $email → $uid');
      } catch (e) {
        final err = e.toString();
        if (err.contains('email-already-in-use') ||
            err.contains('Bu e-posta adresi zaten kullanımda')) {
          // UID'yi Firestore'dan bul
          try {
            final snap = await firestore
                .collection('users')
                .where('email', isEqualTo: email)
                .limit(1)
                .get();
            if (snap.docs.isNotEmpty) uid = snap.docs.first.id;
          } catch (_) {}
          debugPrint('ℹ️  [Seed] Oyuncu zaten var: $email → $uid');
        } else {
          debugPrint('⚠️  [Seed] $email hatası: $err');
          continue;
        }
      }

      if (uid == null) continue;

      // Zengin profil verisini Firestore'a yaz
      final skills = actor['skills'] as List<String>;
      try {
        await firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': email,
          'fullName': fullName,
          'phone': phone,
          'role': 'actor',
          'isActive': true,
          'isProfileComplete': true,
          'completionPercentage': 90,
          'approvalStatus': 'approved',
          'age': actor['age'],
          'gender': actor['gender'],
          'heightCm': actor['heightCm'],
          'weightKg': actor['weightKg'],
          'eyeColor': actor['eyeColor'],
          'hairColor': actor['hairColor'],
          'city': actor['city'],
          'country': 'Türkiye',
          'bio': actor['bio'],
          'experienceLevel': actor['experienceLevel'],
          'skills': skills,
          'skillsLowercase': skills.map((s) => s.toLowerCase()).toList(),
          'profilePhotoUrl': actor['profilePhotoUrl'],
          'isHidden': false,
          'galleryPhotoUrls': [],
          'filmography': [],
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ [Seed] Oyuncu profil yazıldı: $email');
      } catch (e) {
        debugPrint('⚠️  [Seed] $email profil hatası: $e');
      }
    }
  }

  /// Uygulama açılışında auth durumunu kontrol et
  Future<void> checkAuthStatus() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Admin hesapları (Yağmur ve Alican) rol kontrolü ve ikilik senkronizasyonu
      await _authService.syncAndPromoteAdminUsers();

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

  /// SMS Kodu Gönder (Telefon Numarası ile)
  Future<bool> sendPhoneOtp(String rawPhone) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _codeSent = false;
    notifyListeners();

    final completer = Completer<bool>();
    bool autoVerified = false;

    try {
      String formattedPhone = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
      if (formattedPhone.startsWith('0')) {
        formattedPhone = '+90${formattedPhone.substring(1)}';
      } else if (!formattedPhone.startsWith('+')) {
        formattedPhone = '+90$formattedPhone';
      }

      _phoneNumber = formattedPhone;

      await _authService.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        onCodeSent: (verificationId) {
          if (autoVerified) return;
          _verificationId = verificationId;
          _codeSent = true;
          _status = AuthStatus.unauthenticated;
          _errorMessage = null;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        },
        onError: (error) {
          if (autoVerified) return;
          _status = AuthStatus.error;
          _errorMessage = error.toString().replaceAll('Exception: ', '');
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
        },
        onAutoVerify: (credential) async {
          autoVerified = true;
          try {
            final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
            if (userCred.user != null) {
              final uid = userCred.user!.uid;
              final phone = userCred.user!.phoneNumber ?? '';

              try {
                _user = await _authService.getUserData(uid);
              } catch (_) {
                final cleanPhone = AuthService.normalizePhone(phone);
                final designatedAdmin = AuthService.designatedAdmins.firstWhere(
                  (a) => a['cleanPhone'] == cleanPhone,
                  orElse: () => {},
                );
                final isDesignatedAdmin = designatedAdmin.isNotEmpty;
                final assignedRole = isDesignatedAdmin ? UserRole.admin : UserRole.actor;
                final assignedName = isDesignatedAdmin ? designatedAdmin['name']! : '';
                final assignedEmail = isDesignatedAdmin ? designatedAdmin['email']! : '';

                _user = UserModel(
                  uid: uid,
                  email: assignedEmail,
                  fullName: assignedName,
                  phone: phone,
                  role: assignedRole,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await FirebaseFirestore.instance
                    .collection(AppConstants.usersCollection)
                    .doc(uid)
                    .set({
                  ..._user!.toMap(),
                  'isActive': true,
                  'approvalStatus': isDesignatedAdmin ? 'approved' : 'pending',
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              }
              _codeSent = false;
              _verificationId = null;
              _status = AuthStatus.authenticated;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('is_logged_in', true);
              notifyListeners();
              if (!completer.isCompleted) completer.complete(true);
            }
          } catch (e) {
            _status = AuthStatus.error;
            _errorMessage = e.toString().replaceAll('Exception: ', '');
            notifyListeners();
            if (!completer.isCompleted) completer.complete(false);
          }
        },
      );

      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (!completer.isCompleted) {
            _status = AuthStatus.error;
            _errorMessage = 'SMS gönderme zaman aşımına uğradı. Lütfen tekrar deneyin.';
            notifyListeners();
            completer.complete(false);
          }
          return false;
        },
      );
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// SMS Kodunu Doğrula ve Giriş Yap
  Future<bool> verifyPhoneOtp(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'Doğrulama kimliği bulunamadı. Lütfen tekrar SMS kodu isteyin.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithPhoneCredential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      _status = AuthStatus.authenticated;

      // Telefon doğrulama state'ini sıfırla
      _codeSent = false;
      _verificationId = null;

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

  /// SMS Girişi Sonrası E-posta Tanımlama / Güncelleme
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

  /// Telefon Giriş Durumunu Sıfırla
  void resetPhoneAuth() {
    _verificationId = null;
    _codeSent = false;
    _phoneNumber = null;
    notifyListeners();
  }

  /// Çıkış yap
  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (_) {}
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    _verificationId = null;
    _codeSent = false;
    _phoneNumber = null;
    
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

      // 1. Önce kullanıcının kendi dokümanındaki tüm kişisel verileri temizle ve inaktif/pending yap
      try {
        await FirebaseFirestore.instance
            .collection(AppConstants.usersCollection)
            .doc(uid)
            .set({
          'uid': uid,
          'email': firebaseUser.email ?? '',
          'fullName': 'Silinmiş Kullanıcı',
          'phone': '',
          'role': 'actor',
          'isActive': false,
          'approvalStatus': 'pending',
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('⚠️ [DeleteAccount] Firestore set uyarısı: $e');
      }

      // 2. Ardından Firestore dokümanını silmeyi dene
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
