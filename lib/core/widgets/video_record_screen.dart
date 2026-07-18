import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Premium Video Kayıt & Teleprompter Ekranı
/// Yatay çekim kontrolü, hız/boyut ayarlı prompter ve geri sayım sayacı içerir.

class VideoRecordScreen extends StatefulWidget {
  final String? prefilledScript;
  final String? backgroundAudioUrl; // Rolle iligli arka plan sesi
  final bool isMimicMode; // Mimik rehberi modu

  const VideoRecordScreen({
    super.key,
    this.prefilledScript,
    this.backgroundAudioUrl,
    this.isMimicMode = false,
  });

  @override
  State<VideoRecordScreen> createState() => _VideoRecordScreenState();
}

class _VideoRecordScreenState extends State<VideoRecordScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  int _selectedCameraIndex = 1; // Varsayılan ön kamera (varsa)

  // Mimik Modu Değişkenleri
  FlutterTts? _flutterTts;
  int _currentMimicIndex = 0;
  Timer? _mimicTimer;
  String _currentMimicText = '';
  final List<String> _mimicPrompts = [
    "Çok mutlusun",
    "Şaşırdın",
    "Üzüldün",
    "Sinirlendin",
    "Tekrar çok mutlusun",
    "Ellerini göster",
    "Ellerinin tersini göster",
    "Teşekkürler",
  ];

  // Prompter Ayarları
  bool _isPrompterOpen = true;
  double _scrollSpeed = 2.0; // 1x ile 5x arası
  double _fontSize = 24.0;   // 18 ile 36 arası
  late TextEditingController _scriptController;
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  // Geri Sayım Ayarları
  int _countdownSeconds = 3; // 0 (yok), 3, 5, 10
  bool _isCountingDown = false;
  int _currentCountdown = 3;
  Timer? _countdownTimer;

  // Hata durumları
  String? _errorMessage;

  // Arka plan sesi
  AudioPlayer? _audioPlayer;
  bool _audioMuted = false;
  bool _hasBackgroundAudio = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  double _audioVolume = 0.5; // Default volume: 50%

  // Prompter durdurma (kayıt sırasında)
  bool _isPrompterPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scriptController = TextEditingController(text: widget.prefilledScript ?? '');
    _hasBackgroundAudio = widget.backgroundAudioUrl != null &&
        widget.backgroundAudioUrl!.isNotEmpty;

    if (widget.isMimicMode) {
      _initTts();
    }

    // Arka plan sesi varsa hazırla
    if (_hasBackgroundAudio) {
      _initAudioPlayer();
    }
    
    // Kamera ekranında yatay modu algılamak için preferred orientations'ı serbest bırak
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollTimer?.cancel();
    _countdownTimer?.cancel();
    _mimicTimer?.cancel();
    _flutterTts?.stop();
    WakelockPlus.disable();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _controller?.dispose();
    _scriptController.dispose();
    _scrollController.dispose();

    // Ekrandan çıkarken tekrar dikey moda kilitle
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App arka plana gidince kamerayı durdur/temizle
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _audioPlayer?.stop();
    } else if (state == AppLifecycleState.resumed) {
      _onCameraSelected(cameraController.description);
    }
  }

  Future<void> _initCamera() async {
    // İzin kontrolleri
    final cameraStatus = await Permission.camera.request();
    final micStatus = await Permission.microphone.request();

    if (!cameraStatus.isGranted || !micStatus.isGranted) {
      setState(() {
        _errorMessage = 'Kamera ve mikrofon izinleri gereklidir.';
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'Cihazda kullanılabilir kamera bulunamadı.';
        });
        return;
      }

      // Ön kamerayı bulmaya çalış (genellikle lensDirection = front)
      int frontIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (frontIndex != -1) {
        _selectedCameraIndex = frontIndex;
      } else {
        _selectedCameraIndex = 0;
      }

      await _onCameraSelected(_cameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _errorMessage = 'Kamera başlatılırken hata oluştu: $e';
      });
    }
  }

  Future<void> _onCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = cameraController;

    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
      if (cameraController.value.hasError) {
        setState(() {
          _errorMessage = 'Kamera Hatası: ${cameraController.value.errorDescription}';
        });
      }
    });

    try {
      await cameraController.initialize();
      // Lock to landscape values if needed, but standard orientation is fine
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Kamera yüklenemedi: $e';
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _onCameraSelected(_cameras[_selectedCameraIndex]);
  }

  // Geri Sayım & Kayıt Yönetimi
  void _startRecordWorkflow() {
    if (_isCountingDown || _isRecording) return;

    // Kayıt anında dikey olup olmadığını kontrol et
    final isPortrait = MediaQuery.of(context).size.height > MediaQuery.of(context).size.width;
    if (isPortrait) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt başlatılamadı: Lütfen cihazınızı yatay (landscape) konuma getirin!'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (_countdownSeconds > 0) {
      setState(() {
        _isCountingDown = true;
        _currentCountdown = _countdownSeconds;
      });

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_currentCountdown == 1) {
          timer.cancel();
          setState(() {
            _isCountingDown = false;
          });
          _startRecording();
        } else {
          setState(() {
            _currentCountdown--;
          });
        }
      });
    } else {
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isRecording) {
      return;
    }

    try {
      await controller.startVideoRecording();
      await WakelockPlus.enable(); // Ekranın kararmasını önle
      setState(() {
        _isRecording = true;
        _isPrompterPaused = false;
      });

      // Ses ve prompter'ı aynı anda başlat (await olmadan — race condition önlenir)
      if (_hasBackgroundAudio && !_audioMuted) {
        _audioPlayer?.seek(Duration.zero);
        _audioPlayer?.play();
      }

      // Prompter açık ve metin doluysa kaydırmayı başlat
      if (widget.isMimicMode) {
        _startMimicSequence();
      } else if (_isPrompterOpen && _scriptController.text.isNotEmpty) {
        _startPrompterScroll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kayıt başlatılamadı: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isRecordingVideo) {
      return;
    }

    try {
      final XFile file = await controller.stopVideoRecording();
      await WakelockPlus.disable(); // Ekranda kalmayı kapat
      setState(() {
        _isRecording = false;
      });
      _stopPrompterScroll();
      _mimicTimer?.cancel();
      _flutterTts?.stop();
      await _audioPlayer?.stop(); // Sesi durdur

      // Kaydedilen videoyu doğrula ve geri gönder
      if (mounted) {
        Navigator.pop(context, file.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt durdurulamadı: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts?.setLanguage("tr-TR");
    _flutterTts?.setSpeechRate(0.5);
    _flutterTts?.setVolume(1.0);
    
    // Ensure iOS plays through speaker while recording
    if (Platform.isIOS) {
      _flutterTts?.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    }
  }

  void _startMimicSequence() {
    _currentMimicIndex = 0;
    _nextMimicStep();
  }

  void _nextMimicStep() {
    if (!mounted || !_isRecording) return;

    if (_currentMimicIndex >= _mimicPrompts.length) {
      _stopRecording();
      return;
    }

    final prompt = _mimicPrompts[_currentMimicIndex];
    setState(() {
      _currentMimicText = prompt;
    });

    _speak(prompt);

    _mimicTimer = Timer(const Duration(seconds: 5), () {
      _currentMimicIndex++;
      _nextMimicStep();
    });
  }

  Future<void> _speak(String text) async {
    try {
      await _flutterTts?.stop();
      await _flutterTts?.speak(text);
    } catch (e) {
      debugPrint("TTS speak error: $e");
    }
  }

  Future<void> _initAudioPlayer() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setUrl(widget.backgroundAudioUrl!);
      await _audioPlayer!.setLoopMode(LoopMode.one);
      await _audioPlayer!.setVolume(_audioVolume);

      // Duration ve pozisyon stream'lerini dinle
      _audioPlayer!.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _audioDuration = d);
      });
      _audioPlayer!.positionStream.listen((p) {
        if (mounted) setState(() => _audioPosition = p);
      });

      debugPrint('🎧 [BackgroundAudio] Hazır: ${widget.backgroundAudioUrl}');
    } catch (e) {
      debugPrint('⚠️ [BackgroundAudio] Yüklenemedi: $e');
      _hasBackgroundAudio = false;
    }
  }

  // Prompter Scroll Motoru
  void _startPrompterScroll() {
    _scrollTimer?.cancel();
    _scrollController.jumpTo(0);

    const int tickMs = 30;
    _scrollTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      if (!mounted || !_isRecording || !_isPrompterOpen) {
        timer.cancel();
        return;
      }
      // Durdurulmuşsa kaydırma
      if (_isPrompterPaused) return;

      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.offset;
        if (currentScroll >= maxScroll) {
          timer.cancel();
          return;
        }
        final double step = _scrollSpeed * 0.45;
        _scrollController.jumpTo(currentScroll + step);
      }
    });
  }

  void _stopPrompterScroll() {
    _scrollTimer?.cancel();
  }

  void _togglePrompterPause() {
    setState(() => _isPrompterPaused = !_isPrompterPaused);
  }

  // Ses ilerleme string formatı
  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Kayıt sırasında ses ilerleme barı
  Widget _buildAudioBar() {
    final total = _audioDuration.inMilliseconds.toDouble();
    final current = _audioPosition.inMilliseconds.toDouble().clamp(0.0, total > 0 ? total : 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note_rounded, size: 13, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                'Arka Plan Sesi',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${_formatDuration(_audioPosition)} / ${_formatDuration(_audioDuration)}',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: AppTheme.accent.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: current,
              min: 0,
              max: total > 0 ? total : 1.0,
              onChanged: (val) {
                _audioPlayer?.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Başa al
              GestureDetector(
                onTap: () => _audioPlayer?.seek(Duration.zero),
                child: const Icon(Icons.replay_rounded, size: 18, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              // Oynat/Durdur
              GestureDetector(
                onTap: () async {
                  setState(() => _audioMuted = !_audioMuted);
                  if (_audioMuted) {
                    await _audioPlayer?.pause();
                  } else {
                    await _audioPlayer?.play();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _audioMuted
                        ? Colors.red.withValues(alpha: 0.7)
                        : AppTheme.accent.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _audioMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 10sn ileri
              GestureDetector(
                onTap: () {
                  final next = _audioPosition + const Duration(seconds: 10);
                  if (next < _audioDuration) _audioPlayer?.seek(next);
                },
                child: const Icon(Icons.forward_10_rounded, size: 18, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Ses Seviyesi Kontrolü
          Row(
            children: [
              const Icon(Icons.volume_down_rounded, size: 14, color: Colors.white54),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.white70,
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: _audioVolume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() {
                        _audioVolume = val;
                      });
                      _audioPlayer?.setVolume(val);
                    },
                  ),
                ),
              ),
              const Icon(Icons.volume_up_rounded, size: 14, color: Colors.white54),
            ],
          ),
        ],
      ),
    );
  }

  // Kayıt sırasında prompter kontrol paneli (üstte şeffaf)
  Widget _buildRecordingPrompterControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Durdur/Devam et
          GestureDetector(
            onTap: _togglePrompterPause,
            child: Row(
              children: [
                Icon(
                  _isPrompterPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 18,
                  color: _isPrompterPaused ? AppTheme.accent : Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  _isPrompterPaused ? 'Devam' : 'Durdur',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _isPrompterPaused ? AppTheme.accent : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Yeniden Başlat
          GestureDetector(
            onTap: () {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(0);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.replay_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Yeniden Başlat',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.format_size, size: 13, color: Colors.white54),
          const SizedBox(width: 4),
          SizedBox(
            width: 90,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: Colors.white70,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _fontSize,
                min: 18.0,
                max: 36.0,
                onChanged: (val) => setState(() => _fontSize = val),
              ),
            ),
          ),
          // Hız
          const Icon(Icons.speed, size: 13, color: Colors.white54),
          const SizedBox(width: 4),
          SizedBox(
            width: 80,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                activeTrackColor: AppTheme.accent,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppTheme.accent,
              ),
              child: Slider(
                value: _scrollSpeed,
                min: 1.0,
                max: 5.0,
                divisions: 8,
                onChanged: (val) => setState(() => _scrollSpeed = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Metin Düzenleme Dialogu
  void _editScriptDialog() {
    if (_isRecording || _isCountingDown) return;

    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController(text: _scriptController.text);
        return AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          title: Text(
            'Prompter Metni Düzenle',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: textController,
              maxLines: 8,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Buraya seslendirmek istediğiniz metni yazın...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                fillColor: AppTheme.surfaceLight,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _scriptController.text = textController.text;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 56, color: AppTheme.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  child: const Text('Geri Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    final isPortrait = MediaQuery.of(context).size.height > MediaQuery.of(context).size.width;
    final isPrompterActive = _isPrompterOpen && !isPortrait && !widget.isMimicMode;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Kamera Önizleme (Tam Ekran)
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // 2. Yönlendirme / Yatay Tutma Uyarısı (Portre Modunda üstte şık bir şerit olarak gösterilir)
          if (isPortrait)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.screen_rotation,
                      size: 24,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Lütfen Cihazı Yatay Tutun\nKayıt sadece yatay (landscape) modda başlatılabilir.',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Geri Sayım Pulsing Overlay
          if (_isCountingDown && !isPortrait)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent, width: 3),
                    ),
                    child: Center(
                      child: Text(
                        '$_currentCountdown',
                        style: GoogleFonts.outfit(
                          fontSize: 64,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 3.5 MİMİK REHBERİ BANNERI (Kayıt sırasında altta şık ve küçük bir kart olarak gösterilir)
          if (widget.isMimicMode && _isRecording && !isPortrait && _currentMimicText.isNotEmpty)
            Positioned(
              bottom: 105,
              left: MediaQuery.of(context).size.width * 0.20,
              right: MediaQuery.of(context).size.width * 0.20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.face_retouching_natural, color: AppTheme.accent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'MİMİK TALİMATI',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: Text(
                          _currentMimicText,
                          key: ValueKey(_currentMimicText),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      MimicProgressTimer(duration: const Duration(seconds: 5)),
                    ],
                  ),
                ),
              ),
            ),

          // 4. TELEPROMPTER PANELI (Fullscreen & Transparan)
          if (isPrompterActive)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
                child: Stack(
                  children: [
                    // Kayma metin alanı
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 60, bottom: 60),
                        child: _scriptController.text.isEmpty
                            ? Center(
                                child: GestureDetector(
                                  onTap: _editScriptDialog,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.edit_note, color: Colors.white54, size: 40),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Metin girilmemiş. Eklemek için tıklayın.',
                                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                controller: _scrollController,
                                physics: const NeverScrollableScrollPhysics(),
                                child: Center(
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width * 0.40, // Orta 1/3'lük alan
                                    child: Column(
                                      children: [
                                        // Üst boşluk (Metnin en alttan gelmesini sağlar)
                                        SizedBox(height: MediaQuery.of(context).size.height * 0.70),
                                        Text(
                                          _scriptController.text,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: _fontSize,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            height: 1.8,
                                            shadows: [
                                              const Shadow(
                                                offset: Offset(1.5, 1.5),
                                                blurRadius: 5.0,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Alt boşluk (Metnin yukarı kayıp kaybolmasını sağlar)
                                        SizedBox(height: MediaQuery.of(context).size.height),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),

                      // Prompter Üst Barı (Kontroller & Düzenle Butonu)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 44,
                        child: Container(
                          color: Colors.black38,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.description, size: 16, color: AppTheme.accent),
                              const SizedBox(width: 6),
                              Text(
                                'TELEPROMPTER',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const Spacer(),
                              if (!_isRecording) ...[
                                TextButton.icon(
                                  onPressed: () {
                                    if (_scrollController.hasClients) {
                                      _scrollController.jumpTo(0);
                                    }
                                  },
                                  icon: const Icon(Icons.replay_rounded, size: 14, color: AppTheme.accent),
                                  label: Text(
                                    'Yeniden Başlat',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accent),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: _editScriptDialog,
                                  icon: const Icon(Icons.edit_outlined, size: 14, color: AppTheme.accent),
                                  label: Text(
                                    'Düzenle',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.accent),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Prompter Alt Barı (Hız ve Boyut Ayarları)
                      if (!_isRecording && !widget.isMimicMode)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 48,
                          child: Container(
                            color: Colors.black38,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Hız Slider
                                const Icon(Icons.speed, size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Slider(
                                    value: _scrollSpeed,
                                    min: 1.0,
                                    max: 5.0,
                                    divisions: 8,
                                    activeColor: AppTheme.accent,
                                    inactiveColor: Colors.white24,
                                    onChanged: (val) {
                                      setState(() {
                                        _scrollSpeed = val;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Font Boyut Slider
                                const Icon(Icons.format_size, size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Slider(
                                    value: _fontSize,
                                    min: 18.0,
                                    max: 36.0,
                                    activeColor: AppTheme.accent,
                                    inactiveColor: Colors.white24,
                                    onChanged: (val) {
                                      setState(() {
                                        _fontSize = val;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

          // 5. YAN/ALT KONTROL PANELİ
          if (!isPortrait && !_isCountingDown)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Sol Taraf: Geri Sayım Ayarı ve Prompter Switch (Kayıt sırasında gizlenir)
                    if (!_isRecording)
                      widget.isMimicMode
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.face, size: 14, color: AppTheme.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mimik Kaydı Modu',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                // Geri Sayım Chip'i
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.timer_outlined, size: 14, color: Colors.white70),
                                      const SizedBox(width: 4),
                                      DropdownButton<int>(
                                        value: _countdownSeconds,
                                        dropdownColor: Colors.black87,
                                        underline: const SizedBox(),
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _countdownSeconds = val;
                                            });
                                          }
                                        },
                                        items: const [
                                          DropdownMenuItem(value: 0, child: Text('Süre Yok')),
                                          DropdownMenuItem(value: 3, child: Text('3 sn')),
                                          DropdownMenuItem(value: 5, child: Text('5 sn')),
                                          DropdownMenuItem(value: 10, child: Text('10 sn')),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Prompter Toggle
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _isPrompterOpen = !_isPrompterOpen;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _isPrompterOpen ? AppTheme.accent : Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          _isPrompterOpen ? Icons.visibility : Icons.visibility_off,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Prompter',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                    else
                        // Kayıt sırasında: Dikey yapı (Kırmızı badge + Prompter ctrl + Ses bar)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Kırmızı KAYIT YAPILIYOR badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.circle, size: 8, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    'KAYIT YAPILIYOR',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Prompter kontrollü
                            if (_isPrompterOpen && _scriptController.text.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildRecordingPrompterControls(),
                            ],
                            // Ses barı
                            if (_hasBackgroundAudio) ...[
                              const SizedBox(height: 6),
                              _buildAudioBar(),
                            ],
                          ],
                        ),

                    // Merkez: KAYIT BUTONU
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _startRecordWorkflow,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: Container(
                            width: _isRecording ? 28 : 54,
                            height: _isRecording ? 28 : 54,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(_isRecording ? 6 : 27),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Sağ Taraf: Kamera Değiştir (Kayıt sırasında gizlenir) veya Boş Spacer
                    if (!_isRecording)
                      IconButton(
                        onPressed: _toggleCamera,
                        icon: const Icon(Icons.flip_camera_ios, size: 28, color: Colors.white),
                      )
                    else
                      const SizedBox(width: 48), // Denge için boşluk
                  ],
                ),
              ),
            ),

          // 6. Geri Dön Butonu (Sol Üst)
          if (!_isRecording && !_isCountingDown)
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

          // 7. Ses Açma/Kapama Butonu — Sağ Üst (her zaman görünür, arka plan sesi varsa)
          if (_hasBackgroundAudio)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _audioMuted = !_audioMuted);
                    if (_audioMuted) {
                      await _audioPlayer?.pause();
                    } else if (_isRecording) {
                      await _audioPlayer?.play();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _audioMuted
                          ? Colors.red.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _audioMuted
                            ? Colors.red.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _audioMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _audioMuted ? 'Ses Kapalı' : 'Ses Açık',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MimicProgressTimer extends StatefulWidget {
  final Duration duration;
  const MimicProgressTimer({super.key, required this.duration});

  @override
  State<MimicProgressTimer> createState() => _MimicProgressTimerState();
}

class _MimicProgressTimerState extends State<MimicProgressTimer> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: widget.duration);
    _animController.forward();
  }

  @override
  void didUpdateWidget(MimicProgressTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _animController.reset();
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return SizedBox(
          width: 240,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _animController.value,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 4,
            ),
          ),
        );
      },
    );
  }
}
