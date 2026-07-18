import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';
import 'package:castelle/core/widgets/video_record_screen.dart';

/// Castelle - Audition Video Gönderim Ekranı
/// Video seçme/çekme → önizleme → sıkıştırma → yükleme

class AuditionSubmitScreen extends StatefulWidget {
  final ProjectModel project;
  final ProjectRole role;
  final String? customScript;
  final bool budgetFlexible;

  const AuditionSubmitScreen({
    super.key,
    required this.project,
    required this.role,
    this.customScript,
    this.budgetFlexible = false,
  });

  @override
  State<AuditionSubmitScreen> createState() => _AuditionSubmitScreenState();
}

class _AuditionSubmitScreenState extends State<AuditionSubmitScreen> {
  final _noteController = TextEditingController();
  final _budgetController = TextEditingController();
  final _picker = ImagePicker();

  File? _selectedVideo;
  VideoPlayerController? _videoController;
  bool _isVideoReady = false;
  int? _fileSizeBytes;
  double? _requestedBudget;

  @override
  void initState() {
    super.initState();
    _requestedBudget = widget.role.budget;
    if (_requestedBudget != null) {
      _budgetController.text = _requestedBudget!.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _budgetController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    final xFile = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );

    if (xFile == null) return;

    debugPrint('📹 [image_picker] xFile.path: "${xFile.path}"');

    final file = File(xFile.path);
    final size = await file.length();
    debugPrint('📹 [image_picker] Dosya boyutu: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');

    setState(() {
      _selectedVideo = file;
      _fileSizeBytes = size;
      _isVideoReady = false;
    });

    // Video önizleme başlat – çift yöntem
    _videoController?.dispose();
    try {
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      setState(() => _isVideoReady = true);
      debugPrint('✅ [Preview] file() yöntemi başarılı.');
    } catch (e) {
      debugPrint('⚠️ [Preview] file() başarısız: $e → networkUrl(Uri.file()) deneniyor...');
      _videoController?.dispose();
      try {
        _videoController = VideoPlayerController.networkUrl(Uri.file(xFile.path));
        await _videoController!.initialize();
        setState(() => _isVideoReady = true);
        debugPrint('✅ [Preview] networkUrl(Uri.file()) başarılı.');
      } catch (e2) {
        debugPrint('❌ [Preview] Her iki yöntem başarısız: $e2');
        setState(() => _isVideoReady = false);
      }
    }
  }

