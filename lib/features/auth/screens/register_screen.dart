import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/widgets/policy_dialogs.dart';

/// Castelle - Register Screen
/// Premium kayıt ekranı - Rol seçimli

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  UserRole _selectedRole = UserRole.actor;
  bool _acceptedKvkk = false;
  bool _acceptedTermsAndPrivacy = false;
  bool _acceptedDataProcessing = false;
  bool _acceptedProfileSharing = false;
  bool _acceptedAuditionSharing = false;
  bool _acceptedMarketingUse = false; // İsteğe bağlı

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptedKvkk ||
        !_acceptedTermsAndPrivacy ||
        !_acceptedDataProcessing ||
        !_acceptedProfileSharing ||
        !_acceptedAuditionSharing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt için lütfen tüm zorunlu metin onaylarını ve açık rızaları verin.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
      phone: _phoneController.text,
      role: _selectedRole.value,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Kayıt başarısız.'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

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
                        color: Colors.black.withOpacity(0.04),
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
                        // Geri butonu ve Başlık
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
                            const SizedBox(width: 8),
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

                        Text(
                          'Castelle platformuna katılın ve oyunculuk dünyasında yerinizi alın.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF6B7280),
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 24),

                        // Form
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ad Soyad
                              TextFormField(
                                controller: _fullNameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                style: GoogleFonts.inter(color: const Color(0xFF111827), fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Ad Soyad',
                                  hintText: 'Adınız ve soyadınız',
                                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Ad soyad gerekli';
                                  }
                                  if (value.trim().length < 3) {
                                    return 'En az 3 karakter girin';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 350.ms),

                              const SizedBox(height: 16),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: GoogleFonts.inter(color: const Color(0xFF111827), fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'E-posta',
                                  hintText: 'ornek@email.com',
                                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'E-posta gerekli';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                      .hasMatch(value)) {
                                    return 'Geçerli bir e-posta girin';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 400.ms),

                              const SizedBox(height: 16),

                              // Telefon
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                style: GoogleFonts.inter(color: const Color(0xFF111827), fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Telefon',
                                  hintText: '05XX XXX XX XX',
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Telefon numarası gerekli';
                                  }
                                  if (value.replaceAll(RegExp(r'[^0-9]'), '').length <
                                      10) {
                                    return 'Geçerli bir telefon numarası girin';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 450.ms),

                              const SizedBox(height: 16),

                              // Şifre
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                style: GoogleFonts.inter(color: const Color(0xFF111827), fontSize: 14),
                                decoration: InputDecoration(
                                  labelText: 'Şifre',
                                  hintText: 'En az 6 karakter',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Şifre gerekli';
                                  }
                                  if (value.length < 6) {
                                    return 'Şifre en az 6 karakter olmalı';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 500.ms),

                              const SizedBox(height: 16),

                              // Şifre Tekrar
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                style: GoogleFonts.inter(color: const Color(0xFF111827), fontSize: 14),
                                onFieldSubmitted: (_) => _handleRegister(),
                                decoration: InputDecoration(
                                  labelText: 'Şifre Tekrar',
                                  hintText: 'Şifrenizi tekrar girin',
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  filled: true,
                                  fillColor: const Color(0xFFF9FAFB),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Şifre tekrarı gerekli';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Şifreler eşleşmiyor';
                                  }
                                  return null;
                                },
                              ).animate().fadeIn(delay: 550.ms),

                              const SizedBox(height: 20),

                              // Yasal Onaylar Kartı
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Yasal Onaylar & Açık Rıza Metinleri',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

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

                                    // 6. Tanıtım ve Pazarlama Amaçlı Kullanım
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
                              ).animate().fadeIn(delay: 600.ms),

                              const SizedBox(height: 24),

                              // Kayıt Ol Butonu
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
                                    onPressed: authProvider.isLoading ? null : _handleRegister,
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
                                            'Hesap Oluştur',
                                            style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                  ),
                                ),
                              ).animate().fadeIn(delay: 650.ms),

                              const SizedBox(height: 12),

                              // Google ile Kayıt Ol / Giriş Yap Butonu
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : () async {
                                          final success = await authProvider.signInWithGoogle();
                                          if (success && mounted) {
                                            // GoRouter will handle redirection
                                          } else if (!success && mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(authProvider.errorMessage ?? 'Google ile kayıt başarısız.'),
                                                backgroundColor: AppTheme.error,
                                              ),
                                            );
                                          }
                                        },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF374151),
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFFD1D5DB), width: 1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.network(
                                        'https://www.gstatic.com/images/branding/product/2x/googleg_64dp.png',
                                        height: 20,
                                        width: 20,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.g_mobiledata_rounded,
                                          color: Colors.red,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Google ile Kayıt Ol / Giriş Yap',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF374151),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(delay: 700.ms),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Giriş linki
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Zaten hesabın var mı? ',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF6B7280),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/login'),
                                child: Text(
                                  'Giriş Yap',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 750.ms),
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
