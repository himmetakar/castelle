import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Splash Screen
/// Ali Imam - Fragment Shader Animasyonlu Premium Açılış Ekranı (Beyaz Tema & Tam Ekran Ölçekli)

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static bool splashPassed = false;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late AnimationController _timeController;
  bool _shaderLoadError = false;

  @override
  void initState() {
    super.initState();
    SplashScreen.splashPassed = false;
    // Shader zaman animasyonu için controller
    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _loadShader();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/shader.frag');
      if (mounted) {
        setState(() {
          _shader = program.fragmentShader();
        });
      }
    } catch (e) {
      debugPrint("Shader yüklenirken hata oluştu: $e");
      if (mounted) {
        setState(() {
          _shaderLoadError = true;
        });
      }
    }
  }

  Future<void> _initializeApp() async {
    // 1. Giriş durumunu arka planda hemen kontrol etmeye başla
    final authProvider = context.read<AuthProvider>();
    final checkAuthFuture = authProvider.checkAuthStatus();

    // 2. Tam olarak 2 saniye bekle
    await Future.delayed(const Duration(seconds: 2));

    // 3. Giriş durumunun tamamlanmasını bekle
    await checkAuthFuture;

    if (!mounted) return;

    // 4. Splash ekranının bittiğini işaretle ve yönlendir
    SplashScreen.splashPassed = true;
    
    if (authProvider.status == AuthStatus.authenticated) {
      context.go('/home');
    } else {
      final prefs = await SharedPreferences.getInstance();
      final showOnboarding = prefs.getBool('show_onboarding') ?? true;
      if (showOnboarding) {
        context.go('/onboarding');
      } else {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Shader Animasyonu Arka Planı (veya hata durumunda düz beyaz arka plan)
          Positioned.fill(
            child: _shader != null
                ? AnimatedBuilder(
                    animation: _timeController,
                    builder: (context, child) {
                      // Zaman değeri (saniyeler içinde sürekli artan değer)
                      final double time = _timeController.value * 60.0;
                      return CustomPaint(
                        painter: ShaderPainter(
                          shader: _shader!,
                          time: time,
                          devicePixelRatio: devicePixelRatio,
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.white,
                  ),
          ),

          // Yazılar ve Yükleniyor (Ön Planda)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/ana-logo-siyah.png',
                  height: 60,
                  fit: BoxFit.contain,
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 800.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 800.ms,
                      curve: Curves.elasticOut,
                    ),

                const SizedBox(height: 48),

                // Yükleniyor Göstergesi
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primary,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shader Painter
class ShaderPainter extends CustomPainter {
  ShaderPainter({
    required this.shader,
    required this.time,
    required this.devicePixelRatio,
  });

  final ui.FragmentShader shader;
  final double time;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    // Physical pixels mapping to avoid scaling and centering issues:
    // uniform vec2 uResolution; -> index 0 (width), index 1 (height)
    // uniform float uTime;      -> index 2
    shader.setFloat(0, size.width * devicePixelRatio);
    shader.setFloat(1, size.height * devicePixelRatio);
    shader.setFloat(2, time);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant ShaderPainter oldDelegate) {
    return oldDelegate.time != time || oldDelegate.devicePixelRatio != devicePixelRatio;
  }
}
