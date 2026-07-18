import 'package:cloud_firestore/cloud_firestore.dart';

// Castelle - Audition Model
// Oyuncu audition (deneme çekimi) gönderimi

/// Audition durumu
enum AuditionStatus {
  uploading('uploading', 'Yükleniyor'),
  submitted('submitted', 'İşlem Bekliyor'),
  reviewing('reviewing', 'İnceleniyor'),
  options('options', 'Opsiyonlu'),
  approved('approved', 'Onaylandı'),
  rejected('rejected', 'Reddedildi'),
  revision('revision', 'Revizyon İstendi');

  const AuditionStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static AuditionStatus fromString(String value) {
    return AuditionStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => AuditionStatus.submitted,
    );
  }
}

/// Audition Modeli
class AuditionModel {
  final String id;
  final String actorId;          // Gönderen oyuncu uid
  final String actorName;        // Oyuncu adı
  final String projectId;        // İlgili proje
  final String projectTitle;     // Proje adı
  final String roleName;         // Başvurulan rol adı
  final String videoUrl;         // Firebase Storage video URL
  final String? thumbnailUrl;    // Video küçük resim URL
  final String? note;            // Oyuncunun ek notu
  final int? videoDurationSec;   // Video süresi (saniye)
  final int? videoSizeBytes;     // Sıkıştırılmış boyut
  final int? originalSizeBytes;  // Orijinal boyut
  final AuditionStatus status;
  final String? reviewerNote;    // Yönetmen/Admin geri bildirimi
  final String? reviewerId;      // İnceleyen kişi uid
  final String? reviewerName;    // İnceleyen kişi adı
  final double? requestedBudget; // Oyuncunun talep ettiği bütçe
  final double? originalBudget;  // Proje/rolün orijinal bütçesi
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final DateTime? optionStartDate;
  final DateTime? optionEndDate;
  final List<String>? optionQuestions;
  final Map<String, String>? optionAnswers;
  final bool? optionAvailable;
  final String? optionExplanation;

  const AuditionModel({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.projectId,
    required this.projectTitle,
    required this.roleName,
    required this.videoUrl,
    this.thumbnailUrl,
    this.note,
    this.videoDurationSec,
    this.videoSizeBytes,
    this.originalSizeBytes,
    this.status = AuditionStatus.submitted,
    this.reviewerNote,
    this.reviewerId,
    this.reviewerName,
    this.requestedBudget,
    this.originalBudget,
    required this.createdAt,
    this.reviewedAt,
    this.optionStartDate,
    this.optionEndDate,
    this.optionQuestions,
    this.optionAnswers,
    this.optionAvailable,
    this.optionExplanation,
  });

  factory AuditionModel.fromMap(Map<String, dynamic> map, String id) {
    return AuditionModel(
      id: id,
      actorId: map['actorId'] ?? '',
      actorName: map['actorName'] ?? '',
      projectId: map['projectId'] ?? '',
      projectTitle: map['projectTitle'] ?? '',
      roleName: map['roleName'] ?? '',
      videoUrl: map['videoUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'],
      note: map['note'],
      videoDurationSec: map['videoDurationSec'],
      videoSizeBytes: map['videoSizeBytes'],
      originalSizeBytes: map['originalSizeBytes'],
      status: AuditionStatus.fromString(map['status'] ?? 'submitted'),
      reviewerNote: map['reviewerNote'],
      reviewerId: map['reviewerId'],
      reviewerName: map['reviewerName'],
      requestedBudget: map['requestedBudget'] != null ? (map['requestedBudget'] as num).toDouble() : null,
      originalBudget: map['originalBudget'] != null ? (map['originalBudget'] as num).toDouble() : null,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (map['reviewedAt'] as Timestamp?)?.toDate(),
      optionStartDate: (map['optionStartDate'] as Timestamp?)?.toDate(),
      optionEndDate: (map['optionEndDate'] as Timestamp?)?.toDate(),
      optionQuestions: (map['optionQuestions'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      optionAnswers: map['optionAnswers'] != null ? Map<String, String>.from(map['optionAnswers']) : null,
      optionAvailable: map['optionAvailable'] as bool?,
      optionExplanation: map['optionExplanation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'projectId': projectId,
      'projectTitle': projectTitle,
      'roleName': roleName,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'note': note,
      'videoDurationSec': videoDurationSec,
      'videoSizeBytes': videoSizeBytes,
      'originalSizeBytes': originalSizeBytes,
      'status': status.value,
      'reviewerNote': reviewerNote,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'requestedBudget': requestedBudget,
      'originalBudget': originalBudget,
      'createdAt': Timestamp.fromDate(createdAt),
      'reviewedAt':
          reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'optionStartDate': optionStartDate != null ? Timestamp.fromDate(optionStartDate!) : null,
      'optionEndDate': optionEndDate != null ? Timestamp.fromDate(optionEndDate!) : null,
      'optionQuestions': optionQuestions,
      'optionAnswers': optionAnswers,
      'optionAvailable': optionAvailable,
      'optionExplanation': optionExplanation,
    };
  }

  /// Sıkıştırma oranı
  double get compressionRatio {
    if (originalSizeBytes == null || videoSizeBytes == null) return 0;
    if (originalSizeBytes == 0) return 0;
    return 1 - (videoSizeBytes! / originalSizeBytes!);
  }

  /// Okunabilir video boyutu
  String get formattedSize {
    if (videoSizeBytes == null) return '—';
    if (videoSizeBytes! > 1024 * 1024) {
      return '${(videoSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(videoSizeBytes! / 1024).toStringAsFixed(0)} KB';
  }

  /// Okunabilir süre
  String get formattedDuration {
    if (videoDurationSec == null) return '—';
    final minutes = videoDurationSec! ~/ 60;
    final seconds = videoDurationSec! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Bütçe değişti mi?
  bool get isBudgetChanged {
    if (requestedBudget == null) return false;
    // Eğer orijinal bütçe belirtilmemişse ama oyuncu bir bütçe talep etmişse bu da bütçenin değiştiğini (belirlendiğini) gösterir
    if (originalBudget == null) return true;
    return (requestedBudget! - originalBudget!).abs() > 0.01;
  }

  AuditionModel copyWith({
    String? id,
    AuditionStatus? status,
    String? reviewerNote,
    String? reviewerId,
    String? reviewerName,
    double? requestedBudget,
    double? originalBudget,
    DateTime? reviewedAt,
    DateTime? optionStartDate,
    DateTime? optionEndDate,
    List<String>? optionQuestions,
    Map<String, String>? optionAnswers,
    bool? optionAvailable,
    String? optionExplanation,
  }) {
    return AuditionModel(
      id: id ?? this.id,
      actorId: actorId,
      actorName: actorName,
      projectId: projectId,
      projectTitle: projectTitle,
      roleName: roleName,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      note: note,
      videoDurationSec: videoDurationSec,
      videoSizeBytes: videoSizeBytes,
      originalSizeBytes: originalSizeBytes,
      status: status ?? this.status,
      reviewerNote: reviewerNote ?? this.reviewerNote,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      requestedBudget: requestedBudget ?? this.requestedBudget,
      originalBudget: originalBudget ?? this.originalBudget,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      optionStartDate: optionStartDate ?? this.optionStartDate,
      optionEndDate: optionEndDate ?? this.optionEndDate,
      optionQuestions: optionQuestions ?? this.optionQuestions,
      optionAnswers: optionAnswers ?? this.optionAnswers,
      optionAvailable: optionAvailable ?? this.optionAvailable,
      optionExplanation: optionExplanation ?? this.optionExplanation,
    );
  }
}
