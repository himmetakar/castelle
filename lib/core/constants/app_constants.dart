// Castelle - App Constants
// Tüm uygulama genelinde kullanılan sabit değerler

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Castelle';
  static const String appTagline = 'Premium Casting Platform';
  static const String appVersion = '1.0.0';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String projectsCollection = 'projects';
  static const String auditionsCollection = 'auditions';
  static const String notificationsCollection = 'notifications';
  static const String skillsCollection = 'skills';

  // Storage Paths
  static const String profilePhotosPath = 'profile_photos';
  static const String auditionVideosPath = 'audition_videos';
  static const String projectAssetsPath = 'project_assets';

  // Video Compression
  static const int maxVideoSizeMB = 50;
  static const int maxVideoDurationSeconds = 180;
  static const double videoCompressionQuality = 0.7;

  // Pagination
  static const int defaultPageSize = 20;
  static const int actorListPageSize = 30;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxBioLength = 500;
  static const int maxSkillsCount = 50;
  static const int minAge = 4;
  static const int maxAge = 100;
  static const int minHeight = 50;
  static const int maxHeight = 250;
  static const int minWeight = 15;
  static const int maxWeight = 300;
}
