import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/services/audition_service.dart';

// Castelle - Audition Provider
// Video kopyalama + yükleme + audition durum yönetimi
// NOT: VideoCompress güvenli fallback ile geri eklendi.
// Emülatörde veya hata durumunda otomatik olarak orijinal dosyaya döner.

class AuditionProvider extends ChangeNotifier {
  final AuditionService _service = AuditionService();

  List<AuditionModel> _auditions = [];
  bool _isLoading = false;
  bool _isCompressing = false; 
  bool _isUploading = false;
  double _compressProgress = 0;
  double _uploadProgress = 0;
  String? _errorMessage;

  // Getters
  List<AuditionModel> get auditions => _auditions;
  bool get isLoading => _isLoading;
  bool get isCompressing => _isCompressing;
  bool get isUploading => _isUploading;
  double get compressProgress => _compressProgress;
  double get uploadProgress => _uploadProgress;
  String? get errorMessage => _errorMessage;
  bool get isProcessing => _isCompressing || _isUploading;

  /// Video sıkıştır, kalıcı dizine kaydet ve oluştur
  Future<bool> submitAudition({
    required File videoFile,
    required String actorId,
    required String actorName,
    required String projectId,
    required String projectTitle,
    required String roleName,
    String? note,
    double? requestedBudget,
    double? originalBudget,
  }) async {
    _errorMessage = null;
    final originalSize = await videoFile.length();

    // ADIM 1: SIKIŞTIRMA (Veya hata durumunda doğrudan kopyalama)
    _isCompressing = true;
    _compressProgress = 0;
    notifyListeners();

    File persistentFile;
    final fileName =
        '${actorId}_${projectId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/audition_videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }
      final destPath = '${videosDir.path}/$fileName';

      File? compressedFile;

      try {
        debugPrint('🎬 [Video Sıkıştırma] Başlıyor: ${videoFile.path}');
        
        // Gerçek sıkıştırma ilerlemesini dinle
        final subscription = VideoCompress.compressProgress$.subscribe((progress) {
          _compressProgress = (progress / 100).clamp(0.0, 1.0);
          notifyListeners();
        });

        // Sıkıştırmayı başlat
        final mediaInfo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.DefaultQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        subscription.unsubscribe();

        if (mediaInfo != null && mediaInfo.file != null) {
          final tempFile = mediaInfo.file!;
          final length = await tempFile.length();
          if (length > 0) {
            compressedFile = tempFile;
            debugPrint('✅ [Video Sıkıştırıldı]: ${compressedFile.path} (${(length / 1024 / 1024).toStringAsFixed(2)} MB)');
          }
        }
      } catch (compressError) {
        debugPrint('⚠️ [Video Sıkıştırma Hatası - Fallback uygulanıyor]: $compressError');
        try {
          await VideoCompress.cancelCompression();
        } catch (_) {}
      }

      if (compressedFile != null) {
        // Sıkıştırılmış videoyu kalıcı konuma kopyala
        persistentFile = await compressedFile.copy(destPath);
        debugPrint('💾 [Sıkıştırılmış Video Kaydedildi]: ${persistentFile.path}');
      } else {
        debugPrint('📂 [Sıkıştırma Başarısız/Atlandı] Orijinal dosya kopyalanıyor...');
        // Simüle edilmiş kopyalama ilerlemesi gösterelim (fallback durumunda hızlıca doldurur)
        for (double p = 0.2; p <= 1.0; p += 0.2) {
          _compressProgress = p;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 50));
        }
        persistentFile = await videoFile.copy(destPath);
        debugPrint('💾 [Orijinal Video Kaydedildi (Fallback)]: ${persistentFile.path}');
      }

      // Sıkıştırma cache temizle
      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}

      _compressProgress = 1.0;
      _isCompressing = false;
      notifyListeners();
    } catch (e) {
      _isCompressing = false;
      _errorMessage = 'Video hazırlama hatası: $e';
      notifyListeners();
      return false;
    }

    // ADIM 2: FIREBASE STORAGE'A YÜKLE
    _isUploading = true;
    _uploadProgress = 0;
    notifyListeners();

    try {
      final videoUrl = await _service.uploadVideo(
        videoFile: persistentFile,
        actorId: actorId,
        projectId: projectId,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      _isUploading = false;
      notifyListeners();

      // ADIM 3: FIRESTORE'A KAYDET
      final fileSize = await persistentFile.length();

      // Video süresini al – video_player ile (güvenilir)
      int durationSec = 0;
      try {
        final ctrl = VideoPlayerController.file(persistentFile);
        await ctrl.initialize();
        durationSec = ctrl.value.duration.inSeconds;
        await ctrl.dispose();
        debugPrint('🎞️ [Video Süresi]: ${durationSec}s');
      } catch (e) {
        debugPrint('⚠️ [Video Süresi Alınamadı]: $e');
      }

      // Firebase URL ise onu kullan, değilse kalıcı dosya yolunu kullan
      final finalVideoUrl = videoUrl.startsWith('http')
          ? videoUrl
          : persistentFile.path;

      debugPrint('📝 [Audition Kaydediliyor] videoUrl: $finalVideoUrl');

      final audition = AuditionModel(
        id: '',
        actorId: actorId,
        actorName: actorName,
        projectId: projectId,
        projectTitle: projectTitle,
        roleName: roleName,
        videoUrl: finalVideoUrl,
        note: note,
        videoDurationSec: durationSec,
        videoSizeBytes: fileSize,
        originalSizeBytes: originalSize,
        status: AuditionStatus.submitted,
        requestedBudget: requestedBudget,
        originalBudget: originalBudget,
        createdAt: DateTime.now(),
      );

      await _service.createAudition(audition);

      notifyListeners();
      return true;
    } catch (e) {
      _isUploading = false;
      _errorMessage = 'Yükleme hatası: $e';
      notifyListeners();
      return false;
    }
  }

  /// Oyuncunun audition'larını yükle
  Future<void> loadActorAuditions(String actorId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _auditions = await _service.getActorAuditions(actorId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Projenin audition'larını yükle
  Future<void> loadProjectAuditions(String projectId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _auditions = await _service.getProjectAuditions(projectId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Tüm audition'ları yükle (Admin/Yönetmen/Moderatör)
  /// [projectIds] verilirse sadece o projelere ait auditionlar gelir (moderatör filtresi)
  Future<void> loadAllAuditions({AuditionStatus? status, List<String>? projectIds}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _auditions = await _service.getAllAuditions(
        status: status,
        projectIds: projectIds,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Audition incele (Yönetmen/Admin)
  Future<bool> reviewAudition({
    required String auditionId,
    required AuditionStatus status,
    String? reviewerNote,
    String? reviewerId,
    String? reviewerName,
  }) async {
    try {
      await _service.reviewAudition(
        auditionId: auditionId,
        status: status,
        reviewerNote: reviewerNote,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
      );

      final index = _auditions.indexWhere((a) => a.id == auditionId);
      if (index != -1) {
        _auditions[index] = _auditions[index].copyWith(
          status: status,
          reviewerNote: reviewerNote,
          reviewerId: reviewerId,
          reviewerName: reviewerName,
          reviewedAt: DateTime.now(),
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// İşlemi iptal et
  void cancelProcessing() {
    _isCompressing = false;
    _isUploading = false;
    _compressProgress = 0;
    _uploadProgress = 0;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Audition listesini temizle (moderatör proje atanmadığında)
  void clearAuditions() {
    _auditions = [];
    _isLoading = false;
    notifyListeners();
  }

  /// Audition'a opsiyon talebi gönder (Yönetmen/Admin)
  Future<bool> sendOptionRequest({
    required String auditionId,
    required DateTime startDate,
    required DateTime endDate,
    required List<String> questions,
    String? reviewerId,
    String? reviewerName,
  }) async {
    try {
      await _service.sendOptionRequest(
        auditionId: auditionId,
        startDate: startDate,
        endDate: endDate,
        questions: questions,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
      );

      final index = _auditions.indexWhere((a) => a.id == auditionId);
      if (index != -1) {
        _auditions[index] = _auditions[index].copyWith(
          status: AuditionStatus.options,
          optionStartDate: startDate,
          optionEndDate: endDate,
          optionQuestions: questions,
          optionAnswers: null,
          optionAvailable: null,
          optionExplanation: null,
          reviewerId: reviewerId,
          reviewerName: reviewerName,
          reviewedAt: DateTime.now(),
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Oyuncu opsiyon talebini yanıtlar
  Future<bool> submitOptionResponse({
    required String auditionId,
    required bool available,
    String? explanation,
    required Map<String, String> answers,
  }) async {
    try {
      await _service.submitOptionResponse(
        auditionId: auditionId,
        available: available,
        explanation: explanation,
        answers: answers,
      );

      final index = _auditions.indexWhere((a) => a.id == auditionId);
      if (index != -1) {
        _auditions[index] = _auditions[index].copyWith(
          optionAvailable: available,
          optionExplanation: explanation,
          optionAnswers: answers,
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
