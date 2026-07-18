import 'package:castelle/core/models/actor_profile_model.dart';

// Castelle - Actor Filter Model
// Admin ve Moderatör için oyuncu filtreleme kriterleri

class ActorFilterModel {
  final String? searchQuery;       // İsim / e-posta arama
  final int? minAge;
  final int? maxAge;
  final Gender? gender;
  final int? minHeight;
  final int? maxHeight;
  final int? minWeight;
  final int? maxWeight;
  final EyeColor? eyeColor;
  final HairColor? hairColor;
  final String? city;
  final String? experienceLevel;
  final List<String> skills;       // Seçili yetenekler (AND mantığı)
  final bool onlyComplete;         // Sadece profili tamamlanmış

  const ActorFilterModel({
    this.searchQuery,
    this.minAge,
    this.maxAge,
    this.gender,
    this.minHeight,
    this.maxHeight,
    this.minWeight,
    this.maxWeight,
    this.eyeColor,
    this.hairColor,
    this.city,
    this.experienceLevel,
    this.skills = const [],
    this.onlyComplete = false,
  });

  /// Filtre aktif mi?
  bool get hasActiveFilters {
    return searchQuery != null && searchQuery!.isNotEmpty ||
        minAge != null ||
        maxAge != null ||
        gender != null ||
        minHeight != null ||
        maxHeight != null ||
        minWeight != null ||
        maxWeight != null ||
        eyeColor != null ||
        hairColor != null ||
        city != null && city!.isNotEmpty ||
        experienceLevel != null ||
        skills.isNotEmpty ||
        onlyComplete;
  }

  /// Aktif filtre sayısı
  int get activeFilterCount {
    int count = 0;
    if (searchQuery != null && searchQuery!.isNotEmpty) count++;
    if (minAge != null || maxAge != null) count++;
    if (gender != null) count++;
    if (minHeight != null || maxHeight != null) count++;
    if (minWeight != null || maxWeight != null) count++;
    if (eyeColor != null) count++;
    if (hairColor != null) count++;
    if (city != null && city!.isNotEmpty) count++;
    if (experienceLevel != null) count++;
    if (skills.isNotEmpty) count++;
    if (onlyComplete) count++;
    return count;
  }

  /// Tüm filtreleri temizle
  ActorFilterModel clear() {
    return const ActorFilterModel();
  }

  /// Kopya oluştur
  ActorFilterModel copyWith({
    String? searchQuery,
    int? minAge,
    int? maxAge,
    Gender? gender,
    int? minHeight,
    int? maxHeight,
    int? minWeight,
    int? maxWeight,
    EyeColor? eyeColor,
    HairColor? hairColor,
    String? city,
    String? experienceLevel,
    List<String>? skills,
    bool? onlyComplete,
    // Null yapabilmek için özel flagler
    bool clearSearchQuery = false,
    bool clearMinAge = false,
    bool clearMaxAge = false,
    bool clearGender = false,
    bool clearMinHeight = false,
    bool clearMaxHeight = false,
    bool clearMinWeight = false,
    bool clearMaxWeight = false,
    bool clearEyeColor = false,
    bool clearHairColor = false,
    bool clearCity = false,
    bool clearExperienceLevel = false,
  }) {
    return ActorFilterModel(
      searchQuery: clearSearchQuery ? null : (searchQuery ?? this.searchQuery),
      minAge: clearMinAge ? null : (minAge ?? this.minAge),
      maxAge: clearMaxAge ? null : (maxAge ?? this.maxAge),
      gender: clearGender ? null : (gender ?? this.gender),
      minHeight: clearMinHeight ? null : (minHeight ?? this.minHeight),
      maxHeight: clearMaxHeight ? null : (maxHeight ?? this.maxHeight),
      minWeight: clearMinWeight ? null : (minWeight ?? this.minWeight),
      maxWeight: clearMaxWeight ? null : (maxWeight ?? this.maxWeight),
      eyeColor: clearEyeColor ? null : (eyeColor ?? this.eyeColor),
      hairColor: clearHairColor ? null : (hairColor ?? this.hairColor),
      city: clearCity ? null : (city ?? this.city),
      experienceLevel: clearExperienceLevel
          ? null
          : (experienceLevel ?? this.experienceLevel),
      skills: skills ?? this.skills,
      onlyComplete: onlyComplete ?? this.onlyComplete,
    );
  }

