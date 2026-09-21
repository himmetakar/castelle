import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/audition_model.dart';

/// Castelle - Oyuncunun Kendi Audition Detayı
/// "Başvurularım" listesinden bir audition'a tıklandığında açılır.
/// Salt okunur: video oynatma ve gönderim bilgileri gösterilir,
/// yönetmen/admin onay-ret gibi işlemler burada YOK.
class MyAuditionDetailScreen extends StatefulWidget {
  final AuditionModel audition;

  const MyAuditionDetailScreen({
    super.key,
    required this.audition,
  });

  @override
  State<MyAuditionDetailScreen> createState() =>
      _MyAuditionDetailScreenState();
}

class _MyAuditionDetailScreenState extends State<MyAuditionDetailScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoLoading = true;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    var videoUrl = widget.audition.videoUrl;

    // Firebase Storage URL'sindeki slash karakterlerini %2F yapacak şekilde
    // düzelt (eski kayıtlar için)
    if (videoUrl.startsWith('http') && videoUrl.contains('/o/')) {
      final oIndex = videoUrl.indexOf('/o/');
      final queryIndex = videoUrl.indexOf('?', oIndex);
      final baseUrl = videoUrl.substring(0, oIndex + 3);
      final queryParams =
          queryIndex != -1 ? videoUrl.substring(queryIndex) : '';
      final rawPath = queryIndex != -1
          ? videoUrl.substring(oIndex + 3, queryIndex)
          : videoUrl.substring(oIndex + 3);

      if (rawPath.contains('/') && !rawPath.contains('%2F')) {
        final encodedPath = Uri.encodeComponent(rawPath);
        videoUrl = '$baseUrl$encodedPath$queryParams';
      }
    }

    if (videoUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isVideoLoading = false;
        _videoError = 'Video URL bulunamadı. Audition kaydında video bilgisi eksik.';
      });
      return;
    }

    final isLocalFile = videoUrl.startsWith('/') ||
        videoUrl.startsWith('file://') ||
        videoUrl.contains('/data/') ||
        videoUrl.contains('/storage/');

    try {
      if (isLocalFile) {
        final cleanPath = videoUrl.replaceFirst(RegExp(r'^file://'), '');
        final file = File(cleanPath);
        final exists = await file.exists();

        if (!exists) {
          if (!mounted) return;
          setState(() {
            _isVideoLoading = false;
            _videoError =
                'Video dosyası cihazda bulunamadı.\n\nDosya adı: ${cleanPath.split('/').last}';
          });
          return;
        }

        try {
          _videoController = VideoPlayerController.file(file);
          await _videoController!.initialize();
        } catch (_) {
          _videoController?.dispose();
          _videoController = VideoPlayerController.networkUrl(Uri.file(cleanPath));
          await _videoController!.initialize();
        }
      } else if (videoUrl.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        await _videoController!.initialize();
      } else {
        if (!mounted) return;
        setState(() {
          _isVideoLoading = false;
          _videoError = 'Geçersiz video adresi:\n$videoUrl';
        });
        return;
      }
    } catch (e) {
      _videoController?.dispose();
      _videoController = null;
      if (!mounted) return;
      setState(() {
        _isVideoLoading = false;
        _videoError = 'Video oynatılamadı.\n\nHata: $e';
      });
      return;
    }

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

    if (!mounted) return;
    setState(() => _isVideoLoading = false);
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Color _statusColor(AuditionStatus status) {
    return switch (status) {
      AuditionStatus.uploading => AppTheme.textTertiary,
      AuditionStatus.submitted => AppTheme.warning,
      AuditionStatus.reviewing => AppTheme.info,
      AuditionStatus.options => AppTheme.accent,
      AuditionStatus.approved => AppTheme.success,
      AuditionStatus.rejected => AppTheme.error,
      AuditionStatus.revision => AppTheme.accent,
    };
  }

  Widget _buildStatusChip(AuditionModel audition) {
    String label = audition.status.displayName;
    Color color = _statusColor(audition.status);

    if (audition.status == AuditionStatus.options) {
      if (audition.optionAvailable == null) {
        label = '🟡 Cevap Bekleniyor';
        color = AppTheme.warning;
      } else if (audition.optionAvailable == true) {
        label = '🟢 Opsiyonda';
        color = AppTheme.success;
      } else {
        label = '🔴 Müsait Değil';
        color = AppTheme.error;
      }
    } else if (audition.status == AuditionStatus.approved) {
      label = '🔵 Kesinleşti';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
        ),
      ],
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
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
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
                label: Text('Tekrar Dene', style: GoogleFonts.inter(fontSize: 13)),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Chewie(controller: _chewieController!),
      ),
    );
  }

  Widget _buildOptionResponseDetails(AuditionModel audition) {
    String formatDateOnly(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    final startStr =
        audition.optionStartDate != null ? formatDateOnly(audition.optionStartDate!) : '';
    final endStr =
        audition.optionEndDate != null ? formatDateOnly(audition.optionEndDate!) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'Opsiyon Yanıtı İletildi',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Çekim Tarihleri: $startStr - $endStr',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Müsaitlik: ${audition.optionAvailable == true ? "Evet (Müsaitim)" : "Hayır (Müsait değilim)"}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: audition.optionAvailable == true ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (audition.optionAvailable == false && audition.optionExplanation != null) ...[
            const SizedBox(height: 4),
            Text(
              'Açıklama: ${audition.optionExplanation}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
          if (audition.optionQuestions != null && audition.optionQuestions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Sorular ve Cevaplarınız:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            for (final q in audition.optionQuestions!) ...[
              Text(
                'S: $q',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
              Text(
                'C: ${audition.optionAnswers?[q] ?? "Yanıtlanmadı"}',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
        ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audition = widget.audition;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          audition.projectTitle.isNotEmpty ? audition.projectTitle : 'Audition Detayı',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVideoPlayer(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              audition.projectTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              audition.roleName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(audition),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildMiniInfo(Icons.timer, audition.formattedDuration),
                      _buildMiniInfo(Icons.sd_storage, audition.formattedSize),
                      if (audition.requestedBudget != null)
                        _buildMiniInfo(
                          Icons.attach_money,
                          '${audition.requestedBudget!.toStringAsFixed(0)} ₺',
                        ),
                    ],
                  ),
                  if (audition.note != null && audition.note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Notunuz',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      audition.note!,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                  if (audition.reviewerNote != null && audition.reviewerNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor(audition.status).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: _statusColor(audition.status).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.feedback_outlined, size: 14, color: _statusColor(audition.status)),
                              const SizedBox(width: 6),
                              Text(
                                'Geri Bildirim${audition.reviewerName != null ? " — ${audition.reviewerName}" : ""}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(audition.status),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            audition.reviewerNote!,
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (audition.status == AuditionStatus.options)
                    _buildOptionResponseDetails(audition),
                  const SizedBox(height: 12),
                  Text(
                    'Gönderim: ${_formatDate(audition.createdAt)}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