  Future<void> _recordCustomVideo() async {
    final script = widget.customScript ?? widget.role.auditionScript;
    final audioUrl = widget.role.backgroundAudioUrl; // Rol bazlı arka plan sesi
    final videoPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => VideoRecordScreen(
          prefilledScript: script,
          backgroundAudioUrl: audioUrl,
        ),
      ),
    );

    if (videoPath == null || videoPath.isEmpty) return;

    final file = File(videoPath);
    final size = await file.length();

    setState(() {
      _selectedVideo = file;
      _fileSizeBytes = size;
      _isVideoReady = false;
    });

    _videoController?.dispose();
    try {
      _videoController = VideoPlayerController.file(file);
      await _videoController!.initialize();
      setState(() => _isVideoReady = true);
    } catch (e) {
      debugPrint('⚠️ [Preview] custom record file failed: $e');
      setState(() => _isVideoReady = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedVideo == null) return;

    // Deadline check
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (widget.project.deadline != null) {
      final deadlineDate = DateTime(widget.project.deadline!.year, widget.project.deadline!.month, widget.project.deadline!.day);
      if (deadlineDate.isBefore(today)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu projenin son başvuru tarihi dolduğu için audition gönderilemez.'),
            backgroundColor: AppTheme.error,
          ),
        );
        return;
      }
    }

    final authProvider = context.read<AuthProvider>();
    final auditionProvider = context.read<AuditionProvider>();

    final success = await auditionProvider.submitAudition(
      videoFile: _selectedVideo!,
      actorId: authProvider.user!.uid,
      actorName: authProvider.user!.fullName,
      projectId: widget.project.id,
      projectTitle: widget.project.title,
      roleName: widget.role.roleName,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      requestedBudget: _requestedBudget,
      originalBudget: widget.role.budget,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audition başarıyla gönderildi! 🎉'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(auditionProvider.errorMessage ?? 'Gönderim başarısız'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auditionProvider = context.watch<AuditionProvider>();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isDeadlinePassed = false;
    if (widget.project.deadline != null) {
      final deadlineDate = DateTime(widget.project.deadline!.year, widget.project.deadline!.month, widget.project.deadline!.day);
      isDeadlinePassed = deadlineDate.isBefore(today);
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Audition Gönder'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: auditionProvider.isProcessing
              ? null
              : () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Banner if Deadline Passed
            if (isDeadlinePassed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Bu projenin son başvuru tarihi dolduğu için yeni audition gönderilemez.',
                        style: GoogleFonts.inter(
                          color: AppTheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Proje + Rol bilgisi
            _buildProjectCard()
                .animate()
                .fadeIn(duration: 200.ms),

            const SizedBox(height: 16),

            // Bütçe Talebi Bölümü
            _buildBudgetCard()
                .animate()
                .fadeIn(delay: 50.ms),

            const SizedBox(height: 24),

            // Video seçim / önizleme
            if (_selectedVideo == null)
              isDeadlinePassed
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.videocam_off, size: 48, color: AppTheme.textTertiary),
                          const SizedBox(height: 16),
                          Text(
                            'Başvurular Kapatıldı',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildVideoPickerCard()
                      .animate()
                      .fadeIn(delay: 100.ms)
            else
              _buildVideoPreview()
                  .animate()
                  .fadeIn(delay: 100.ms),

            const SizedBox(height: 24),

            // Not ekleme
            _buildSectionTitle('Ek Not (opsiyonel)'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 300,
              enabled: !auditionProvider.isProcessing && !isDeadlinePassed,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: isDeadlinePassed
                    ? 'Başvuru süresi dolduğu için not eklenemez.'
                    : 'Yönetmene iletmek istediğiniz bir notunuz var mı?',
                alignLabelWithHint: true,
                counterStyle: GoogleFonts.inter(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 24),

            // İşlem durumu
            if (auditionProvider.isProcessing)
              _buildProcessingCard(auditionProvider)
                  .animate()
                  .fadeIn(),

            // Gönder butonu
            if (!auditionProvider.isProcessing) ...[
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed:
                      _selectedVideo != null && !isDeadlinePassed ? _handleSubmit : null,
                  icon: const Icon(Icons.send),
                  label: Text(
                    'Audition Gönder',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textOnAccent,
                    disabledBackgroundColor:
                        AppTheme.surfaceElevated,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // YARDIMCI WİDGET'LAR
  // ═══════════════════════════════════════

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildBudgetCard() {
    final isFlexible = widget.budgetFlexible;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle('Proje Bütçesi'),
              if (widget.role.budget != null)
                Text(
                  '${widget.role.budget!.toStringAsFixed(0)} ₺',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                )
              else
                Text(
                  'Belirtilmemiş',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isFlexible
                ? 'Rol almak isteyebilirsiniz ancak bütçe yetersiz gelebilir. Talep ettiğiniz bütçeyi aşağıdan düzenleyebilirsiniz:'
                : 'Bu rol için bütçe sabittir, bütçe değişikliği talep etme yetkiniz bulunmamaktadır.',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          if (isFlexible) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Talep Ettiğiniz Bütçe (₺)',
                hintText: 'Örn: 25000',
                prefixIcon: Icon(Icons.monetization_on_outlined, size: 20),
              ),
              onChanged: (val) {
                setState(() {
                  _requestedBudget = double.tryParse(val);
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🎬', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.project.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        widget.role.roleName,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPickerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.videocam,
                size: 32, color: AppTheme.accent),
          ),
          const SizedBox(height: 16),
          Text(
            'Audition Videonuzu Ekleyin',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kameranızla çekin veya galeriden seçin\nMaksimum 5 dakika',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPickerButton(
                Icons.camera_alt,
                'Kamera',
                _recordCustomVideo,
              ),
              const SizedBox(width: 16),
              _buildPickerButton(
                Icons.photo_library,
                'Galeri',
                () => _pickVideo(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton(
      IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppTheme.accent),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Video oynatıcı
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusMd),
            ),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              color: Colors.black,
              width: double.infinity,
              child: _isVideoReady
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_videoController!.value.isPlaying) {
                                _videoController!.pause();
                              } else {
                                _videoController!.play();
                              }
                            });
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_videoController!),
                              if (!_videoController!.value.isPlaying)
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow,
                                      size: 32, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.accent,
                      ),
                    ),
            ),
          ),

          // Video bilgileri
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.video_file,
                    size: 18, color: AppTheme.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video seçildi',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (_fileSizeBytes != null)
                        Text(
                          'Orijinal: ${(_fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
                          '${_isVideoReady ? " · ${_formatDuration(_videoController!.value.duration)}" : ""}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                // Değiştir butonu
                GestureDetector(
                  onTap: () {
                    _videoController?.dispose();
                    _videoController = null;
                    setState(() {
                      _selectedVideo = null;
                      _isVideoReady = false;
                      _fileSizeBytes = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Değiştir',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingCard(AuditionProvider provider) {
    final isCompressing = provider.isCompressing;
    final progress = isCompressing
        ? provider.compressProgress
        : provider.uploadProgress;
    final label =
        isCompressing ? 'Video sıkıştırılıyor...' : 'Yükleniyor...';
    final icon = isCompressing ? Icons.compress : Icons.cloud_upload;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.accent),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.surfaceElevated,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: provider.cancelProcessing,
            child: Text(
              'İptal Et',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final min = duration.inMinutes;
    final sec = duration.inSeconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}
