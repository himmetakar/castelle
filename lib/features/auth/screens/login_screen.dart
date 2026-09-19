import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Login Screen
/// Gmail ve E-posta / Şifre ile Giriş Ekranı

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _showEmailForm = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle();
    if (mounted) setState(() => _isGoogleLoading = false);

    if (!success && mounted) {
      // Bu Gmail hesabıyla ilk kez giriş yapılıyor — daha önce kayıt/giriş
      // ekranında sorulan 18 yaş kontrolü bu akışta atlanmıştı. Hesabı
      // tamamlamadan önce burada da aynı soruyu sormamız gerekiyor.
      if (authProvider.pendingGoogleUser != null) {
        await _showGoogleAgeVerificationDialog();
        return;
      }
      if (authProvider.errorMessage != null) {
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
  }

  /// Google ile ilk kez giriş yapan (yeni) bir kullanıcı için 18 yaş / veli
  /// bilgisi dialog'unu gösterir. Normal e-posta kaydındaki ile aynı kuralı uygular.
  Future<void> _showGoogleAgeVerificationDialog() async {
    bool? isOver18;
    final guardianNameController = TextEditingController();
    final guardianPhoneController = TextEditingController();
    final dialogFormKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Yaş Doğrulama', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Form(
                  key: dialogFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hesabınızı oluşturmadan önce lütfen yaş durumunuzu belirtin.',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isOver18 == true ? AppTheme.primary.withValues(alpha: 0.08) : null,
                                side: BorderSide(color: isOver18 == true ? AppTheme.primary : const Color(0xFFD1D5DB)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => setDialogState(() => isOver18 = true),
                              child: Text('18 Yaşından Büyüğüm', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isOver18 == false ? AppTheme.primary.withValues(alpha: 0.08) : null,
                                side: BorderSide(color: isOver18 == false ? AppTheme.primary : const Color(0xFFD1D5DB)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => setDialogState(() => isOver18 = false),
                              child: Text('18 Yaşından Küçüğüm', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      if (isOver18 == false) ...[
                        const SizedBox(height: 16),
                        Text(
                          '18 yaşından küçük kullanıcıların kaydolabilmesi için veli bilgileri zorunludur.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: guardianNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Veli Ad Soyadı *'),
                          validator: (val) => (isOver18 == false && (val == null || val.trim().isEmpty))
                              ? 'Lütfen velinizin ad soyadını girin.'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: guardianPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Veli Telefon Numarası *'),
                          validator: (val) => (isOver18 == false && (val == null || val.trim().isEmpty))
                              ? 'Lütfen velinizin telefon numarasını girin.'
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (isOver18 == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Lütfen yaş durumunuzu seçin.')),
                      );
                      return;
                    }
                    if (!dialogFormKey.currentState!.validate()) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Devam Et'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();

    if (confirmed == true) {
      setState(() => _isGoogleLoading = true);
      final success = await authProvider.completeGoogleRegistration(
        isUnder18: isOver18 == false,
        guardianName: isOver18 == false ? guardianNameController.text.trim() : null,
        guardianPhone: isOver18 == false ? guardianPhoneController.text.trim() : null,
      );
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
    } else {
      await authProvider.cancelPendingGoogleRegistration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kayıt tamamlanmadı. Devam etmek için yaş bilginizi onaylamanız gerekir.'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (mounted) setState(() => _isEmailLoading = false);

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

  Future<void> _handleForgotPassword() async {
    final resetEmailController = TextEditingController(text: _emailController.text);
    final dialogFormKey = GlobalKey<FormState>();

    final dialogResult = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Şifremi Unuttum', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Form(
          key: dialogFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Şifre sıfırlama bağlantısı almak için kaydolduğunuz e-posta adresini girin.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF4B5563)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'E-posta Adresi',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Lütfen e-posta adresinizi girin.';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (dialogFormKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );

    if (dialogResult == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.resetPassword(resetEmailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Şifre sıfırlama e-postası gönderildi. Lütfen e-postanızı kontrol edin.'
                  : (authProvider.errorMessage ?? 'Hata oluştu.'),
            ),
            backgroundColor: success ? AppTheme.success : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading || _isGoogleLoading || _isEmailLoading;

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
                              'Premium Casting SaaS Platformu’na Gmail veya E-posta hesabınız ile giriş yapın.',
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
                              height: 52,
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
                                      child: _isGoogleLoading
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
                                                const _GoogleLogoSvg(size: 22),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Gmail ile Giriş Yap',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15.5,
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

                            // DIVIDER
                            Row(
                              children: [
                                const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    'ya da',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF9CA3AF),
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider(color: Color(0xFFE5E7EB), thickness: 1)),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // EMAIL WITH PASSWORD FORM / BUTTON
                            if (!_showEmailForm)
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppTheme.primary, width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: () => setState(() => _showEmailForm = true),
                                  icon: const Icon(Icons.mail_outline_rounded, color: AppTheme.primary, size: 20),
                                  label: Text(
                                    'E-posta ile Giriş Yap',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: 400.ms)
                            else
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // E-posta Field
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: const InputDecoration(
                                        labelText: 'E-posta Adresi',
                                        hintText: 'ornek@email.com',
                                        prefixIcon: Icon(Icons.email_outlined),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Lütfen e-posta adresinizi girin.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Şifre Field
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      decoration: InputDecoration(
                                        labelText: 'Şifre',
                                        prefixIcon: const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          ),
                                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                        ),
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Lütfen şifrenizi girin.';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 8),

                                    // Şifremi Unuttum Button
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _handleForgotPassword,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Şifremi Unuttum?',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Giriş Yap Submit Button
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
                                        onPressed: isLoading ? null : _handleEmailSignIn,
                                        child: _isEmailLoading
                                            ? const SizedBox(
                                                width: 22,
                                                height: 22,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Text(
                                                'Giriş Yap',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().fadeIn(duration: 300.ms),

                            const SizedBox(height: 24),

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
                                      'Güvenli SSL ve 256-bit şifrelenmiş kimlik doğrulama',
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
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';
    return SvgPicture.string(
      svgString,
      width: size,
      height: size,
    );
  }
}
