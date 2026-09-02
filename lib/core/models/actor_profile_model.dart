// Castelle - Actor Profile Model
// Oyuncunun tüm statik ve dinamik profil verileri

/// Cinsiyet enum
enum Gender {
  male('male', 'Erkek'),
  female('female', 'Kadın'),
  other('other', 'Diğer');

  const Gender(this.value, this.displayName);
  final String value;
  final String displayName;

  static Gender fromString(String value) {
    return Gender.values.firstWhere(
      (g) => g.value == value,
      orElse: () => Gender.other,
    );
  }
}

/// Göz rengi
enum EyeColor {
  brown('brown', 'Kahverengi'),
  blue('blue', 'Mavi'),
  green('green', 'Yeşil'),
  hazel('hazel', 'Ela'),
  gray('gray', 'Gri'),
  black('black', 'Siyah'),
  other('other', 'Diğer');

  const EyeColor(this.value, this.displayName);
  final String value;
  final String displayName;

  static EyeColor fromString(String value) {
    return EyeColor.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EyeColor.other,
    );
  }
}

/// Saç rengi
enum HairColor {
  black('black', 'Siyah'),
  brown('brown', 'Kahverengi'),
  blonde('blonde', 'Sarı'),
  red('red', 'Kızıl'),
  gray('gray', 'Gri/Beyaz'),
  auburn('auburn', 'Kumral'),
  other('other', 'Diğer');

  const HairColor(this.value, this.displayName);
  final String value;
  final String displayName;

  static HairColor fromString(String value) {
    return HairColor.values.firstWhere(
      (h) => h.value == value,
      orElse: () => HairColor.other,
    );
  }
}

/// Oyuncu Profil Modeli
class ActorProfileModel {
  final String uid;

  // Temel bilgiler (UserModel'den gelen)
  final String fullName;
  final String email;
  final String phone;
  final String? emergencyPhone;
  final String? bankIban;
  final String? bankAccountHolder;
  final String? profilePhotoUrl;
  final String? recoveryEmail;

  // Fiziksel özellikler
  final int? age;
  final int? birthYear;
  final Gender? gender;
  final int? heightCm;
  final int? weightKg;
  final EyeColor? eyeColor;
  final HairColor? hairColor;

  // Konum
  final String? city;
  final String? country;

  // Biyografi
  final String? bio;

  // Deneyim
  final String? experienceLevel; // 'beginner', 'intermediate', 'advanced', 'professional'

  // ═══════════════════════════════════════
  // DİNAMİK YETENEK HAVUZU
  // Firestore'da List<String> olarak tutulur
  // Ucu açık - oyuncu istediği yeteneği girebilir
  // ═══════════════════════════════════════
  final List<String> skills;

  // ═══════════════════════════════════════
  // KATEGORİZE YETENEKLER (opsiyonel detay)
  // Firestore'da Map<String, List<String>> olarak tutulur
  // Örn: {'diller': ['İngilizce', 'Almanca'], 'spor': ['Yüzme', 'Eskrim']}
  // ═══════════════════════════════════════
  final Map<String, List<String>> categorizedSkills;

  // Eğitim ve sertifikalar
  final List<String> education;

  // Sosyal medya
  final String? instagramHandle;
  final String? tiktokHandle;
  final String? xHandle;
  final String? youtubeChannel;
  final String? imdbLink;

  // Profil tamamlanma yüzdesi
  final bool isProfileComplete;

  // Yeni Alanlar
  final List<String> galleryPhotoUrls;
  final List<Map<String, dynamic>> filmography; // {year: String, projectType: String, projectTitle: String, director: String}
  final List<String> hobbies;
  final String? introVideoUrl;
  final String? showreelVideoUrl;
  final String? performanceVideoUrl;
  final String? expressionVideoUrl;
  final Map<String, bool> lockedSections;
  final bool isHidden;
  final List<String> acceptedNdas;

