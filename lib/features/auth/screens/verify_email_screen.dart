import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - E-posta Aktivasyon Ekranı
/// Normal e-posta/şifre ile kaydolan kullanıcılar, e-postalarındaki aktivasyon
/// linkine tıklayana kadar bu ekranda tutulur ve uygulama verisine erişemez.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _autoCheckTimer;
  bool _isChecking = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Kullanıcı e-postasındaki linke tıklayıp uygulamaya geri döndüğünde
    // otomatik olarak fark edilmesi için periyodik kontrol.
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkVerification(silent: true));
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    final authProvider = context.read<AuthProvider>();
    final verified = await authProvider.refreshEmailVerification();
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!verified && !silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('E-posta adresiniz henüz doğrulanmamış görünüyor. Lütfen önce aktivasyon linkine tıklayın.'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    // verified == true olduğunda GoRouter, AuthProvider'ı dinlediği için
    // otomatik olarak /home yönlendirmesini tetikleyecektir.
  }

  Future<void> _resendEmail() async {
    if (_resendCooldown > 0 || _isResending) return;
    setState(() => _isResending = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resendVerificationEmail();
    if (!mounted) return;
    setState(() => _isResending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Aktivasyon e-postası tekrar gönderildi.'
              : (authProvider.errorMessage ?? 'E-posta gönderilirken bir hata oluştu.'),
        ),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    if (success) {
      setState(() => _resendCooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _resendCooldown--;
          if (_resendCooldown <= 0) timer.cancel();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final email = authProvider.user?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9FAFB), Color(0xFFF3F4F6)],
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
                  padding: const EdgeInsets.all(32),
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
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_unread_outlined, color: AppTheme.accent, size: 38),
                      ).animate().scale(begin: const Offset(0.85, 0.85), duration: 500.ms, curve: Curves.elasticOut),

                      const SizedBox(height: 22),

                      Text(
                        'E-posta Adresinizi Doğrulayın',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 21, fontWeight: FontWeight.bold, color: const Color(0xFF111827)),
                      ),
                      const SizedBox(height: 10),

                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF4B5563), height: 1.5),
                          children: [
                            const TextSpan(text: 'Hesabınızı etkinleştirmek için '),
                            TextSpan(
                              text: email.isNotEmpty ? email : 'e-posta adresinize',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                            const TextSpan(
                              text: ' gönderdiğimiz aktivasyon linkine tıklayın. E-postayı birkaç dakika içinde görmüyorsanız, lütfen spam/gereksiz klasörünüzü de kontrol edin.',
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 24),

                      // Linke tıkladım / Kontrol Et
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          onPressed: _isChecking ? null : () => _checkVerification(silent: false),
                          child: _isChecking
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : Text(
                                  'Linke Tıkladım, Kontrol Et',
                                  style: GoogleFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Tekrar Gönder
                      TextButton(
                        onPressed: (_resendCooldown > 0 || _isResending) ? null : _resendEmail,
                        child: Text(
                          _resendCooldown > 0
                              ? 'Tekrar Gönder ($_resendCooldown sn)'
                              : (_isResending ? 'Gönderiliyor...' : 'Aktivasyon E-postasını Tekrar Gönder'),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      const Divider(color: Color(0xFFE5E7EB)),
                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: () => context.read<AuthProvider>().signOut(),
                        child: Text(
                          'Farklı bir hesapla giriş yap',
                          style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF6B7280)),
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
