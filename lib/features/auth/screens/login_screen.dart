import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Login Screen
/// Gmail / Google ile Giriş Ekranı

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGoogleLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();
    if (mounted) setState(() => _isGoogleLoading = false);

    if (!success && mounted && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading || _isGoogleLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF9FAFB),
              Color(0xFFF3F4F6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Top Glow Accent
                      Positioned(
                        top: -90,
                        left: -50,
                        right: -50,
                        child: Container(
                          height: 220,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.primary.withValues(alpha: 0.12),
                                AppTheme.primary.withValues(alpha: 0.03),
                                Colors.transparent,
                              ],
                              radius: 0.9,
                            ),
                          ),
                        ),
                      ),

                      // Card Content
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Logo
                            Image.asset(
                              'assets/images/ana-logo-siyah.png',
                              height: 48,
                              fit: BoxFit.contain,
                            ).animate().scale(
                                  begin: const Offset(0.85, 0.85),
                                  duration: 600.ms,
                                  curve: Curves.elasticOut,
                                ),
                            const SizedBox(height: 16),

                            // Header Text
                            Text(
                              'Castelle\'e Hoş Geldiniz',
                              style: GoogleFonts.outfit(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1),
                            const SizedBox(height: 8),
                            Text(
                              'Premium Casting SaaS Platformu’na Gmail hesabınız ile anında giriş yapın.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                color: const Color(0xFF6B7280),
                                height: 1.4,
                              ),
                            ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),

                            const SizedBox(height: 32),

                            // --- GMAIL / GOOGLE ILE GIRIS BUTONU ---
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: isLoading ? null : _handleGoogleSignIn,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: isLoading
                                          ? const Center(
                                              child: SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: AppTheme.primary,
                                                ),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const _GoogleLogoSvg(size: 24),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Gmail ile Giriş Yap',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF1F2937),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ).animate().fadeIn(delay: 350.ms).scale(begin: const Offset(0.96, 0.96)),

                            const SizedBox(height: 20),

                            // Security Info Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF059669)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Google OAuth 2.0 ile yüksek güvenlikli kimlik doğrulama',
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        color: const Color(0xFF4B5563),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: 450.ms),

                            const SizedBox(height: 28),

                            // Register redirect link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Henüz hesabınız yok mu? ',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.go('/register'),
                                  child: Text(
                                    'Kayıt Ol',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 500.ms),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google Multi-Color SVG Logo
class _GoogleLogoSvg extends StatelessWidget {
  final double size;
  const _GoogleLogoSvg({this.size = 24});

  @override
  Widget build(BuildContext context) {
    const String svgString = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24s.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';
    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}
