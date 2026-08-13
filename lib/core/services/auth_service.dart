import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:castelle/core/models/user_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/services/notification_service.dart';

/// Castelle - Firebase Auth Service
/// Kimlik doğrulama ve kullanıcı yönetim servisi

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set({
        ...userModel.toMap(),
        'isActive': true,
        'approvalStatus': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      // Admin kullanıcılarına yeni üye bildirimi gönder
      try {
        final roleLabel = UserRole.fromString(role).displayName;
        await NotificationService().sendBulkNotification(
          title: 'Yeni Üye Kaydı 👤',
          body: '${fullName.trim()} ($roleLabel) platforma yeni kayıt oldu.',
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

  /// Google ile Giriş/Kayıt
  Future<UserModel> signInWithGoogle() async {
    try {
      // Her defasında hangi Google hesabı ile giriş yapılacağını sorması için önbellekteki oturumu sıfırla
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google giriş işlemi iptal edildi.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Firebase Google kimlik doğrulaması başarısız.');
      }

      // Firestore'da kullanıcının dokümanı var mı kontrol et
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, user.uid);
      } else {
        // Firestore dokümanı yoksa varsayılan olarak 'actor' (oyuncu) rolüyle oluştur
        final userModel = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          fullName: user.displayName ?? 'Google Kullanıcısı',
          phone: '',
          role: UserRole.actor,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .set({
          ...userModel.toMap(),
          'isActive': true,
          'approvalStatus': 'approved',
          'approvedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Admin kullanıcılarına yeni üye bildirimi gönder
        try {
          await NotificationService().sendBulkNotification(
            title: 'Yeni Üye Kaydı (Google) 👤',
            body: '${user.displayName ?? "Google Kullanıcısı"} (Oyuncu) platforma yeni kayıt oldu.',
            type: NotificationType.systemMessage,
            target: NotificationTarget.admins,
          );
        } catch (_) {}

        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    } catch (e) {
      throw Exception('Google ile giriş başarısız: $e');
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
    if (e.message != null && e.message!.contains('CONFIGURATION_NOT_FOUND')) {
      return Exception('Firebase Console\'da E-posta/Şifre giriş yöntemi etkinleştirilmemiş. Lütfen Firebase Console -> Authentication -> Sign-in method altından E-posta/Şifre seçeneğini etkinleştirin.');
    }
    switch (e.code) {
      case 'configuration-not-found':
        return Exception('Firebase Console\'da E-posta/Şifre giriş yöntemi etkinleştirilmemiş. Lütfen Firebase Console -> Authentication -> Sign-in method altından E-posta/Şifre seçeneğini etkinleştirin.');
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
