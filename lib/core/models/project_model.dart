import 'package:cloud_firestore/cloud_firestore.dart';

// Castelle - Project Model
// İş Veren ve Admin tarafından oluşturulan casting projeleri

/// Proje durumu
enum ProjectStatus {
  draft('draft', 'Taslak'),
  active('active', 'Aktif'),
  casting('casting', 'Casting Aşaması'),
  completed('completed', 'Tamamlandı'),
  cancelled('cancelled', 'İptal');

  const ProjectStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static ProjectStatus fromString(String value) {
    return ProjectStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ProjectStatus.draft,
    );
  }
}

/// Proje içindeki rol ilanı
class ProjectRole {
  final String roleName;        // Örn: "Ana Karakter", "Figüran"
  final String? description;
  final String? auditionNotes;  // Oyuncunun audition çekerken dikkat etmesi gereken notlar
  final String? auditionScript; // Prompter için ön tanımlı audition metni
  final int? ageMin;
  final int? ageMax;
  final String? gender;         // 'male', 'female', 'other', null(farketmez)
  final int? heightMin;
  final int? heightMax;
  final List<String> requiredSkills;
  final int quota;              // Kaç kişi alınacak
  final double? budget;         // Rol bütçesi
  final String? backgroundAudioUrl; // Audition kaydı sırasında çalacak arka plan sesi

  const ProjectRole({
    required this.roleName,
    this.description,
    this.auditionNotes,
    this.auditionScript,
    this.ageMin,
    this.ageMax,
    this.gender,
    this.heightMin,
    this.heightMax,
    this.requiredSkills = const [],
    this.quota = 1,
    this.budget,
    this.backgroundAudioUrl,
  });

