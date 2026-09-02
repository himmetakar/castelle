import 'package:cloud_firestore/cloud_firestore.dart';
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
  final DateTime? birthDate; // Doğum tarihi
  final int? age; // Yaş
  final bool isUnder18; // 18 yaş altı mı?
  final bool isGuardianApproved; // Veli / Yasal temsilci onayladı mı?
  final String guardianApprovalStatus; // 'pending', 'approved', 'rejected'
  final bool hasAcceptedTerms; // Sözleşmeler ve KVKK onaylandı mı?
  final DateTime? acceptedTermsAt; // Onaylanma tarihi

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
    this.birthDate,
    this.age,
    this.isUnder18 = false,
    this.isGuardianApproved = false,
    this.guardianApprovalStatus = 'pending',
    this.hasAcceptedTerms = false,
    this.acceptedTermsAt,
  });

  /// Firestore'dan UserModel oluştur
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final parsedAge = map['age'] is int
        ? map['age'] as int
        : (map['age'] != null ? int.tryParse(map['age'].toString()) : null);

    final under18Flag = map['isUnder18'] ?? (parsedAge != null && parsedAge < 18);

    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      phone: map['phone'] ?? '',
      role: UserRole.fromString(map['role'] ?? 'actor'),
      profilePhotoUrl: map['profilePhotoUrl'],
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
      metadata: map['metadata'],
      recoveryEmail: map['recoveryEmail'],
      moderatorPermissions: map['moderatorPermissions'] is Map
          ? Map<String, dynamic>.from(map['moderatorPermissions'])
          : null,
      birthDate: parseDate(map['birthDate']),
      age: parsedAge,
      isUnder18: under18Flag,
      isGuardianApproved: map['isGuardianApproved'] ?? false,
      guardianApprovalStatus: map['guardianApprovalStatus'] ?? (under18Flag ? 'pending' : 'approved'),
      hasAcceptedTerms: map['hasAcceptedTerms'] ?? false,
      acceptedTermsAt: parseDate(map['acceptedTermsAt']),
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
      'birthDate': birthDate?.toIso8601String(),
      'age': age,
      'isUnder18': isUnder18,
      'isGuardianApproved': isGuardianApproved,
      'guardianApprovalStatus': guardianApprovalStatus,
      'hasAcceptedTerms': hasAcceptedTerms,
      'acceptedTermsAt': acceptedTermsAt?.toIso8601String(),
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
    DateTime? birthDate,
    int? age,
    bool? isUnder18,
    bool? isGuardianApproved,
    String? guardianApprovalStatus,
    bool? hasAcceptedTerms,
    DateTime? acceptedTermsAt,
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
      birthDate: birthDate ?? this.birthDate,
      age: age ?? this.age,
      isUnder18: isUnder18 ?? this.isUnder18,
      isGuardianApproved: isGuardianApproved ?? this.isGuardianApproved,
      guardianApprovalStatus: guardianApprovalStatus ?? this.guardianApprovalStatus,
      hasAcceptedTerms: hasAcceptedTerms ?? this.hasAcceptedTerms,
      acceptedTermsAt: acceptedTermsAt ?? this.acceptedTermsAt,
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