  /// Client-side filtreleme (Firestore'dan gelen sonuçlara ek filtre)
  bool matchesActor(ActorProfileModel actor) {
    // İsim / e-posta arama
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final q = searchQuery!.toLowerCase();
      if (!actor.fullName.toLowerCase().contains(q) &&
          !actor.email.toLowerCase().contains(q)) {
        return false;
      }
    }

    // Yaş
    if (minAge != null && (actor.age == null || actor.age! < minAge!)) {
      return false;
    }
    if (maxAge != null && (actor.age == null || actor.age! > maxAge!)) {
      return false;
    }

    // Cinsiyet
    if (gender != null && actor.gender != gender) return false;

    // Boy
    if (minHeight != null &&
        (actor.heightCm == null || actor.heightCm! < minHeight!)) {
      return false;
    }
    if (maxHeight != null &&
        (actor.heightCm == null || actor.heightCm! > maxHeight!)) {
      return false;
    }

    // Kilo
    if (minWeight != null &&
        (actor.weightKg == null || actor.weightKg! < minWeight!)) {
      return false;
    }
    if (maxWeight != null &&
        (actor.weightKg == null || actor.weightKg! > maxWeight!)) {
      return false;
    }

    // Göz rengi
    if (eyeColor != null && actor.eyeColor != eyeColor) return false;

    // Saç rengi
    if (hairColor != null && actor.hairColor != hairColor) return false;

    // Şehir
    if (city != null && city!.isNotEmpty) {
      if (actor.city == null ||
          !actor.city!.toLowerCase().contains(city!.toLowerCase())) {
        return false;
      }
    }

    // Deneyim
    if (experienceLevel != null &&
        actor.experienceLevel != experienceLevel) {
      return false;
    }

    // Yetenekler (AND mantığı)
    if (skills.isNotEmpty) {
      final actorSkillsLower =
          actor.skills.map((s) => s.toLowerCase()).toSet();
      for (final skill in skills) {
        if (!actorSkillsLower.contains(skill.toLowerCase())) {
          return false;
        }
      }
    }

    // Profil tamamlanma
    if (onlyComplete && !actor.isProfileComplete) return false;

    return true;
  }

  /// Zorunlu filtreler — skills HARİÇ (skills soft/bonus olarak sıralamada kullanılır)
  bool matchesActorHard(ActorProfileModel actor) {
    // İsim / e-posta arama
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final q = searchQuery!.toLowerCase();
      if (!actor.fullName.toLowerCase().contains(q) &&
          !actor.email.toLowerCase().contains(q)) {
        return false;
      }
    }

    // Yaş
    if (minAge != null && (actor.age == null || actor.age! < minAge!)) {
      return false;
    }
    if (maxAge != null && (actor.age == null || actor.age! > maxAge!)) {
      return false;
    }

    // Cinsiyet
    if (gender != null && actor.gender != gender) return false;

    // Boy
    if (minHeight != null &&
        (actor.heightCm == null || actor.heightCm! < minHeight!)) {
      return false;
    }
    if (maxHeight != null &&
        (actor.heightCm == null || actor.heightCm! > maxHeight!)) {
      return false;
    }

    // Kilo
    if (minWeight != null &&
        (actor.weightKg == null || actor.weightKg! < minWeight!)) {
      return false;
    }
    if (maxWeight != null &&
        (actor.weightKg == null || actor.weightKg! > maxWeight!)) {
      return false;
    }

    // Göz rengi
    if (eyeColor != null && actor.eyeColor != eyeColor) return false;

    // Saç rengi
    if (hairColor != null && actor.hairColor != hairColor) return false;

    // Şehir
    if (city != null && city!.isNotEmpty) {
      if (actor.city == null ||
          !actor.city!.toLowerCase().contains(city!.toLowerCase())) {
        return false;
      }
    }

    // Deneyim
    if (experienceLevel != null &&
        actor.experienceLevel != experienceLevel) {
      return false;
    }

    // Profil tamamlanma
    if (onlyComplete && !actor.isProfileComplete) return false;

    // Skills burada kontrol edilmez — sıralamada bonus olarak kullanılır

    return true;
  }
}
