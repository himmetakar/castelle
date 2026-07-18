// Castelle - User Roles Enum
// Sistemdeki tüm kullanıcı rolleri

enum UserRole {
  admin('admin', 'Admin', 'Sistem Yöneticisi'),
  moderator('moderator', 'Moderatör', 'İçerik Moderatörü'),
  actor('actor', 'Oyuncu', 'Oyuncu / Sanatçı');

  const UserRole(this.value, this.displayName, this.description);

  final String value;
  final String displayName;
  final String description;

  /// String'den UserRole'e çevirme
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.actor,
    );
  }
}
