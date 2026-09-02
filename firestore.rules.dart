// Castelle - Firestore Security Rules
// Bu kuralları Firebase Console → Firestore → Rules sekmesine yapıştırın

/*
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isOwner(userId) || isSignedIn();
      allow update, delete: if isOwner(userId) || isSignedIn();
    }

    match /projects/{projectId} {
      allow read, create, update, delete: if isSignedIn();
    }

    match /auditions/{auditionId} {
      allow read, create, update, delete: if isSignedIn();
    }

    match /notifications/{notificationId} {
      allow read, create, update, delete: if isSignedIn();
    }

    match /skills/{skillId} {
      allow read, write: if isSignedIn();
    }

    match /moderator_approvals/{approvalId} {
      allow read, write: if isSignedIn();
    }

    match /chats/{chatId} {
      allow read, write: if isSignedIn();

      match /messages/{messageId} {
        allow read, write: if isSignedIn();
      }
    }

    match /calendar_events/{eventId} {
      allow read, write: if isSignedIn();
    }

    match /settings/{settingId} {
      allow read, write: if isSignedIn();
    }
  }
}
*/
