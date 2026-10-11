import 'dart:async';
import 'dart:io' show File;

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'package:castelle/core/theme/app_theme.dart';

/// Castelle — Ortak, cihazdan bağımsız video oynatıcı
///
/// Uygulamadaki tüm video gösterimleri (profil tanıtım videosu, proje örnek
/// videosu, audition videoları) bu widget'ı kullanır. Eski oynatıcılarda
/// cihaza göre değişen şu sorunlar giderildi:
///
/// * Bir sayfada birden fazla video aynı anda başlatılıyordu. Bazı Android
///   cihazlarda donanım çözücü (decoder) sayısı sınırlı olduğu için videolar
///   hiç açılmıyor / beyaz-siyah ekran kalıyordu. Artık video, [autoInit]
///   verilmedikçe ancak kullanıcı oynat'a bastığında başlatılır.
/// * Başlatma hatası veya takılma durumunda sonsuz yükleniyor animasyonu ya
///   da boş (beyaz) alan kalıyordu. Artık zaman aşımı + anlaşılır hata ve
///   "Tekrar Dene" / "Harici Oynatıcıda Aç" seçenekleri var.
/// * Dikey (portre) videolar tüm ekranı kaplıyordu. Yükseklik [maxHeight]
///   ile sınırlandı, video siyah zemin üzerinde ortalanıyor.
/// * Video değiştirildiğinde (ör. profil videosu yenilendiğinde) eski video
///   gösterilmeye devam ediyordu. URL değişince oynatıcı yeniden kurulur.
/// * Eski kayıtlardaki hatalı Firebase Storage URL'leri (%2F kodlaması
///   eksik) otomatik düzeltilir.
class AppVideoPlayer extends StatefulWidget {
  /// Ağ adresi (http/https/blob) veya yerel dosya yolu.
  final String videoUrl;

  /// true ise sayfa açılır açılmaz video hazırlanır (oynatılmaz).
  final bool autoInit;

  /// Oynatıcı alanının en fazla yüksekliği.
  final double maxHeight;

  /// Oynatıcı hazır olmadan önce gösterilecek başlık (ops.).
  final String? title;

  final double borderRadius;

