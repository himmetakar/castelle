// Castelle - Firestore Security Rules
// Bu kuralları Firebase Console → Firestore → Rules sekmesine yapıştırın

/*
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ═══════════════════════════════════════
    // YARDIMCI FONKSİYONLAR
    // ═══════════════════════════════════════

    // Giriş yapmış mı?
    function isSignedIn() {
      return request.auth != null;
    }

    // Kendi belgesi mi?
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // Kullanıcının rolünü al
    function getUserRole() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role;
    }

    // Admin mi?
    function isAdmin() {
      return isSignedIn() && getUserRole() == 'admin';
    }

    // Moderatör mü?
    function isModerator() {
      return isSignedIn() && getUserRole() == 'moderator';
    }

    // Admin veya Moderatör mü?
    function isAdminOrModerator() {
      return isAdmin() || isModerator();
    }

    // Yönetmen mi?
    function isDirector() {
      return isSignedIn() && getUserRole() == 'director';
    }

    // İş Veren mi?
    function isEmployer() {
      return isSignedIn() && getUserRole() == 'employer';
    }

    // Oyuncu mu?
    function isActor() {
      return isSignedIn() && getUserRole() == 'actor';
    }

    // ═══════════════════════════════════════
    // USERS KOLEKSİYONU
    // ═══════════════════════════════════════
    match /users/{userId} {
      // Herkes kendi profilini okuyabilir
      // Admin ve Moderatör tüm profilleri okuyabilir
      allow read: if isOwner(userId) || isAdminOrModerator() || isDirector() || isEmployer();

      // Sadece kayıt sırasında oluşturulabilir (kendi uid'si ile)
      allow create: if isOwner(userId);

      // Kendi profilini güncelleyebilir, Admin herkesin rolünü değiştirebilir
      allow update: if isOwner(userId) || isAdmin();

      // Sadece Admin silebilir
      allow delete: if isAdmin();
    }

    // ═══════════════════════════════════════
    // PROJECTS KOLEKSİYONU
    // ═══════════════════════════════════════
    match /projects/{projectId} {
      // Herkes projeleri okuyabilir (kendi rolüne göre filtreleme frontend'de)
      allow read: if isSignedIn();

      // İş Veren ve Admin proje oluşturabilir
      allow create: if isEmployer() || isAdmin();

      // İş Veren (kendi projesi) ve Admin güncelleyebilir
      allow update: if isAdmin() || (isEmployer() && resource.data.employerId == request.auth.uid);

      // Sadece Admin silebilir
      allow delete: if isAdmin();
    }

    // ═══════════════════════════════════════
    // AUDITIONS KOLEKSİYONU
    // ═══════════════════════════════════════
    match /auditions/{auditionId} {
      // Admin, Moderatör, Yönetmen ve ilgili oyuncu okuyabilir
      allow read: if isAdminOrModerator() || isDirector()
                     || (isActor() && resource.data.actorId == request.auth.uid);

      // Oyuncu kendi audition'ını oluşturabilir
      allow create: if isActor() && request.resource.data.actorId == request.auth.uid;

      // Admin, Moderatör güncelleyebilir (yönetmene atama vb.)
      // Yönetmen onay/ret yapabilir
      allow update: if isAdminOrModerator() || isDirector();

      // Sadece Admin silebilir
      allow delete: if isAdmin();
    }

    // ═══════════════════════════════════════
    // NOTIFICATIONS KOLEKSİYONU
    // ═══════════════════════════════════════
    match /notifications/{notificationId} {
      // Kendi bildirimlerini okuyabilir
      allow read: if isSignedIn() && (resource.data.userId == request.auth.uid || resource.data.recipientId == request.auth.uid);

      // Admin, Moderatör, Yönetmen ve İş Veren bildirim oluşturabilir
      allow create: if isAdminOrModerator() || isDirector() || isEmployer();

      // Okundu olarak işaretleme
      allow update: if isSignedIn() && (resource.data.userId == request.auth.uid || resource.data.recipientId == request.auth.uid);

      // Sadece Admin silebilir
      allow delete: if isAdmin();
    }

    // ═══════════════════════════════════════
    // SKILLS KOLEKSİYONU (Global yetenek listesi)
    // ═══════════════════════════════════════
    match /skills/{skillId} {
      allow read: if isSignedIn();
      allow write: if isAdminOrModerator();
    }
  }
}
*/