  factory ProjectRole.fromMap(Map<String, dynamic> map) {
    return ProjectRole(
      roleName: map['roleName'] ?? '',
      description: map['description'],
      auditionNotes: map['auditionNotes'],
      auditionScript: map['auditionScript'],
      ageMin: map['ageMin'] != null ? int.tryParse(map['ageMin'].toString()) : null,
      ageMax: map['ageMax'] != null ? int.tryParse(map['ageMax'].toString()) : null,
      gender: map['gender'],
      heightMin: map['heightMin'] != null ? int.tryParse(map['heightMin'].toString()) : null,
      heightMax: map['heightMax'] != null ? int.tryParse(map['heightMax'].toString()) : null,
      requiredSkills: (map['requiredSkills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      quota: map['quota'] ?? 1,
      budget: map['budget'] != null ? double.tryParse(map['budget'].toString()) : null,
      backgroundAudioUrl: map['backgroundAudioUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'roleName': roleName,
      'description': description,
      'auditionNotes': auditionNotes,
      'auditionScript': auditionScript,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'gender': gender,
      'heightMin': heightMin,
      'heightMax': heightMax,
      'requiredSkills': requiredSkills,
      'quota': quota,
      'budget': budget,
      'backgroundAudioUrl': backgroundAudioUrl,
    };
  }
}

/// Proje Modeli
class ProjectModel {
  final String id;
  final String title;
  final String? description;
  final String employerId;       // Oluşturan iş verenin uid'si
  final String employerName;     // İş verenin adı
  final ProjectStatus status;
  final List<ProjectRole> roles; // Proje içindeki roller
  final DateTime? deadline;      // Son başvuru tarihi
  final String? location;        // Çekim lokasyonu
  final String? projectType;     // 'film', 'dizi', 'reklam', 'klip', 'tiyatro'
  final String? directorId;      // Atanan yönetmen uid
  final String? directorName;    // Atanan yönetmen adı
  final String? coordinatorId;    // Atanan casting sorumlusu (moderatör) uid
  final String? coordinatorName;  // Atanan casting sorumlusu (moderatör) adı
  final String? coordinatorPhone; // Atanan casting sorumlusu (moderatör) telefon no
  final String? primaryImageUrl;  // Birincil görsel URL'si
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> galleryImageUrls;
  final String? sampleVideoUrl;
  final double? budget;
  // New details fields
  final String? shootDate;       // Çekim tarihi
  final String? shootDuration;   // Çekim süresi
  final String? media;           // Mecra
  final bool cashPayment;        // Peşin ödeme
  final bool isPrivate;          // Gizli proje
  final String? scenario;        // Senaryo (zengin metin / markdown)

  const ProjectModel({
    required this.id,
    required this.title,
    this.description,
    required this.employerId,
    required this.employerName,
    this.status = ProjectStatus.draft,
    this.roles = const [],
    this.deadline,
    this.location,
    this.projectType,
    this.directorId,
    this.directorName,
    this.coordinatorId,
    this.coordinatorName,
    this.coordinatorPhone,
    this.primaryImageUrl,
    required this.createdAt,
    this.updatedAt,
    this.galleryImageUrls = const [],
    this.sampleVideoUrl,
    this.budget,
    this.shootDate,
    this.shootDuration,
    this.media,
    this.cashPayment = false,
    this.isPrivate = false,
    this.scenario,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> map, String id) {
    final rolesList = (map['roles'] as List<dynamic>?)
            ?.map((r) => ProjectRole.fromMap(r as Map<String, dynamic>))
            .toList() ??
        [];

    return ProjectModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'],
      employerId: map['employerId'] ?? '',
      employerName: map['employerName'] ?? '',
      status: ProjectStatus.fromString(map['status'] ?? 'draft'),
      roles: rolesList,
      deadline: (map['deadline'] as Timestamp?)?.toDate(),
      location: map['location'],
      projectType: map['projectType'],
      directorId: map['directorId'],
      directorName: map['directorName'],
      coordinatorId: map['coordinatorId'],
      coordinatorName: map['coordinatorName'],
      coordinatorPhone: map['coordinatorPhone'],
      primaryImageUrl: map['primaryImageUrl'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      galleryImageUrls: (map['galleryImageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sampleVideoUrl: map['sampleVideoUrl'],
      budget: map['budget'] != null ? double.tryParse(map['budget'].toString()) : null,
      shootDate: map['shootDate'],
      shootDuration: map['shootDuration'],
      media: map['media'],
      cashPayment: map['cashPayment'] ?? false,
      isPrivate: map['isPrivate'] ?? false,
      scenario: map['scenario'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'employerId': employerId,
      'employerName': employerName,
      'status': status.value,
      'roles': roles.map((r) => r.toMap()).toList(),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'location': location,
      'projectType': projectType,
      'directorId': directorId,
      'directorName': directorName,
      'coordinatorId': coordinatorId,
      'coordinatorName': coordinatorName,
      'coordinatorPhone': coordinatorPhone,
      'primaryImageUrl': primaryImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'galleryImageUrls': galleryImageUrls,
      'sampleVideoUrl': sampleVideoUrl,
      'budget': budget,
      'shootDate': shootDate,
      'shootDuration': shootDuration,
      'media': media,
      'cashPayment': cashPayment,
      'isPrivate': isPrivate,
      'scenario': scenario,
      // Filtreleme için
      'requiredSkillsAll': roles
          .expand((r) => r.requiredSkills)
          .map((s) => s.toLowerCase())
          .toSet()
          .toList(),
    };
  }

  /// Toplam kota
  int get totalQuota => roles.fold(0, (total, r) => total + r.quota);

  /// Proje türü etiketi
  String get projectTypeLabel {
    return switch (projectType) {
      'film' => '🎬 Film',
      'dizi' => '📺 Dizi',
      'reklam' => '📢 Reklam',
      'klip' => '🎵 Klip',
      'tiyatro' => '🎭 Tiyatro',
      'kisa_film' => '🎞️ Kısa Film',
      _ => '🎬 Proje',
    };
  }

  ProjectModel copyWith({
    String? title,
    String? description,
    ProjectStatus? status,
    List<ProjectRole>? roles,
    DateTime? deadline,
    String? location,
    String? projectType,
    String? directorId,
    String? directorName,
    String? coordinatorId,
    String? coordinatorName,
    String? coordinatorPhone,
    String? primaryImageUrl,
    bool clearDeadline = false,
    bool clearCoordinator = false,
    List<String>? galleryImageUrls,
    String? sampleVideoUrl,
    double? budget,
    String? shootDate,
    String? shootDuration,
    String? media,
    bool? cashPayment,
    bool? isPrivate,
    String? scenario,
  }) {
    return ProjectModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      employerId: employerId,
      employerName: employerName,
      status: status ?? this.status,
      roles: roles ?? this.roles,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      location: location ?? this.location,
      projectType: projectType ?? this.projectType,
      directorId: directorId ?? this.directorId,
      directorName: directorName ?? this.directorName,
      coordinatorId: clearCoordinator ? null : (coordinatorId ?? this.coordinatorId),
      coordinatorName: clearCoordinator ? null : (coordinatorName ?? this.coordinatorName),
      coordinatorPhone: clearCoordinator ? null : (coordinatorPhone ?? this.coordinatorPhone),
      primaryImageUrl: primaryImageUrl ?? this.primaryImageUrl,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      sampleVideoUrl: sampleVideoUrl ?? this.sampleVideoUrl,
      budget: budget ?? this.budget,
      shootDate: shootDate ?? this.shootDate,
      shootDuration: shootDuration ?? this.shootDuration,
      media: media ?? this.media,
      cashPayment: cashPayment ?? this.cashPayment,
      isPrivate: isPrivate ?? this.isPrivate,
      scenario: scenario ?? this.scenario,
    );
  }
}

/// Proje türleri
class ProjectTypes {
  ProjectTypes._();

  static const List<Map<String, String>> all = [
    {'value': 'film', 'label': 'Film', 'icon': '🎬'},
    {'value': 'dizi', 'label': 'Dizi', 'icon': '📺'},
    {'value': 'reklam', 'label': 'Reklam', 'icon': '📢'},
    {'value': 'klip', 'label': 'Müzik Klibi', 'icon': '🎵'},
    {'value': 'tiyatro', 'label': 'Tiyatro', 'icon': '🎭'},
    {'value': 'kisa_film', 'label': 'Kısa Film', 'icon': '🎞️'},
  ];
}
