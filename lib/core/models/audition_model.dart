import 'package:cloud_firestore/cloud_firestore.dart';

// Castelle - Audition Model
// Oyuncu audition (deneme çekimi) gönderimi

/// Audition durumu
///
/// Başvurular ekranında (oyuncu ve panel) yalnızca 5 durum gösterilir:
/// Gönderildi · Opsiyon · Onaylandı · Reddedildi · Revizyon.
/// `uploading` ve `reviewing` teknik ara durumlardır ve kullanıcıya
/// "Gönderildi" olarak yansıtılır.
enum AuditionStatus {
  uploading('uploading', 'Gönderildi'),
  submitted('submitted', 'Gönderildi'),
  reviewing('reviewing', 'Gönderildi'),
  options('options', 'Opsiyon'),
  approved('approved', 'Onaylandı'),
  rejected('rejected', 'Reddedildi'),
  revision('revision', 'Revizyon');

  const AuditionStatus(this.value, this.displayName);
  final String value;
  final String displayName;

  static AuditionStatus fromString(String value) {
    return AuditionStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => AuditionStatus.submitted,
    );
  }

  /// Kullanıcıya gösterilen 5 ana durumdan hangisine karşılık geldiği.
  AuditionStatus get displayGroup => switch (this) {
        AuditionStatus.uploading ||
        AuditionStatus.submitted ||
        AuditionStatus.reviewing =>
          AuditionStatus.submitted,
        _ => this,
      };

  /// Gösterilen 5 durum (sekme sırası).
  static const List<AuditionStatus> visibleStatuses = [
    AuditionStatus.submitted,
    AuditionStatus.options,
    AuditionStatus.approved,
    AuditionStatus.rejected,
    AuditionStatus.revision,
  ];

  /// Bir sekmeye (5 ana durumdan biri) düşen gerçek durum değerleri.
  static List<AuditionStatus> membersOf(AuditionStatus group) =>
      AuditionStatus.values.where((s) => s.displayGroup == group).toList();
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

  // ── Yedekleme / geçmiş alanları ──
  /// Panelden silindi mi? (Kalıcı silme yok — "Silinenler"den geri alınabilir.
  /// Oyuncunun kendi geçmişinde kayıt görünmeye devam eder.)
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedByName;
  /// Proje silindiğinde işaretlenir; başvuru kaydı geçmiş için korunur.
  final bool projectDeleted;
  /// Durum değişiklik tarihçesi: [{status, at(Timestamp), by, note}]
  final List<Map<String, dynamic>> statusHistory;
  /// Revize sonrası değiştirilen eski videolar: [{videoUrl, uploadedAt, reviewerNote}]
  final List<Map<String, dynamic>> previousVersions;
  final int revisionCount;
  final DateTime? resubmittedAt;
  /// Oyuncunun çekim sırasında kullandığı senaryo/prompter metni
  final String? scriptUsed;

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
    this.isDeleted = false,
    this.deletedAt,
    this.deletedByName,
    this.projectDeleted = false,
    this.statusHistory = const [],
    this.previousVersions = const [],
    this.revisionCount = 0,
    this.resubmittedAt,
    this.scriptUsed,
  });

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  factory AuditionModel.fromMap(Map<String, dynamic> map, String id) {
    return AuditionModel(
      id: id,
      actorId: _str(map['actorId']),
      actorName: _str(map['actorName']),
      projectId: _str(map['projectId']),
      projectTitle: _str(map['projectTitle']),
      roleName: _str(map['roleName']),
      videoUrl: _str(map['videoUrl']),
      thumbnailUrl: _strOrNull(map['thumbnailUrl']),
      note: _strOrNull(map['note']),
      videoDurationSec: _int(map['videoDurationSec']),
      videoSizeBytes: _int(map['videoSizeBytes']),
      originalSizeBytes: _int(map['originalSizeBytes']),
      status: AuditionStatus.fromString(_strOrNull(map['status']) ?? 'submitted'),
      reviewerNote: _strOrNull(map['reviewerNote']),
      reviewerId: _strOrNull(map['reviewerId']),
      reviewerName: _strOrNull(map['reviewerName']),
      requestedBudget: _double(map['requestedBudget']),
      originalBudget: _double(map['originalBudget']),
      createdAt: _date(map['createdAt']) ?? DateTime.now(),
      reviewedAt: _date(map['reviewedAt']),
      optionStartDate: _date(map['optionStartDate']),
      optionEndDate: _date(map['optionEndDate']),
      optionQuestions: (map['optionQuestions'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      optionAnswers: map['optionAnswers'] is Map
          ? (map['optionAnswers'] as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))
          : null,
      optionAvailable: map['optionAvailable'] is bool ? map['optionAvailable'] as bool : null,
      optionExplanation: _strOrNull(map['optionExplanation']),
      isDeleted: map['isDeleted'] == true,
      deletedAt: _date(map['deletedAt']),
      deletedByName: _strOrNull(map['deletedByName']),
      projectDeleted: map['projectDeleted'] == true,
      statusHistory: _mapList(map['statusHistory']),
      previousVersions: _mapList(map['previousVersions']),
      revisionCount: (map['revisionCount'] is num) ? (map['revisionCount'] as num).toInt() : 0,
      resubmittedAt: _date(map['resubmittedAt']),
      scriptUsed: _strOrNull(map['scriptUsed']),
    );
  }

  // Firestore'dan gelen değerleri tipine güvenmeden çözümle. Web release
  // derlemesinde (dart2js -O4) örtük tip kontrolleri kalktığı için yanlış
  // tipte bir alan (ör. double süre, string tarih) modele sızıp render
  // sırasında gri ekrana yol açabiliyordu.
  static String _str(dynamic v) => v == null ? '' : v.toString();
  static String? _strOrNull(dynamic v) => v?.toString();
  static int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return num.tryParse(v)?.toInt();
    return null;
  }

  static double? _double(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static DateTime? _date(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v);
    return null;
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
      'isDeleted': isDeleted,
      'projectDeleted': projectDeleted,
      'statusHistory': statusHistory,
      'previousVersions': previousVersions,
      'revisionCount': revisionCount,
      'scriptUsed': scriptUsed,
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
    bool? isDeleted,
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
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt,
      deletedByName: deletedByName,
      projectDeleted: projectDeleted,
      statusHistory: statusHistory,
      previousVersions: previousVersions,
      revisionCount: revisionCount,
      resubmittedAt: resubmittedAt,
      scriptUsed: scriptUsed,
    );
  }
}
