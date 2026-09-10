import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Login Screen
/// Sadece SMS / Telefon Numarası ile Giriş Ekranı (Şifresiz ve E-postasız)

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.sendPhoneOtp(_phoneController.text.trim());

    if (success && mounted && authProvider.codeSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS doğrulama kodu telefonunuza gönderildi.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'SMS kodu gönderilemedi.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _handleVerifyOtp() async {
    if (!_otpFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyPhoneOtp(_otpController.text.trim());

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'SMS doğrulama kodu geçersiz.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final codeSent = authProvider.codeSent;

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
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Top Glow Effect
                      Positioned(
                        top: -80,
                        left: -40,
                        right: -40,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.primary.withOpacity(0.12),
                                AppTheme.primary.withOpacity(0.04),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo
                            Center(
                              child: Image.asset(
                                'assets/images/ana-logo-siyah.png',
                                height: 45,
                                fit: BoxFit.contain,
                              ).animate().scale(
                                    begin: const Offset(0.8, 0.8),
                                    duration: 600.ms,
                                    curve: Curves.elasticOut,
                                  ),
                            ),
                            const SizedBox(height: 12),

                            // Welcoming text
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Hoş Geldiniz',
                                    style: GoogleFonts.outfit(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF111827),
                                    ),
                                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                                  const SizedBox(height: 6),
                                  Text(
                                    codeSent
                                        ? 'Telefonunuza gelen 6 haneli SMS kodunu girin.'
                                        : 'Telefon numaranız ile tek kullanımlık SMS kodu alarak giriş yapın.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // --- SMS İLE GİRİŞ AKIŞI ---
                            if (!codeSent) ...[
                              // ADIM 1: Telefon Numarası Girme
                              Form(
                                key: _phoneFormKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Telefon Numarası',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _handleSendOtp(),
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF111827),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: const Color(0xFFF9FAFB),
                                        hintText: '05XX XXX XX XX',
                                        hintStyle: GoogleFonts.inter(
                                          color: const Color(0xFF9CA3AF),
                                          fontSize: 14,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.phone_android_rounded,
                                          color: Color(0xFF9CA3AF),
                                          size: 20,
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Telefon numarası gerekli';
                                        }
                                        final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
                                        if (clean.length < 10) {
                                          return 'Geçerli 10 haneli telefon numarası girin (ör: 05551234567)';
                                        }
                                        return null;
                                      },
                                    ).animate().fadeIn(delay: 400.ms),

                                    const SizedBox(height: 24),

                                    // SMS Kodu Gönder Butonu
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primary,
                                              AppTheme.primary.withOpacity(0.85),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primary.withOpacity(0.18),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: authProvider.isLoading ? null : _handleSendOtp,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: authProvider.isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.sms_outlined, size: 20),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'SMS Kodu Gönder',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w600,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ).animate().fadeIn(delay: 500.ms),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // ADIM 2: 6 Haneli OTP Kodunu Girme
                              Form(
                                key: _otpFormKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Gönderilen telefon uyarısı
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.mark_email_read, size: 20, color: AppTheme.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'SMS Kodu Gönderildi:\n${authProvider.phoneNumber ?? _phoneController.text}',
                                              style: GoogleFonts.inter(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              authProvider.resetPhoneAuth();
                                              _otpController.clear();
                                            },
                                            child: Text(
                                              'Değiştir',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    Text(
                                      '6 Haneli SMS Doğrulama Kodu',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF374151),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _otpController,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.done,
                                      maxLength: 6,
                                      onFieldSubmitted: (_) => _handleVerifyOtp(),
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF111827),
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 8,
                                      ),
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        counterText: '',
                                        filled: true,
                                        fillColor: const Color(0xFFF9FAFB),
                                        hintText: '••••••',
                                        hintStyle: GoogleFonts.inter(
                                          color: const Color(0xFF9CA3AF),
                                          fontSize: 20,
                                          letterSpacing: 4,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().length < 6) {
                                          return '6 haneli kodu eksiksiz girin';
                                        }
                                        return null;
                                      },
                                    ).animate().fadeIn(delay: 300.ms),

                                    const SizedBox(height: 20),

                                    // Doğrula & Giriş Yap Butonu
                                    SizedBox(
                                      width: double.infinity,
                                      height: 50,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          gradient: LinearGradient(
                                            colors: [
                                              AppTheme.primary,
                                              AppTheme.primary.withOpacity(0.85),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primary.withOpacity(0.18),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: authProvider.isLoading ? null : _handleVerifyOtp,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shadowColor: Colors.transparent,
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                          child: authProvider.isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : Text(
                                                  'Doğrula ve Giriş Yap',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.2,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ).animate().fadeIn(delay: 400.ms),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 28),

                            // Kayıt ol yönlendirmesi
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Hesabınız yok mu? ',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.go('/register'),
                                    child: Text(
                                      'Kayıt Ol',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