  const AppVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoInit = false,
    this.maxHeight = 460,
    this.title,
    this.borderRadius = 10,
  });

  /// Firebase Storage URL'sindeki "/o/" sonrası yolun %2F ile kodlanmasını
  /// garanti eder (eski kayıtlar için).
  static String normalizeUrl(String url) {
    var videoUrl = url.trim();
    if (videoUrl.startsWith('http') && videoUrl.contains('/o/')) {
      final oIndex = videoUrl.indexOf('/o/');
      final queryIndex = videoUrl.indexOf('?', oIndex);
      final baseUrl = videoUrl.substring(0, oIndex + 3);
      final queryParams = queryIndex != -1 ? videoUrl.substring(queryIndex) : '';
      final rawPath = queryIndex != -1
          ? videoUrl.substring(oIndex + 3, queryIndex)
          : videoUrl.substring(oIndex + 3);
      if (rawPath.contains('/') && !rawPath.contains('%2F')) {
        videoUrl = '$baseUrl${Uri.encodeComponent(rawPath)}$queryParams';
      }
    }
    return videoUrl;
  }

  static bool _isLocalPath(String url) {
    if (kIsWeb) return false;
    return url.startsWith('/') ||
        url.startsWith('file://') ||
        url.contains('/data/') ||
        url.contains('/storage/') ||
        RegExp(r'^[A-Za-z]:\\').hasMatch(url);
  }

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = false;
  String? _error;
  int _initToken = 0;

  String get _url => AppVideoPlayer.normalizeUrl(widget.videoUrl);

  @override
  void initState() {
    super.initState();
    if (widget.autoInit) {
      _initPlayer(autoPlay: false);
    }
  }

  @override
  void didUpdateWidget(covariant AppVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeControllers();
      _error = null;
      _isLoading = false;
      if (widget.autoInit) {
        _initPlayer(autoPlay: false);
      }
    }
  }

  @override
  void dispose() {
    _initToken++;
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    final chewie = _chewieController;
    final video = _videoController;
    _chewieController = null;
    _videoController = null;
    chewie?.dispose();
    video?.dispose();
  }

  Future<void> _initPlayer({required bool autoPlay}) async {
    final url = _url;
    if (url.isEmpty) {
      setState(() => _error = 'Video adresi bulunamadı.');
      return;
    }

    final token = ++_initToken;
    _disposeControllers();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    VideoPlayerController? controller;
    try {
      if (AppVideoPlayer._isLocalPath(url)) {
        final clean = url.replaceFirst(RegExp(r'^file://'), '');
        final file = File(clean);
        if (!await file.exists()) {
          throw Exception('Video dosyası bu cihazda bulunamadı.');
        }
        controller = VideoPlayerController.file(file);
      } else {
        controller = VideoPlayerController.networkUrl(
          Uri.parse(url),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      await controller.initialize().timeout(const Duration(seconds: 30));

      if (!mounted || token != _initToken) {
        await controller.dispose();
        return;
      }

      final size = controller.value.size;
      var aspect = controller.value.aspectRatio;
      if (aspect.isNaN || aspect.isInfinite || aspect <= 0 || size.isEmpty) {
        aspect = 9 / 16;
      }
      final isPortrait = aspect < 1;

      _videoController = controller;
      _chewieController = ChewieController(
        videoPlayerController: controller,
        aspectRatio: aspect,
        autoPlay: autoPlay,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        showControlsOnInitialize: false,
        deviceOrientationsOnEnterFullScreen: isPortrait
            ? const [DeviceOrientation.portraitUp]
            : const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ],
        deviceOrientationsAfterFullScreen: const [
          DeviceOrientation.portraitUp,
        ],
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accent,
          handleColor: AppTheme.accent,
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white38,
        ),
        errorBuilder: (context, message) => _buildError(
          'Video oynatılırken bir sorun oluştu.',
        ),
      );

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('⚠️ [AppVideoPlayer] Video başlatılamadı ($url): $e');
      try {
        await controller?.dispose();
      } catch (_) {}
      if (!mounted || token != _initToken) return;
      _videoController = null;
      _chewieController = null;
      setState(() {
        _isLoading = false;
        _error = e is TimeoutException
            ? 'Video zaman aşımına uğradı. İnternet bağlantınızı kontrol edip tekrar deneyin.'
            : 'Video bu cihazda açılamadı.';
      });
    }
  }

  Future<void> _openExternally() async {
    final uri = Uri.tryParse(_url);
    if (uri == null) return;
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video açılamadı: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _frame({required double width, required double height, required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: width,
        height: height,
        color: Colors.black,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildError(String message) {
    final canOpenExternally = _url.startsWith('http');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 30),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _initPlayer(autoPlay: true),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Tekrar Dene'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              if (canOpenExternally)
                ElevatedButton.icon(
                  onPressed: _openExternally,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Harici Oynatıcıda Aç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        final controller = _videoController;
        final chewie = _chewieController;

        // Hazır oynatıcı
        if (controller != null && chewie != null && controller.value.isInitialized) {
          final aspect = chewie.aspectRatio ?? controller.value.aspectRatio;
          var width = maxWidth;
          var height = width / aspect;
          if (height > widget.maxHeight) {
            height = widget.maxHeight;
            width = height * aspect;
          }
          return Center(
            child: _frame(
              width: maxWidth,
              height: height,
              child: SizedBox(
                width: width,
                height: height,
                child: Chewie(controller: chewie),
              ),
            ),
          );
        }

        final placeholderHeight = (maxWidth * 9 / 16).clamp(160.0, widget.maxHeight);

        if (_isLoading) {
          return _frame(
            width: maxWidth,
            height: placeholderHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.accent),
                const SizedBox(height: 10),
                Text(
                  'Video yükleniyor...',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          );
        }

        if (_error != null) {
          return _frame(
            width: maxWidth,
            height: placeholderHeight < 200 ? 200 : placeholderHeight,
            child: _buildError(_error!),
          );
        }

        // Henüz başlatılmadı — oynat butonu
        return GestureDetector(
          onTap: () => _initPlayer(autoPlay: true),
          child: _frame(
            width: maxWidth,
            height: placeholderHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.title != null ? '${widget.title} — Oynat' : 'Videoyu Oynat',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
