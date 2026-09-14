import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/widgets/policy_dialogs.dart';

/// Castelle - Register Screen
/// Gmail ile Kayıt Ol Ekranı

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _isGoogleLoading = false;

  bool _acceptedKvkk = false;
  bool _acceptedTermsAndPrivacy = false;
  bool _acceptedDataProcessing = false;
  bool _acceptedProfileSharing = false;
  bool _acceptedAuditionSharing = false;
  bool _acceptedMarketingUse = false;

  Future<void> _handleGoogleRegister() async {
    if (!_acceptedKvkk ||
        !_acceptedTermsAndPrivacy ||
        !_acceptedDataProcessing ||
        !_acceptedProfileSharing ||
        !_acceptedAuditionSharing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Kayıt için lütfen tüm zorunlu metin onaylarını ve açık rızaları verin.'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
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
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button & Header Title
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => context.go('/login'),
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Color(0xFF111827),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Hesap Oluştur',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 400.ms),

                        const SizedBox(height: 6),

                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: Text(
                            'Castelle platformuna Gmail hesabınız ile tek tıkla katılarak profilinizi oluşturun.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 24),

                        // Yasal Onaylar & Açık Rıza Kartı
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.gavel_outlined, size: 18, color: AppTheme.accent),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Yasal Onaylar & Açık Rıza Metinleri',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // 1. KVKK Aydınlatma Metni
                              _buildCheckboxItem(
                                value: _acceptedKvkk,
                                onChanged: (val) => setState(() => _acceptedKvkk = val ?? false),
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF374151), height: 1.35),
                                    children: [
                                      WidgetSpan(
                                        child: InkWell(
                                          onTap: () => PolicyDialogs.showKvkk(context),
                                          child: const Text(
                                            'KVKK Aydınlatma Metni',
                                            style: TextStyle(
                                              color: AppTheme.accent,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: '’ni okudum ve bilgi edindim.'),
                                    ],
                                  ),
                                ),
                              ),

                              // 2. Kullanım Koşulları & Gizlilik Politikası
                              _buildCheckboxItem(
                                value: _acceptedTermsAndPrivacy,
                                onChanged: (val) => setState(() => _acceptedTermsAndPrivacy = val ?? false),
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF374151), height: 1.35),
                                    children: [
                                      WidgetSpan(
                                        child: InkWell(
                                          onTap: () => PolicyDialogs.showTermsOfUse(context),
                                          child: const Text(
                                            'Kullanım Koşulları',
                                            style: TextStyle(
                                              color: AppTheme.accent,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: ' ve '),
                                      WidgetSpan(
                                        child: InkWell(
                                          onTap: () => PolicyDialogs.showPrivacyPolicy(context),
                                          child: const Text(
                                            'Gizlilik Politikası',
                                            style: TextStyle(
                                              color: AppTheme.accent,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const TextSpan(text: '’nı okudum ve kabul ediyorum.'),
                                    ],
                                  ),
                                ),
                              ),

                              // 3. Hizmet Kapsamında Kişisel Veri İşleme
                              _buildCheckboxItem(
                                value: _acceptedDataProcessing,
                                onChanged: (val) => setState(() => _acceptedDataProcessing = val ?? false),
                                child: Text(
                                  'Kişisel verilerimin Castelle hizmetlerinin sunulması amacıyla Aydınlatma Metni’nde belirtilen kapsamda işlenmesini kabul ediyorum.',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF374151), height: 1.35),
                                ),
                              ),

                              // 4. Profil ve Görsel İçeriklerin Paylaşılması
                              _buildCheckboxItem(
                                value: _acceptedProfileSharing,
                                onChanged: (val) => setState(() => _acceptedProfileSharing = val ?? false),
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF374151), height: 1.35),
                                    children: [
                                      const TextSpan(
                                          text:
                                              'Oyunculuk profilimde bulunan fotoğraf, video, CV, showreel ve mesleki bilgilerimin, başvurduğum projeler kapsamında yapımcı, yönetmen ve yetkili sektör profesyonelleri tarafından görüntülenmesine '),
                                      WidgetSpan(
                                        child: InkWell(
                                          onTap: () => PolicyDialogs.showExplicitConsent(context),
                                          child: const Text(
                                            'açık rıza veriyorum.',
                                            style: TextStyle(
                                              color: AppTheme.accent,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 5. Deneme Çekimlerinin Paylaşılması
                              _buildCheckboxItem(
                                value: _acceptedAuditionSharing,
                                onChanged: (val) => setState(() => _acceptedAuditionSharing = val ?? false),
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF374151), height: 1.35),
                                    children: [
                                      const TextSpan(
                                          text:
                                              'Castelle üzerinden gerçekleştirdiğim deneme çekimlerinin, başvurduğum projelerin oyuncu seçme ve değerlendirme süreçlerinde ilgili proje yetkilileriyle paylaşılmasına '),
                                      WidgetSpan(
                                        child: InkWell(
                                          onTap: () => PolicyDialogs.showExplicitConsent(context),
                                          child: const Text(
                                            'açık rıza veriyorum.',
                                            style: TextStyle(
                                              color: AppTheme.accent,
                                              fontWeight: FontWeight.bold,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 6. Tanıtım ve Pazarlama Amaçlı Kullanım (İsteğe Bağlı)
                              _buildCheckboxItem(
                                value: _acceptedMarketingUse,
                                isOptional: true,
                                onChanged: (val) => setState(() => _acceptedMarketingUse = val ?? false),
                                child: Text(
                                  'Fotoğraf, video ve diğer içeriklerimin Castelle’nin reklam, tanıtım ve sosyal medya faaliyetlerinde kullanılmasına açık rıza veriyorum. (İsteğe bağlı)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: const Color(0xFF6B7280),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 350.ms),

                        const SizedBox(height: 24),

                        // --- GMAIL ILE KAYIT OL BUTONU ---
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
                                onTap: isLoading ? null : _handleGoogleRegister,
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
                                              'Gmail ile Kayıt Ol',
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
                        ).animate().fadeIn(delay: 450.ms),

                        const SizedBox(height: 24),

                        // Login Redirection Link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Zaten hesabınız var mı? ',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Giriş Yap',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 550.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxItem({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget child,
    bool isOptional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: value,
              activeColor: AppTheme.accent,
              checkColor: AppTheme.textOnAccent,
              side: BorderSide(
                color: isOptional ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.accent,
                width: 1.5,
              ),
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
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
