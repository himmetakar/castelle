import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/services/actor_profile_service.dart';
import 'package:castelle/core/utils/media_upload.dart';

// Castelle - Actor Profile Provider
// Oyuncu profil durum yönetimi

class ActorProfileProvider extends ChangeNotifier {
  final ActorProfileService _service = ActorProfileService();

  ActorProfileModel? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  // Upload/Compression tracking
  bool _isCompressing = false;
  bool _isUploading = false;
  double _compressProgress = 0.0;
  double _uploadProgress = 0.0;

  // Getters
  ActorProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get completionPercentage => _profile?.completionPercentage ?? 0;
  bool get isProfileComplete => completionPercentage >= 70;

  bool get isCompressing => _isCompressing;
  bool get isUploading => _isUploading;
  double get compressProgress => _compressProgress;
  double get uploadProgress => _uploadProgress;
  bool get isProcessing => _isCompressing || _isUploading;

  /// Profili yükle
  /// Son yükleme başarısız oldu mu? (ağ/yetki hatası). true iken kayıt
  /// engellenir: boş/yarım profil sunucudaki gerçek profili ezmesin.
  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _service.getActorProfile(uid);
      if (res != null) {
        _profile = res;
      } else {
        // Belge gerçekten yok (ilk kez profil dolduruluyor) → boş iskelet
        _profile = ActorProfileModel(
          uid: uid,
          fullName: '',
          email: '',
          phone: '',
        );
      }
      _loadFailed = false;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // ESKİ HATA: burada boş bir profil oluşturuluyordu; kullanıcı "her şey
      // silinmiş" görüyor, kaydedince boş liste/alanlar sunucuya yazılıyordu.
      // Artık mevcut profil (varsa) korunur, kayıt engellenir.
      _isLoading = false;
      _loadFailed = true;
      _errorMessage =
          'Profiliniz sunucudan yüklenemedi. İnternet bağlantınızı kontrol edip sayfayı yenileyin.';
      debugPrint('❌ [loadProfile] $e');
      notifyListeners();
    }
  }

  /// Yükleme/upload öncesi profilin elde olduğundan emin ol. Profil henüz
  /// yüklenmemişse önce sunucudan OKUR; okunamazsa false döner (boş iskeletle
  /// kaydedip gerçek verinin üzerine yazmamak için).
  Future<bool> _ensureProfile(String? fallbackUid) async {
    if (_profile != null && !_loadFailed) return true;
    if (fallbackUid == null) return false;
    await loadProfile(fallbackUid);
    return _profile != null && !_loadFailed;
  }

  /// Profili kaydet
  Future<bool> saveProfile(ActorProfileModel profile) async {
    if (_loadFailed) {
      _errorMessage =
          'Profiliniz sunucudan yüklenemediği için kaydedilemedi. İnternet bağlantınızı kontrol edip sayfayı yenileyin.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.saveActorProfile(profile);
      _profile = profile;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // ESKİ HATA: permission-denied gelince "demo" diye yerelde kaydedilmiş
      // gibi gösterip true dönüyordu. Kullanıcı profili %70 dolu görüyor,
      // uygulamayı kapatıp açınca her şey sıfırlanıyordu; yüklenen foto/video
      // URL'leri de aynı yoldan kaybolyordu. Artık hata açıkça gösterilir.
      _isLoading = false;
      final raw = e.toString();
      final lower = raw.toLowerCase();
      if (lower.contains('permission-denied') || lower.contains('permission denied')) {
        _errorMessage =
            'Profil sunucuya kaydedilemedi (yetki hatası). Lütfen uygulamayı güncelleyip tekrar deneyin; sorun sürerse yöneticiye bildirin.';
      } else if (lower.contains('unavailable') || lower.contains('network') || lower.contains('socket')) {
        _errorMessage = 'İnternet bağlantısı yok ya da sunucuya ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.';
      } else {
        _errorMessage = raw.replaceAll('Exception: ', '');
      }
      debugPrint('❌ [saveProfile] $raw');
      notifyListeners();
      return false;
    }
  }

  /// Yetenek ekle
  Future<void> addSkill(String skill) async {
    if (_profile == null) return;
    if (_profile!.skills.contains(skill)) return;

    try {
      await _service.addSkill(_profile!.uid, skill);
      _profile = _profile!.copyWith(
        skills: [..._profile!.skills, skill],
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Yetenek sil
  Future<void> removeSkill(String skill) async {
    if (_profile == null) return;

    try {
      await _service.removeSkill(_profile!.uid, skill);
      _profile = _profile!.copyWith(
        skills: _profile!.skills.where((s) => s != skill).toList(),
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Hata temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Profil fotoğrafı yükle
  Future<bool> uploadProfilePhoto(XFile file, {String? fallbackUid}) async {
    if (!await _ensureProfile(fallbackUid)) {
      _errorMessage ??= 'Profil yüklenemedi, lütfen tekrar deneyin.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final downloadUrl = await _service.uploadProfileMedia(
        file: file,
        uid: _profile!.uid,
        type: 'photo',
        key: 'profile_photo',
      );
      final updatedProfile = _profile!.copyWith(profilePhotoUrl: downloadUrl);
      return await saveProfile(updatedProfile);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Portfolyo galerisine fotoğraf yükle
  Future<bool> uploadGalleryPhoto(XFile file, int index, {String? fallbackUid}) async {
    if (!await _ensureProfile(fallbackUid)) {
      _errorMessage ??= 'Profil yüklenemedi, lütfen tekrar deneyin.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final downloadUrl = await _service.uploadProfileMedia(
        file: file,
        uid: _profile!.uid,
        type: 'photo',
        key: 'gallery_$index',
      );
      final currentGallery = List<String>.from(_profile!.galleryPhotoUrls);
      if (index < currentGallery.length) {
        currentGallery[index] = downloadUrl;
      } else {
        currentGallery.add(downloadUrl);
      }
      final updatedProfile = _profile!.copyWith(galleryPhotoUrls: currentGallery);
      return await saveProfile(updatedProfile);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Portfolyo galerisine birden fazla fotoğraf yükle
  Future<bool> uploadMultipleGalleryPhotos(List<XFile> files, {String? fallbackUid}) async {
    if (!await _ensureProfile(fallbackUid)) {
      _errorMessage ??= 'Profil yüklenemedi, lütfen tekrar deneyin.';
      notifyListeners();
      return false;
    }

    if (files.isEmpty) return true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentGallery = List<String>.from(_profile!.galleryPhotoUrls);
      
      // Limit 10 photos total
      final availableSlots = 10 - currentGallery.length;
      if (availableSlots <= 0) {
        _isLoading = false;
        _errorMessage = 'Maksimum fotoğraf limitine (10) ulaşıldı.';
        notifyListeners();
        return false;
      }

      final filesToUpload = files.take(availableSlots).toList();

      for (int i = 0; i < filesToUpload.length; i++) {
        final file = filesToUpload[i];
        final index = currentGallery.length;
        final downloadUrl = await _service.uploadProfileMedia(
          file: file,
          uid: _profile!.uid,
          type: 'photo',
          key: 'gallery_$index',
        );
        currentGallery.add(downloadUrl);
      }

      final updatedProfile = _profile!.copyWith(galleryPhotoUrls: currentGallery);
      return await saveProfile(updatedProfile);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Portfolyo galerisinden fotoğraf sil
  Future<bool> deleteGalleryPhoto(int index) async {
    if (_profile == null) return false;
    final currentGallery = List<String>.from(_profile!.galleryPhotoUrls);
    if (index >= 0 && index < currentGallery.length) {
      currentGallery.removeAt(index);
      final updatedProfile = _profile!.copyWith(galleryPhotoUrls: currentGallery);
      return await saveProfile(updatedProfile);
    }
    return false;
  }

  /// Profil videosu (Tanıtım, Showreel, Performans, Mimik) sıkıştır ve yükle
  Future<bool> uploadAndCompressProfileVideo(XFile videoFile, String videoKey, {String? fallbackUid}) async {
    if (!await _ensureProfile(fallbackUid)) {
      _errorMessage ??= 'Profil yüklenemedi, lütfen tekrar deneyin.';
      notifyListeners();
      return false;
    }
    _errorMessage = null;

     // Video süre kontrolü (Showreel: 4dk, Performans: 2dk, Tanıtım: 30s, Mimik: Limitsiz/50s)
     int durationSec = 0;
     try {
       final ctrl = MediaUpload.videoController(videoFile.path);
       await ctrl.initialize();
       durationSec = ctrl.value.duration.inSeconds;
       await ctrl.dispose();
       debugPrint('🎞️ [Profil Videosu Süresi]: ${durationSec}s');
       
       int maxAllowedSec = 22; // Varsayılan toleranslı limit
       String limitMsg = '20 saniye';
       
       if (videoKey == 'introVideo') {
         maxAllowedSec = 35;
         limitMsg = '30 saniye';
       } else if (videoKey == 'showreelVideo' || videoKey == 'showreel') {
         maxAllowedSec = 250;
         limitMsg = '4 dakika';
       } else if (videoKey == 'performanceVideo') {
         maxAllowedSec = 130;
         limitMsg = '2 dakika';
       } else if (videoKey == 'expressionVideo' || videoKey == 'expression') {
         maxAllowedSec = 60;
         limitMsg = '50 saniye';
       }
       
       if (durationSec > maxAllowedSec) {
         _errorMessage = 'Yüklemek istediğiniz video $limitMsg limitini aşamaz (Mevcut: ${durationSec}s).';
         notifyListeners();
         return false;
       }
    } catch (e) {
      debugPrint('⚠️ [Video Süresi Alınamadı]: $e');
    }

    _isCompressing = true;
    _compressProgress = 0.0;
    notifyListeners();

    XFile persistentFile;
    final fileName = '${_profile!.uid}_${videoKey}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      if (kIsWeb) {
        // Web'de sıkıştırma (video_compress) ve yerel klasör (path_provider)
        // yok — video olduğu gibi yüklenir.
        persistentFile = videoFile;
      } else {
      final appDir = await getApplicationDocumentsDirectory();
      final videosDir = Directory('${appDir.path}/profile_videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }
      final destPath = '${videosDir.path}/$fileName';

      File? compressedFile;

      try {
        debugPrint('🎬 [Profile Video Sıkıştırma] Başlıyor: ${videoFile.path}');
        
        final subscription = VideoCompress.compressProgress$.subscribe((progress) {
          _compressProgress = (progress / 100).clamp(0.0, 1.0);
          notifyListeners();
        });

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
            debugPrint('✅ [Profile Video Sıkıştırıldı]: ${compressedFile.path}');
          }
        }
      } catch (compressError) {
        debugPrint('⚠️ [Profile Video Sıkıştırma Hatası]: $compressError');
        try {
          await VideoCompress.cancelCompression();
        } catch (_) {}
      }

      if (compressedFile != null) {
        persistentFile = XFile((await compressedFile.copy(destPath)).path);
      } else {
        for (double p = 0.2; p <= 1.0; p += 0.2) {
          _compressProgress = p;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 50));
        }
        persistentFile = XFile((await File(videoFile.path).copy(destPath)).path);
      }

      try {
        await VideoCompress.deleteAllCache();
      } catch (_) {}
      }

      _compressProgress = 1.0;
      _isCompressing = false;
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      final downloadUrl = await _service.uploadProfileMedia(
        file: persistentFile,
        uid: _profile!.uid,
        type: 'video',
        key: videoKey,
        onProgress: (progress) {
          _uploadProgress = progress;
          notifyListeners();
        },
      );

      _isUploading = false;
      notifyListeners();

      ActorProfileModel updatedProfile;
      if (videoKey == 'introVideo') {
        updatedProfile = _profile!.copyWith(introVideoUrl: downloadUrl);
      } else if (videoKey == 'showreelVideo' || videoKey == 'showreel') {
        updatedProfile = _profile!.copyWith(showreelVideoUrl: downloadUrl);
      } else if (videoKey == 'performanceVideo') {
        updatedProfile = _profile!.copyWith(performanceVideoUrl: downloadUrl);
      } else if (videoKey == 'expressionVideo') {
        updatedProfile = _profile!.copyWith(expressionVideoUrl: downloadUrl);
      } else {
        return false;
      }

      return await saveProfile(updatedProfile);
    } catch (e) {
      _isCompressing = false;
      _isUploading = false;
      _errorMessage = 'İşlem hatası: $e';
      notifyListeners();
      return false;
    }
  }

  /// Profil videosunu sil (Tanıtım, Showreel, Performans, Mimik)
  Future<bool> deleteProfileVideo(String videoKey) async {
    if (_profile == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      ActorProfileModel updatedProfile;
      if (videoKey == 'introVideo') {
        updatedProfile = _profile!.copyWith(introVideoUrl: '');
      } else if (videoKey == 'showreelVideo' || videoKey == 'showreel') {
        updatedProfile = _profile!.copyWith(showreelVideoUrl: '');
      } else if (videoKey == 'performanceVideo') {
        updatedProfile = _profile!.copyWith(performanceVideoUrl: '');
      } else if (videoKey == 'expressionVideo') {
        updatedProfile = _profile!.copyWith(expressionVideoUrl: '');
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      return await saveProfile(updatedProfile);
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Silme hatası: $e';
      notifyListeners();
      return false;
    }
  }

  /// Bölüm kilit durumunu değiştir
  Future<bool> toggleSectionLock(String sectionKey) async {
    if (_profile == null) return false;
    final currentLocks = Map<String, bool>.from(_profile!.lockedSections);
    final currentVal = currentLocks[sectionKey] ?? false;
    currentLocks[sectionKey] = !currentVal;
    final updatedProfile = _profile!.copyWith(lockedSections: currentLocks);
    return await saveProfile(updatedProfile);
  }

  /// Profili gizle/göster durumunu değiştir
  Future<bool> toggleProfileVisibility(bool isHidden) async {
    if (_profile == null) return false;
    final updatedProfile = _profile!.copyWith(isHidden: isHidden);
    return await saveProfile(updatedProfile);
  }

  /// Gizlilik Taahhütnamesini (NDA) kabul et
  Future<bool> acceptNda(String projectId) async {
    if (_profile == null) return false;
    if (_profile!.acceptedNdas.contains(projectId)) return true;
    final currentNdas = [..._profile!.acceptedNdas, projectId];
    final updatedProfile = _profile!.copyWith(acceptedNdas: currentNdas);
    return await saveProfile(updatedProfile);
  }

  /// Rol aldığı iş ekle (filmografi)
  Future<bool> addFilmographyItem(Map<String, dynamic> item) async {
    if (_profile == null) return false;
    final list = List<Map<String, dynamic>>.from(_profile!.filmography);
    list.add(item);
    list.sort((a, b) {
      final yA = int.tryParse(a['year']?.toString() ?? '0') ?? 0;
      final yB = int.tryParse(b['year']?.toString() ?? '0') ?? 0;
      return yB.compareTo(yA); // En yeni yıl en üstte
    });
    final updatedProfile = _profile!.copyWith(filmography: list);
    return await saveProfile(updatedProfile);
  }

  /// Rol aldığı işi çıkar (filmografi)
  Future<bool> removeFilmographyItem(int index) async {
    if (_profile == null) return false;
    final list = List<Map<String, dynamic>>.from(_profile!.filmography);
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      final updatedProfile = _profile!.copyWith(filmography: list);
      return await saveProfile(updatedProfile);
    }
    return false;
  }
}
