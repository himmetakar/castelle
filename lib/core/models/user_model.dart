import 'package:castelle/core/constants/user_roles.dart';

/// Castelle - User Model
/// Tüm roller için temel kullanıcı veri modeli

class UserModel {
  final String uid;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final String? profilePhotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final String? recoveryEmail; // ikincil kurtarma e-postası
  final Map<String, dynamic>? moderatorPermissions; // moderatör yetkileri

  const UserModel({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.profilePhotoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.metadata,
    this.recoveryEmail,
    this.moderatorPermissions,
  });

  /// Firestore'dan UserModel oluştur
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      role: UserRole.fromString(map['role'] ?? 'actor'),
      profilePhotoUrl: map['profilePhotoUrl'],
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['createdAt'].millisecondsSinceEpoch)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['updatedAt'].millisecondsSinceEpoch)
          : DateTime.now(),
      isActive: map['isActive'] ?? true,
      metadata: map['metadata'],
      recoveryEmail: map['recoveryEmail'],
      moderatorPermissions: map['moderatorPermissions'] is Map
          ? Map<String, dynamic>.from(map['moderatorPermissions'])
          : null,
    );
  }

  /// UserModel'i Firestore Map'e çevir
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.value,
      'profilePhotoUrl': profilePhotoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isActive': isActive,
      'metadata': metadata,
      'recoveryEmail': recoveryEmail,
      'moderatorPermissions': moderatorPermissions,
    };
  }

  /// Kopyalama ile güncelleme
  UserModel copyWith({
    String? email,
    String? fullName,
    String? phone,
    UserRole? role,
    String? profilePhotoUrl,
    bool? isActive,
    Map<String, dynamic>? metadata,
    String? recoveryEmail,
    Map<String, dynamic>? moderatorPermissions,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      moderatorPermissions: moderatorPermissions ?? this.moderatorPermissions,
    );
  }

  /// Yetki kontrolü yardımcısı
  bool hasModeratorPermission(String permission) {
    if (role == UserRole.admin) return true;
    if (role != UserRole.moderator) return false;
    if (moderatorPermissions == null) return false;
    if (moderatorPermissions!['tamYetki'] == true) return true;
    if (moderatorPermissions!['auditionTamYetki'] == true && permission.startsWith('audition')) return true;
    return moderatorPermissions![permission] == true;
  }
}
