import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/services/actor_profile_service.dart';
import 'package:castelle/core/services/audition_service.dart';
import 'package:castelle/features/actor/screens/actor_cv_view_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:castelle/core/services/pdf_service.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/services/project_service.dart';

/// Castelle - Audition İzleme ve İnceleme Ekranı
/// Değerlendirme ekranı - Yönlendirme, onay, ret işlevleri

class AuditionReviewScreen extends StatefulWidget {
  final AuditionModel audition;
  final String? adminNote;
  final String? attachedPhoto;
  final String? attachedFile;
  final String? forwardedBy;
  final bool? includeProfile;

  const AuditionReviewScreen({
    super.key,
    required this.audition,
    this.adminNote,
    this.attachedPhoto,
    this.attachedFile,
    this.forwardedBy,
    this.includeProfile,
  });

  @override
  State<AuditionReviewScreen> createState() => _AuditionReviewScreenState();
}

class _AuditionReviewScreenState extends State<AuditionReviewScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  final _noteController = TextEditingController();
  bool _isVideoLoading = true;
  ActorProfileModel? _actorProfile;
  bool _isLoadingProfile = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.audition.reviewerNote ?? '';
    _initVideo();
    _loadActorProfile();
  }

  Future<void> _loadActorProfile() async {
    setState(() => _isLoadingProfile = true);
    try {
      final profile = await ActorProfileService().getActorProfile(widget.audition.actorId);
      if (mounted) {
        setState(() {
          _actorProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading actor profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _initVideo() async {
    var videoUrl = widget.audition.videoUrl;
    debugPrint('🎬 [Video Init] Başlıyor. URL: "$videoUrl"');

    // Firebase Storage URL'sindeki slash karakterlerini %2F yapacak şekilde düzelt (eski kayıtlar için)
    if (videoUrl.startsWith('http') && videoUrl.contains('/o/')) {
      final oIndex = videoUrl.indexOf('/o/');
      final queryIndex = videoUrl.indexOf('?', oIndex);
      final baseUrl = videoUrl.substring(0, oIndex + 3);
      final queryParams = queryIndex != -1 ? videoUrl.substring(queryIndex) : '';
      final rawPath = queryIndex != -1 
          ? videoUrl.substring(oIndex + 3, queryIndex) 
          : videoUrl.substring(oIndex + 3);
      
      if (rawPath.contains('/') && !rawPath.contains('%2F')) {
        final encodedPath = Uri.encodeComponent(rawPath);
        videoUrl = '$baseUrl$encodedPath$queryParams';
        debugPrint('🔧 [Video URL Düzeltildi]: $videoUrl');
      }
    }

    if (videoUrl.isEmpty) {
      setState(() {
        _isVideoLoading = false;
        _videoError = 'Video URL bulunamadı. Audition kaydında video bilgisi eksik.';
      });
      return;
    }

    // Yerel dosya mı?
    final isLocalFile = videoUrl.startsWith('/')
        || videoUrl.startsWith('file://')
        || videoUrl.contains('/data/')
        || videoUrl.contains('/storage/');

    if (isLocalFile) {
      final cleanPath = videoUrl.replaceFirst(RegExp(r'^file://'), '');
      final file = File(cleanPath);
      final exists = await file.exists();
      debugPrint('📂 [Video] Yerel dosya: "$cleanPath" | Mevcut: $exists');

      if (!exists) {
        setState(() {
          _isVideoLoading = false;
          _videoError = 'Video dosyası cihazda bulunamadı.\n\nDosya adı: ${cleanPath.split('/').last}';
        });
        return;
      }

      final fileSize = await file.length();
      debugPrint('📏 [Video] Dosya boyutu: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Yöntem 1: VideoPlayerController.file()
      try {
        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
        debugPrint('✅ [Video] file() yöntemi başarılı.');
      } catch (e1) {
        debugPrint('⚠️ [Video] file() başarısız: $e1 → networkUrl(Uri.file()) deneniyor...');
        _videoController?.dispose();
        _videoController = null;

        // Yöntem 2: networkUrl ile file:// URI
        try {
          _videoController = VideoPlayerController.networkUrl(Uri.file(cleanPath));
          await _videoController!.initialize();
          debugPrint('✅ [Video] networkUrl(Uri.file()) yöntemi başarılı.');
        } catch (e2) {
          debugPrint('❌ [Video] Her iki yöntem de başarısız. Hata: $e2');
          _videoController?.dispose();
          _videoController = null;
          setState(() {
            _isVideoLoading = false;
            _videoError = 'Video oynatılamadı.\n\n'
                'Dosya: ${cleanPath.split('/').last}\n'
                'Boyut: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB\n'
                'Hata: $e2';
          });
          return;
        }
      }
    } else if (videoUrl.startsWith('http')) {
      debugPrint('🌐 [Video] Ağ URL\'si: $videoUrl');
      try {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await _videoController!.initialize();
        debugPrint('✅ [Video] Ağ video başarıyla yüklendi.');
      } catch (e) {
        debugPrint('❌ [Video] Ağ video hatası: $e');
        _videoController?.dispose();
        _videoController = null;
        setState(() {
          _isVideoLoading = false;
          _videoError = 'Video sunucudan yüklenemedi.\n\nHata: $e';
        });
        return;
      }
    } else {
      setState(() {
        _isVideoLoading = false;
        _videoError = 'Geçersiz video adresi:\n$videoUrl';
      });
      return;
    }

    // Controller başarıyla init edildi
    debugPrint('🎉 [Video] Hazır! '
        'Boyut: ${_videoController!.value.size}, '
        'Süre: ${_videoController!.value.duration.inSeconds}s, '
        'En-Boy: ${_videoController!.value.aspectRatio.toStringAsFixed(2)}');

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      aspectRatio: _videoController!.value.aspectRatio,
      allowFullScreen: true,
      placeholder: Container(
        color: AppTheme.surfaceLight,
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      ),
      materialProgressColors: ChewieProgressColors(
        playedColor: AppTheme.accent,
        handleColor: AppTheme.accent,
        backgroundColor: AppTheme.surfaceElevated,
        bufferedColor: AppTheme.primary.withValues(alpha: 0.3),
      ),
    );

    setState(() => _isVideoLoading = false);
  }


  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleReview(AuditionStatus status) async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;
    if (user.role == UserRole.moderator) {
      final isApprovedOrRejected = (status == AuditionStatus.approved || status == AuditionStatus.rejected);
      final isRevision = (status == AuditionStatus.revision);
      
      if (isApprovedOrRejected && !user.hasModeratorPermission('auditionOnaylama')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audition onaylama veya reddetme yetkiniz bulunmamaktadır.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      
      if (isRevision && !user.hasModeratorPermission('auditionRevizeIsteme')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audition revize isteme yetkiniz bulunmamaktadır.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
      
      final mode = user.moderatorPermissions?['approvalMode'] ?? 'neutral';
      if (mode == 'admin') {
        final success = await _submitModeratorApprovalRequest(
          actionType: status == AuditionStatus.approved 
              ? 'approve' 
              : (status == AuditionStatus.rejected ? 'reject' : 'revision'),
          auditionId: widget.audition.id,
          projectTitle: widget.audition.projectTitle,
          roleName: widget.audition.roleName,
          actorName: widget.audition.actorName,
          reviewerNote: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          moderatorId: user.uid,
          moderatorName: user.fullName,
        );
        
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('İşleminiz Admin onayına sunuldu.'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
    }
    final auditionProvider = context.read<AuditionProvider>();

    final success = await auditionProvider.reviewAudition(
      auditionId: widget.audition.id,
      status: status,
      reviewerNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      reviewerId: authProvider.user?.uid,
      reviewerName: authProvider.user?.fullName,
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Audition "${status.displayName}" olarak işaretlendi'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _downloadSingleAudition() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user?.role == UserRole.moderator) {
      if (!authProvider.user!.hasModeratorPermission('auditionIndirme')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audition indirme yetkiniz bulunmamaktadır.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }
    if (_actorProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oyuncu profil verileri henüz yüklenmedi, lütfen bekleyin...'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    // 1. Hedef Klasör Seçimi
    String? selectedDir;
    try {
      selectedDir = await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      debugPrint('Folder picker error: $e');
    }

    if (selectedDir == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İndirme iptal edildi. Klasör seçilmedi.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    debugPrint('📁 [Selected Directory] Path: $selectedDir');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seçilen dizin: $selectedDir'),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // 2. Depolama İzni İste
    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      } else {
        await Permission.storage.request();
      }
    }

    // 3. Klasör Oluştur: (Proje Adı) - (Oyuncu Adı)
    final rawFolderName = "${widget.audition.projectTitle} - ${widget.audition.actorName}";
    final cleanFolderName = rawFolderName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    final actorFolderPath = "$selectedDir/$cleanFolderName";

    final actorDir = Directory(actorFolderPath);
    if (!await actorDir.exists()) {
      await actorDir.create(recursive: true);
    }

    // 4. İndirme Diyaloğunu Göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        double percentage = 0.0;
        String progressText = 'Profil PDF oluşturuluyor...';
        bool downloadStarted = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Arka planda indirme işlemini tetikle (sadece ilk seferde)
            if (!downloadStarted) {
              downloadStarted = true;
              Future.microtask(() async {
                try {
                  // 1. PDF oluştur
                  final pdfPath = "$actorFolderPath/${widget.audition.actorName} - Profil.pdf";
                  await PdfService.generateProfilePdf(_actorProfile!, pdfPath);

                  if (widget.audition.videoUrl.isNotEmpty) {
                    setDialogState(() {
                      percentage = 0.3;
                      progressText = 'Video indiriliyor...';
                    });

                    String ext = 'mp4';
                    final lowerUrl = widget.audition.videoUrl.toLowerCase();
                    if (lowerUrl.contains('.mov') || lowerUrl.contains('.mov?')) {
                      ext = 'mov';
                    } else if (lowerUrl.contains('.m4v') || lowerUrl.contains('.m4v?')) {
                      ext = 'm4v';
                    }

                    final videoPath = "$actorFolderPath/${widget.audition.actorName} - Audition.$ext";
                    final isLocal = !widget.audition.videoUrl.startsWith('http://') && !widget.audition.videoUrl.startsWith('https://');

                    if (isLocal) {
                      String cleanLocalPath = widget.audition.videoUrl;
                      if (cleanLocalPath.startsWith('file://')) {
                        cleanLocalPath = Uri.parse(cleanLocalPath).toFilePath();
                      }
                      final sourceFile = File(cleanLocalPath);
                      if (await sourceFile.exists()) {
                        await sourceFile.copy(videoPath);
                        setDialogState(() {
                          percentage = 1.0;
                        });
                      } else {
                        throw Exception('Yerel video dosyasi bulunamadi: $cleanLocalPath');
                      }
                    } else {
                      await Dio().download(
                        widget.audition.videoUrl,
                        videoPath,
                        onReceiveProgress: (received, total) {
                          if (total != -1) {
                            final p = received / total;
                            setDialogState(() {
                              percentage = 0.3 + (p * 0.7);
                              progressText = 'Video indiriliyor: %${(p * 100).toStringAsFixed(0)}';
                            });
                          }
                        },
                      );
                    }
                  }

                  // 5. Oyuncunun Fotoğraflarını İndir
                  final photoUrls = <String>[];
                  if (_actorProfile!.profilePhotoUrl != null && _actorProfile!.profilePhotoUrl!.isNotEmpty) {
                    photoUrls.add(_actorProfile!.profilePhotoUrl!);
                  }
                  photoUrls.addAll(_actorProfile!.galleryPhotoUrls.where((url) => url.isNotEmpty));

                  if (photoUrls.isNotEmpty) {
                    setDialogState(() {
                      progressText = 'Fotograflar indiriliyor...';
                    });

                    final photosFolder = Directory("$actorFolderPath/Fotograflar");
                    if (!await photosFolder.exists()) {
                      await photosFolder.create(recursive: true);
                    }

                    for (int pIdx = 0; pIdx < photoUrls.length; pIdx++) {
                      final url = photoUrls[pIdx];
                      final isProfile = pIdx == 0 && (_actorProfile!.profilePhotoUrl != null && _actorProfile!.profilePhotoUrl!.isNotEmpty);

                      String ext = 'jpg';
                      final lowerUrl = url.toLowerCase();
                      if (lowerUrl.contains('.png') || lowerUrl.contains('.png?')) {
                        ext = 'png';
                      } else if (lowerUrl.contains('.jpeg') || lowerUrl.contains('.jpeg?')) {
                        ext = 'jpeg';
                      }

                      final photoPath = isProfile
                          ? "${photosFolder.path}/Profil Resmi.$ext"
                          : "${photosFolder.path}/Fotograf_${isProfile ? pIdx : pIdx + 1}.$ext";

                      try {
                        final isLocalPhoto = !url.startsWith('http://') && !url.startsWith('https://');
                        if (isLocalPhoto) {
                          String cleanLocalPath = url;
                          if (cleanLocalPath.startsWith('file://')) {
                            cleanLocalPath = Uri.parse(cleanLocalPath).toFilePath();
                          }
                          final file = File(cleanLocalPath);
                          if (await file.exists()) {
                            await file.copy(photoPath);
                          }
                        } else {
                          await Dio().download(url, photoPath);
                        }
                      } catch (photoErr) {
                        debugPrint('Photo download error: $photoErr');
                      }
                    }
                  }

                  if (context.mounted) {
                    Navigator.pop(dialogContext); // kapat

                    // ✔ İndirme başarılı → audition'u İnceleniyor statüsune geçir
                    final auth = context.read<AuthProvider>();
                    AuditionService().markAsReviewing(
                      auditionId: widget.audition.id,
                      reviewerId: auth.user?.uid,
                      reviewerName: auth.user?.fullName,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${widget.audition.actorName}" audition dosyaları başarıyla indirildi! 🎉'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e, s) {
                  debugPrint('Single download error: $e\n$s');
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('İndirme sırasında hata oluştu: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              });
            }

            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              title: const Text('Audition İndiriliyor'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppTheme.border,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    progressText,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Audition İncele'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Cihaza İndir (PDF + Video)',
            onPressed: () => _downloadSingleAudition(),
          ),
          if (context.read<AuthProvider>().user?.hasModeratorPermission('auditionCevaplama') ?? true)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Oyuncuya Mesaj/Bildirim Gönder',
              onPressed: () => _showMessageDialog(),
            ),
          if (context.read<AuthProvider>().user?.hasModeratorPermission('auditionSilme') ?? true)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              tooltip: 'Audition\'ı Sil',
              onPressed: () => _confirmDeleteAudition(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video oynatıcı
            _buildVideoPlayer()
                .animate()
                .fadeIn(duration: 300.ms),

            if (widget.adminNote != null || widget.forwardedBy != null)
              _buildForwardedDetailsCard()
                  .animate()
                  .fadeIn(delay: 150.ms),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Oyuncu + Proje bilgisi
                  _buildActorCard()
                      .animate()
                      .fadeIn(delay: 200.ms),

                  if (widget.audition.requestedBudget != null) ...[
                    const SizedBox(height: 20),
                    _buildBudgetDetailsCard()
                        .animate()
                        .fadeIn(delay: 250.ms),
                  ],

                  if (widget.audition.status == AuditionStatus.options) ...[
                    const SizedBox(height: 20),
                    _buildOptionResponsesCard()
                        .animate()
                        .fadeIn(delay: 280.ms),
                  ],

                  const SizedBox(height: 20),

                  // Video detayları
                  _buildVideoDetails()
                      .animate()
                      .fadeIn(delay: 300.ms),

                  // Oyuncu notu
                  if (widget.audition.note != null &&
                      widget.audition.note!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildSection(
                      'Oyuncu Notu',
                      Icons.message_outlined,
                      child: Text(
                        widget.audition.note!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                  ],

                  const SizedBox(height: 24),

                  // Değerlendirme notu
                  _buildSection(
                    'Geri Bildirim',
                    Icons.rate_review_outlined,
                    child: TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      maxLength: 500,
                      style:
                          const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText:
                            'Oyuncuya geri bildiriminizi yazın...',
                        counterStyle: GoogleFonts.inter(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 24),

                  // Aksiyon butonları
                  _buildActionButtons()
                      .animate()
                      .fadeIn(delay: 500.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_isVideoLoading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppTheme.surfaceLight,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppTheme.accent),
                SizedBox(height: 12),
                Text('Video yükleniyor...',
                    style: TextStyle(color: AppTheme.textTertiary)),
              ],
            ),
          ),
        ),
      );
    }

    if (_videoError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.videocam_off,
                  size: 32, color: AppTheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              'Video Oynatma Hatası',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _videoError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isVideoLoading = true;
                    _videoError = null;
                  });
                  _videoController?.dispose();
                  _videoController = null;
                  _chewieController?.dispose();
                  _chewieController = null;
                  _initVideo();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'Tekrar Dene',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildActorCard() {
    final authProvider = context.watch<AuthProvider>();
    final showProfileBtn = widget.includeProfile == true ||
        authProvider.isAdmin ||
        authProvider.isModerator;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _getInitials(widget.audition.actorName),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.audition.actorName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildMiniChip(
                            widget.audition.projectTitle, AppTheme.info),
                        _buildMiniChip(
                            widget.audition.roleName, AppTheme.accent),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(widget.audition.status),
            ],
          ),
          if (showProfileBtn) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: _isLoadingProfile
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.accent,
                        ),
                      ),
                    )
                  : TextButton.icon(
                      onPressed: _actorProfile == null
                          ? null
                          : () => _showActorProfileDialog(context),
                      icon: const Icon(Icons.person_search_outlined, size: 16),
                      label: Text(
                        'Oyuncu Profilini Gör',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _actorProfile == null ? AppTheme.textTertiary : AppTheme.accent,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _showActorProfileDialog(BuildContext context) {
    if (_actorProfile == null) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  'Oyuncu Profili',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                backgroundColor: AppTheme.surfaceCard,
                elevation: 0,
              ),
              body: ActorCvViewScreen(
                isOwner: false,
                actor: _actorProfile,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBudgetDetailsCard() {
    final audition = widget.audition;
    final isChanged = audition.isBudgetChanged;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isChanged 
            ? AppTheme.warning.withValues(alpha: 0.1) 
            : AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isChanged 
              ? AppTheme.warning.withValues(alpha: 0.3) 
              : AppTheme.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isChanged ? Icons.warning_amber_rounded : Icons.monetization_on,
                color: isChanged ? AppTheme.warning : AppTheme.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isChanged ? 'BÜTÇE TALEBİ DEĞİŞTİ' : 'BÜTÇE BİLGİSİ',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isChanged ? AppTheme.warning : AppTheme.success,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Talep Edilen Bütçe',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${audition.requestedBudget!.toStringAsFixed(0)} ₺',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (audition.originalBudget != null) ...[
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.border.withValues(alpha: 0.3),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Orijinal Rol Bütçesi',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${audition.originalBudget!.toStringAsFixed(0)} ₺',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (isChanged) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Oyuncu rolü almak istiyor ancak bütçenin artırılmasını talep ediyor.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoDetails() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailItem(
            Icons.timer,
            'Süre',
            widget.audition.formattedDuration,
          ),
          _buildDivider(),
          _buildDetailItem(
            Icons.sd_storage,
            'Boyut',
            widget.audition.formattedSize,
          ),
          _buildDivider(),
          _buildDetailItem(
            Icons.compress,
            'Sıkıştırma',
            '${(widget.audition.compressionRatio * 100).toStringAsFixed(0)}%',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.accent),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: AppTheme.border);
  }

  Widget _buildSection(String title, IconData icon,
      {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 14, color: AppTheme.accent),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [

        // Onayla
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _handleReview(AuditionStatus.approved),
            icon: const Icon(Icons.check_circle, size: 20),
            label: Text(
              'Onayla',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Opsiyonla
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _showOptionDialog(),
            icon: const Icon(Icons.star_rounded, size: 20),
            label: Text(
              'Opsiyonla',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Revizyon İste + Reddet
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _handleReview(AuditionStatus.revision),
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text(
                    'Revizyon',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.warning,
                    side: const BorderSide(color: AppTheme.warning),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _handleReview(AuditionStatus.rejected),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: Text(
                    'Reddet',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForwardedDetailsCard() {
    final photo = widget.attachedPhoto;
    final file = widget.attachedFile;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forward_to_inbox, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Yönlendirilen Değerlendirme Bilgisi',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.forwardedBy != null)
            Text(
              'İleten: ${widget.forwardedBy}',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          if (widget.adminNote != null && widget.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.adminNote!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (photo != null && photo.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.infinity,
                child: photo.startsWith('http')
                    ? Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackPhoto(photo),
                      )
                    : Image.file(
                        File(photo),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackPhoto(photo),
                      ),
              ),
            ),
          ],
          if (file != null && file.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.split('/').last.split('\\').last,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackPhoto(String path) {
    return Container(
      color: AppTheme.surfaceLight,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.image, color: AppTheme.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              path.split('/').last.split('\\').last,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusBadge(AuditionStatus status) {
    final color = _statusColor(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.displayName,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMiniChip(String text, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Color _statusColor(AuditionStatus status) {
    return switch (status) {
      AuditionStatus.uploading => AppTheme.textTertiary,
      AuditionStatus.submitted => AppTheme.info,
      AuditionStatus.reviewing => AppTheme.warning,
      AuditionStatus.options => Colors.purple,
      AuditionStatus.approved => AppTheme.success,
      AuditionStatus.rejected => AppTheme.error,
      AuditionStatus.revision => AppTheme.accent,
    };
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }


  Future<bool> _submitModeratorApprovalRequest({
    required String actionType,
    required String auditionId,
    required String projectTitle,
    required String roleName,
    required String actorName,
    String? reviewerNote,
    required String moderatorId,
    required String moderatorName,
  }) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('moderator_approvals').doc();
      await docRef.set({
        'id': docRef.id,
        'moderatorId': moderatorId,
        'moderatorName': moderatorName,
        'auditionId': auditionId,
        'projectTitle': projectTitle,
        'roleName': roleName,
        'actorName': actorName,
        'actionType': actionType,
        'reviewerNote': reviewerNote,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      final notifService = NotificationService();
      await notifService.sendBulkNotification(
        title: 'Moderatör Onay Talebi',
        body: '$moderatorName, "$projectTitle" projesi için bir audition işlemi ($actionType) gerçekleştirdi ve onayınızı bekliyor.',
        type: NotificationType.systemMessage,
        target: NotificationTarget.admins,
        senderId: moderatorId,
        senderName: moderatorName,
      );
      
      return true;
    } catch (e) {
      debugPrint('Error submitting moderator approval request: $e');
      return false;
    }
  }

  Future<void> _showMessageDialog() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          'Oyuncuya Mesaj Gönder',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Mesajınızı yazın...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final msg = controller.text.trim();
              if (msg.isEmpty) return;
              Navigator.pop(ctx);
              
              final authProvider = context.read<AuthProvider>();
              final user = authProvider.user;
              if (user == null) return;
              
              if (user.role == UserRole.moderator && user.moderatorPermissions?['approvalMode'] == 'admin') {
                final success = await _submitModeratorApprovalRequest(
                  actionType: 'message',
                  auditionId: widget.audition.id,
                  projectTitle: widget.audition.projectTitle,
                  roleName: widget.audition.roleName,
                  actorName: widget.audition.actorName,
                  reviewerNote: msg,
                  moderatorId: user.uid,
                  moderatorName: user.fullName,
                );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mesaj gönderme talebiniz Admin onayına sunuldu.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } else {
                try {
                  final notif = NotificationModel(
                    id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
                    recipientId: widget.audition.actorId,
                    title: 'Castelle Mesajı 📩',
                    body: msg,
                    type: NotificationType.systemMessage,
                    isRead: false,
                    senderId: user.uid,
                    senderName: user.fullName,
                    projectId: widget.audition.projectId,
                    createdAt: DateTime.now(),
                  );
                  await NotificationService().sendNotification(notif);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mesaj oyuncuya gönderildi.'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAudition() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          'Audition\'ı Sil',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Bu audition başvurusunu tamamen silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              final authProvider = context.read<AuthProvider>();
              final user = authProvider.user;
              if (user == null) return;
              
              if (user.role == UserRole.moderator && user.moderatorPermissions?['approvalMode'] == 'admin') {
                final success = await _submitModeratorApprovalRequest(
                  actionType: 'delete',
                  auditionId: widget.audition.id,
                  projectTitle: widget.audition.projectTitle,
                  roleName: widget.audition.roleName,
                  actorName: widget.audition.actorName,
                  moderatorId: user.uid,
                  moderatorName: user.fullName,
                );
                if (mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Silme talebiniz Admin onayına sunuldu.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  Navigator.pop(context);
                }
              } else {
                try {
                  await AuditionService().deleteAudition(widget.audition.id, widget.audition.videoUrl);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Audition başarıyla silindi.'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Evet, Sil', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _showOptionDialog() async {
    ProjectModel? project;
    try {
      project = await ProjectService().getProject(widget.audition.projectId);
    } catch (e) {
      debugPrint('Error fetching project: $e');
    }

    DateTime start = DateTime.now().add(const Duration(days: 7));
    DateTime end = DateTime.now().add(const Duration(days: 9));
    
    if (project != null && project.shootDate != null && project.shootDate!.isNotEmpty) {
      final parts = project.shootDate!.split(RegExp(r'[-\u2013\u2014]'));
      if (parts.length == 2) {
        try {
          final cleanStart = parts[0].trim();
          final cleanEnd = parts[1].trim();
          final startParts = cleanStart.split('.');
          final endParts = cleanEnd.split('.');
          if (startParts.length == 3 && endParts.length == 3) {
            start = DateTime(int.parse(startParts[2]), int.parse(startParts[1]), int.parse(startParts[0]));
            end = DateTime(int.parse(endParts[2]), int.parse(endParts[1]), int.parse(endParts[0]));
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return OptionRequestDialog(
          audition: widget.audition,
          initialStartDate: start,
          initialEndDate: end,
          onSubmit: (startDate, endDate, questions) async {
            final authProvider = context.read<AuthProvider>();
            final success = await context.read<AuditionProvider>().sendOptionRequest(
              auditionId: widget.audition.id,
              startDate: startDate,
              endDate: endDate,
              questions: questions,
              reviewerId: authProvider.user?.uid,
              reviewerName: authProvider.user?.fullName,
            );

            if (mounted && success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opsiyon talebi başarıyla gönderildi.'),
                  backgroundColor: AppTheme.success,
                ),
              );
              Navigator.pop(context, true); // Pop review screen
            }
          },
        );
      },
    );
  }

  Widget _buildOptionResponsesCard() {
    final startStr = widget.audition.optionStartDate != null ? _formatDate(widget.audition.optionStartDate!) : '';
    final endStr = widget.audition.optionEndDate != null ? _formatDate(widget.audition.optionEndDate!) : '';
    final answered = widget.audition.optionAvailable != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: Colors.purple.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                'Opsiyon Talebi Detayları',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'İletilen Çekim Tarihleri: $startStr - $endStr',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          if (!answered) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_empty_rounded, size: 14, color: AppTheme.warning),
                  const SizedBox(width: 6),
                  Text(
                    'Oyuncunun yanıtı bekleniyor...',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.warning),
                  ),
                ],
              ),
            ),
          ] else ...[
            Text(
              'Müsaitlik: ${widget.audition.optionAvailable == true ? "Evet (Müsait)" : "Hayır (Müsait Değil)"}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: widget.audition.optionAvailable == true ? AppTheme.success : AppTheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.audition.optionAvailable == false && widget.audition.optionExplanation != null) ...[
              const SizedBox(height: 4),
              Text(
                'Açıklama: ${widget.audition.optionExplanation}',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
            if (widget.audition.optionQuestions != null && widget.audition.optionQuestions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Soru ve Cevaplar:',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              for (final q in widget.audition.optionQuestions!) ...[
                Text(
                  'S: $q',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
                ),
                Text(
                  'C: ${widget.audition.optionAnswers?[q] ?? "Cevaplanmadı"}',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ]
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }
}

class OptionRequestDialog extends StatefulWidget {
  final AuditionModel audition;
  final DateTime initialStartDate;
  final DateTime initialEndDate;
  final Function(DateTime startDate, DateTime endDate, List<String> questions) onSubmit;

  const OptionRequestDialog({
    super.key,
    required this.audition,
    required this.initialStartDate,
    required this.initialEndDate,
    required this.onSubmit,
  });

  @override
  State<OptionRequestDialog> createState() => _OptionRequestDialogState();
}

class _OptionRequestDialogState extends State<OptionRequestDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  final List<TextEditingController> _questionControllers = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
  }

  @override
  void dispose() {
    for (final controller in _questionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questionControllers.add(TextEditingController());
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questionControllers[index].dispose();
      _questionControllers.removeAt(index);
    });
  }

  Future<void> _selectDates() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.accent,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceCard,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opsiyon Talebi Gönder',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Oyuncuya çekim tarihini iletin ve sorularınızı sorun.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Çekim Tarihi Aralığı',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selectDates,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppTheme.accent, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sorular',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addQuestion,
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(
                            'Soru Ekle',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.accent,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_questionControllers.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          'Eklenmiş özel soru bulunmuyor.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _questionControllers.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _questionControllers[index],
                                  decoration: InputDecoration(
                                    hintText: '${index + 1}. Soruyu yazın...',
                                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    filled: true,
                                    fillColor: AppTheme.surfaceLight,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                      borderSide: BorderSide(color: AppTheme.border),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                      borderSide: BorderSide(color: AppTheme.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                      borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                                    ),
                                  ),
                                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                onPressed: () => _removeQuestion(index),
                              ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'İptal',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitting
                      ? null
                      : () async {
                          final questions = _questionControllers
                              .map((c) => c.text.trim())
                              .where((q) => q.isNotEmpty)
                              .toList();
                          setState(() {
                            _submitting = true;
                          });
                          try {
                            await widget.onSubmit(_startDate, _endDate, questions);
                          } finally {
                            if (mounted) {
                              setState(() {
                                _submitting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Gönder',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