  // Admin onay sistemi
  final String approvalStatus; // 'pending', 'approved', 'rejected'
  final String? adminNote;     // Admin'in düzenleyici mesajı

  // Yeni Detaylı Profil Alanları
  final String? bodyMeasurements; // Beden Ölçüleri (Örn: 90-60-90 / M)
  final String? shoeSize; // Ayakkabı Numarası (Örn: 42)
  final List<String> actingEducation; // Oyunculuk Eğitimi
  final List<String> theaterExperience; // Tiyatro Deneyimi
  final List<String> seriesExperience; // Dizi Deneyimi
  final List<String> movieExperience; // Film Deneyimi
  final List<String> commercialExperience; // Reklam Deneyimi
  final Map<String, String> languageLevels; // Yabancı Diller & Seviyeleri (Örn: {'İngilizce': 'İleri (C1)'})
  final List<String> accents; // Aksanlar (Örn: Ege, Karadeniz, İngiliz)
  final List<String> drivingLicense; // Ehliyet (Örn: B Sınıfı, A2)
  final String? cvPdfUrl; // PDF CV Dosya Linki
  final String? cvText; // Yazılı CV / Özgeçmiş
  final List<Map<String, dynamic>> projectVideos; // Geçmiş Proje Videoları

  const ActorProfileModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phone,
    this.emergencyPhone,
    this.bankIban,
    this.bankAccountHolder,
    this.profilePhotoUrl,
    this.recoveryEmail,
    this.age,
    this.birthYear,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.eyeColor,
    this.hairColor,
    this.city,
    this.country,
    this.bio,
    this.experienceLevel,
    this.skills = const [],
    this.categorizedSkills = const {},
    this.education = const [],
    this.instagramHandle,
    this.tiktokHandle,
    this.xHandle,
    this.youtubeChannel,
    this.imdbLink,
    this.isProfileComplete = false,
    this.galleryPhotoUrls = const [],
    this.filmography = const [],
    this.hobbies = const [],
    this.introVideoUrl,
    this.showreelVideoUrl,
    this.performanceVideoUrl,
    this.expressionVideoUrl,
    this.lockedSections = const {},
    this.isHidden = false,
    this.acceptedNdas = const [],
    this.approvalStatus = 'pending', // Yeni/Varsayılan kayıtlar onay bekler
    this.adminNote,
    this.bodyMeasurements,
    this.shoeSize,
    this.actingEducation = const [],
    this.theaterExperience = const [],
    this.seriesExperience = const [],
    this.movieExperience = const [],
    this.commercialExperience = const [],
    this.languageLevels = const {},
    this.accents = const [],
    this.drivingLicense = const [],
    this.cvPdfUrl,
    this.cvText,
    this.projectVideos = const [],
  });

  /// Firestore'dan oluştur
  factory ActorProfileModel.fromMap(Map<String, dynamic> map, String uid) {
    final skills = (map['skills'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final categorizedSkills = <String, List<String>>{};
    if (map['categorizedSkills'] != null) {
      final raw = map['categorizedSkills'] as Map<String, dynamic>;
      for (final entry in raw.entries) {
        categorizedSkills[entry.key] = (entry.value as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      }
    }

    final education = (map['education'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final galleryPhotoUrls = (map['galleryPhotoUrls'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final hobbies = (map['hobbies'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final filmography = (map['filmography'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    final lockedSections = <String, bool>{};
    if (map['lockedSections'] != null) {
      final raw = map['lockedSections'] as Map<String, dynamic>;
      for (final entry in raw.entries) {
        if (entry.value is bool) {
          lockedSections[entry.key] = entry.value as bool;
        }
      }
    }

    final acceptedNdas = (map['acceptedNdas'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final actingEducation = (map['actingEducation'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final theaterExperience = (map['theaterExperience'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final seriesExperience = (map['seriesExperience'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final movieExperience = (map['movieExperience'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final commercialExperience = (map['commercialExperience'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final accents = (map['accents'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final drivingLicense = (map['drivingLicense'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final languageLevels = <String, String>{};
    if (map['languageLevels'] != null) {
      final raw = map['languageLevels'] as Map<String, dynamic>;
      for (final entry in raw.entries) {
        languageLevels[entry.key] = entry.value.toString();
      }
    }

    final projectVideos = (map['projectVideos'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    return ActorProfileModel(
      uid: uid,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      emergencyPhone: map['emergencyPhone'],
      bankIban: map['bankIban'],
      bankAccountHolder: map['bankAccountHolder'],
      profilePhotoUrl: map['profilePhotoUrl'],
      recoveryEmail: map['recoveryEmail'],
      age: map['age'],
      birthYear: map['birthYear'],
      gender: map['gender'] != null
          ? Gender.fromString(map['gender'])
          : null,
      heightCm: map['heightCm'],
      weightKg: map['weightKg'],
      eyeColor: map['eyeColor'] != null
          ? EyeColor.fromString(map['eyeColor'])
          : null,
      hairColor: map['hairColor'] != null
          ? HairColor.fromString(map['hairColor'])
          : null,
      city: map['city'],
      country: map['country'],
      bio: map['bio'],
      experienceLevel: map['experienceLevel'],
      skills: skills,
      categorizedSkills: categorizedSkills,
      education: education,
      instagramHandle: map['instagramHandle'],
      tiktokHandle: map['tiktokHandle'],
      xHandle: map['xHandle'],
      youtubeChannel: map['youtubeChannel'],
      imdbLink: map['imdbLink'],
      isProfileComplete: map['isProfileComplete'] ?? false,
      galleryPhotoUrls: galleryPhotoUrls,
      filmography: filmography,
      hobbies: hobbies,
      introVideoUrl: map['introVideoUrl'],
      showreelVideoUrl: map['showreelVideoUrl'],
      performanceVideoUrl: map['performanceVideoUrl'],
      expressionVideoUrl: map['expressionVideoUrl'],
      lockedSections: lockedSections,
      isHidden: map['isHidden'] ?? false,
      acceptedNdas: acceptedNdas,
      approvalStatus: map['approvalStatus'] as String? ?? 'pending',
      adminNote: map['adminNote'] as String?,
      bodyMeasurements: map['bodyMeasurements'],
      shoeSize: map['shoeSize'],
      actingEducation: actingEducation,
      theaterExperience: theaterExperience,
      seriesExperience: seriesExperience,
      movieExperience: movieExperience,
      commercialExperience: commercialExperience,
      languageLevels: languageLevels,
      accents: accents,
      drivingLicense: drivingLicense,
      cvPdfUrl: map['cvPdfUrl'],
      cvText: map['cvText'],
      projectVideos: projectVideos,
    );
  }

  /// Firestore'a kaydet
  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'emergencyPhone': emergencyPhone,
      'bankIban': bankIban,
      'bankAccountHolder': bankAccountHolder,
      'profilePhotoUrl': profilePhotoUrl,
      'recoveryEmail': recoveryEmail,
      'age': age,
      'birthYear': birthYear,
      'gender': gender?.value,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'eyeColor': eyeColor?.value,
      'hairColor': hairColor?.value,
      'city': city,
      'country': country,
      'bio': bio,
      'experienceLevel': experienceLevel,
      'skills': skills,
      'categorizedSkills': categorizedSkills,
      'education': education,
      'instagramHandle': instagramHandle,
      'tiktokHandle': tiktokHandle,
      'xHandle': xHandle,
      'youtubeChannel': youtubeChannel,
      'imdbLink': imdbLink,
      'isProfileComplete': isProfileComplete,
      // Filtreleme için skills'i lowercase olarak da tut
      'skillsLowercase': skills.map((s) => s.toLowerCase()).toList(),
      'galleryPhotoUrls': galleryPhotoUrls,
      'filmography': filmography,
      'hobbies': hobbies,
      'introVideoUrl': introVideoUrl,
      'showreelVideoUrl': showreelVideoUrl,
      'performanceVideoUrl': performanceVideoUrl,
      'expressionVideoUrl': expressionVideoUrl,
      'lockedSections': lockedSections,
      'isHidden': isHidden,
      'acceptedNdas': acceptedNdas,
      'approvalStatus': approvalStatus,
      'adminNote': adminNote,
      'bodyMeasurements': bodyMeasurements,
      'shoeSize': shoeSize,
      'actingEducation': actingEducation,
      'theaterExperience': theaterExperience,
      'seriesExperience': seriesExperience,
      'movieExperience': movieExperience,
      'commercialExperience': commercialExperience,
      'languageLevels': languageLevels,
      'accents': accents,
      'drivingLicense': drivingLicense,
      'cvPdfUrl': cvPdfUrl,
      'cvText': cvText,
      'projectVideos': projectVideos,
    };
  }

  /// Profil tamamlanma yüzdesini hesapla
  int get completionPercentage {
    int total = 0;
    int filled = 0;

    // Zorunlu alanlar (ağırlıklı)
    total += 10; if (fullName.isNotEmpty) filled += 10;
    total += 5;  if (phone.isNotEmpty) filled += 5;
    total += 10; if (age != null) filled += 10;
    total += 10; if (gender != null) filled += 10;
    total += 8;  if (heightCm != null) filled += 8;
    total += 8;  if (weightKg != null) filled += 8;
    total += 5;  if (eyeColor != null) filled += 5;
    total += 5;  if (hairColor != null) filled += 5;
    total += 5;  if (city != null && city!.isNotEmpty) filled += 5;
    total += 10; if (bio != null && bio!.isNotEmpty) filled += 10;
    total += 15; if (skills.isNotEmpty) filled += 15;
    total += 5;  if (experienceLevel != null) filled += 5;
    total += 4;  if (profilePhotoUrl != null) filled += 4;

    if (total == 0) return 0;
    return ((filled / total) * 100).round();
  }

  /// Kopya oluştur
  ActorProfileModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? emergencyPhone,
    String? bankIban,
    String? bankAccountHolder,
    String? profilePhotoUrl,
    String? recoveryEmail,
    int? age,
    int? birthYear,
    Gender? gender,
    int? heightCm,
    int? weightKg,
    EyeColor? eyeColor,
    HairColor? hairColor,
    String? city,
    String? country,
    String? bio,
    String? experienceLevel,
    List<String>? skills,
    Map<String, List<String>>? categorizedSkills,
    List<String>? education,
    String? instagramHandle,
    String? tiktokHandle,
    String? xHandle,
    String? youtubeChannel,
    String? imdbLink,
    bool? isProfileComplete,
    List<String>? galleryPhotoUrls,
    List<Map<String, dynamic>>? filmography,
    List<String>? hobbies,
    String? introVideoUrl,
    String? showreelVideoUrl,
    String? performanceVideoUrl,
    String? expressionVideoUrl,
    Map<String, bool>? lockedSections,
    bool? isHidden,
    List<String>? acceptedNdas,
    String? approvalStatus,
    String? adminNote,
    String? bodyMeasurements,
    String? shoeSize,
    List<String>? actingEducation,
    List<String>? theaterExperience,
    List<String>? seriesExperience,
    List<String>? movieExperience,
    List<String>? commercialExperience,
    Map<String, String>? languageLevels,
    List<String>? accents,
    List<String>? drivingLicense,
    String? cvPdfUrl,
    String? cvText,
    List<Map<String, dynamic>>? projectVideos,
  }) {
    return ActorProfileModel(
      uid: uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      bankIban: bankIban ?? this.bankIban,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      age: age ?? this.age,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      eyeColor: eyeColor ?? this.eyeColor,
      hairColor: hairColor ?? this.hairColor,
      city: city ?? this.city,
      country: country ?? this.country,
      bio: bio ?? this.bio,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      skills: skills ?? this.skills,
      categorizedSkills: categorizedSkills ?? this.categorizedSkills,
      education: education ?? this.education,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      tiktokHandle: tiktokHandle ?? this.tiktokHandle,
      xHandle: xHandle ?? this.xHandle,
      youtubeChannel: youtubeChannel ?? this.youtubeChannel,
      imdbLink: imdbLink ?? this.imdbLink,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      galleryPhotoUrls: galleryPhotoUrls ?? this.galleryPhotoUrls,
      filmography: filmography ?? this.filmography,
      hobbies: hobbies ?? this.hobbies,
      introVideoUrl: introVideoUrl ?? this.introVideoUrl,
      showreelVideoUrl: showreelVideoUrl ?? this.showreelVideoUrl,
      performanceVideoUrl: performanceVideoUrl ?? this.performanceVideoUrl,
      expressionVideoUrl: expressionVideoUrl ?? this.expressionVideoUrl,
      lockedSections: lockedSections ?? this.lockedSections,
      isHidden: isHidden ?? this.isHidden,
      acceptedNdas: acceptedNdas ?? this.acceptedNdas,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      adminNote: adminNote ?? this.adminNote,
      bodyMeasurements: bodyMeasurements ?? this.bodyMeasurements,
      shoeSize: shoeSize ?? this.shoeSize,
      actingEducation: actingEducation ?? this.actingEducation,
      theaterExperience: theaterExperience ?? this.theaterExperience,
      seriesExperience: seriesExperience ?? this.seriesExperience,
      movieExperience: movieExperience ?? this.movieExperience,
      commercialExperience: commercialExperience ?? this.commercialExperience,
      languageLevels: languageLevels ?? this.languageLevels,
      accents: accents ?? this.accents,
      drivingLicense: drivingLicense ?? this.drivingLicense,
      cvPdfUrl: cvPdfUrl ?? this.cvPdfUrl,
      cvText: cvText ?? this.cvText,
      projectVideos: projectVideos ?? this.projectVideos,
    );
  }
}

/// Önerilen yetenek kategorileri ve örnekleri
class SkillSuggestions {
  SkillSuggestions._();

  static const Map<String, List<String>> categories = {
    'Diller': [
      'İngilizce', 'Almanca', 'Fransızca', 'İspanyolca', 'İtalyanca',
      'Rusça', 'Arapça', 'Japonca', 'Korece', 'Çince',
    ],
    'Müzik': [
      'Şarkı Söyleme', 'Gitar', 'Piyano', 'Keman', 'Bateri',
      'Ney', 'Bağlama', 'Ud', 'Flüt', 'Saksafon',
    ],
    'Dans': [
      'Modern Dans', 'Bale', 'Hip-Hop', 'Salsa', 'Tango',
      'Zeybek', 'Halk Dansları', 'Breakdance', 'Jazz',
    ],
    'Spor': [
      'Yüzme', 'At Binme', 'Eskrim', 'Boks', 'Dövüş Sanatları',
      'Jimnastik', 'Yoga', 'Bisiklet', 'Koşu', 'Dalış',
    ],
    'Sahne': [
      'Doğaçlama', 'Stand-up', 'Tiyatro', 'Pandomim', 'Seslendirme',
      'Sunuculuk', 'Radyo', 'Dubbing',
    ],
    'Diğer': [
      'Araba Kullanma', 'Motor Kullanma', 'Ata Binme', 'Paten',
      'Kayak', 'Paraşüt', 'Tırmanma', 'Fotoğrafçılık',
      'Makyaj', 'Aşçılık', 'İlk Yardım',
    ],
  };

  /// Tüm yeteneklerin düz listesi
  static List<String> get allSkills {
    return categories.values.expand((list) => list).toList();
  }
}
