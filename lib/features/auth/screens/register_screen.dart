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
/// Gmail ve E-posta ile Kayıt Ol Ekranı

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();

  bool? _isOver18; // true: 18 yaşından büyük, false: 18 yaşından küçük, null: seçilmedi
  bool _isGoogleLoading = false;
  bool _isEmailLoading = false;
  bool _showEmailForm = false;
  bool _obscurePassword = true;

  bool _acceptedKvkk = false;
  bool _acceptedTermsAndPrivacy = false;
  bool _acceptedDataProcessing = false;
  bool _acceptedProfileSharing = false;
  bool _acceptedAuditionSharing = false;
  bool _acceptedMarketingUse = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  bool _validateAgeAndGuardian() {
    if (_isOver18 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Lütfen yaş durumunuzu seçin (18 yaşından büyük veya küçük).'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return false;
    }

    if (_isOver18 == false) {
      final name = _guardianNameController.text.trim();
      final phone = _guardianPhoneController.text.trim();
      if (name.isEmpty || name.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lütfen velinizin ad ve soyadını girin.'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return false;
      }
      if (phone.isEmpty || phone.replaceAll(RegExp(r'[^0-9]'), '').length < 7) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Lütfen geçerli bir veli telefon numarası girin.'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return false;
      }
    }

    return true;
  }

  bool _validateLegalConsents() {
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
      return false;
    }
    return true;
  }

  Future<void> _handleGoogleRegister() async {
    if (!_validateAgeAndGuardian()) return;
    if (!_validateLegalConsents()) return;

    setState(() => _isGoogleLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signInWithGoogle(
      isUnder18: _isOver18 == false,
      guardianName: _isOver18 == false ? _guardianNameController.text.trim() : null,
      guardianPhone: _isOver18 == false ? _guardianPhoneController.text.trim() : null,
      // Bu ekranda yaş sorusu zaten yukarıda soruldu ve doğrulandı.
      ageVerified: true,
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
  }

  Future<void> _handleEmailRegister() async {
    if (!_validateAgeAndGuardian()) return;
    if (!_validateLegalConsents()) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      phone: '',
      role: 'actor',
      isUnder18: _isOver18 == false,
      guardianName: _isOver18 == false ? _guardianNameController.text.trim() : null,
      guardianPhone: _isOver18 == false ? _guardianPhoneController.text.trim() : null,
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
                            'Castelle platformuna Gmail veya e-posta adresiniz ile kaydolarak hemen katılın.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF6B7280),
                              height: 1.4,
                            ),
                          ),
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 24),

                        // Yaş Durumu & Veli Bilgileri Kartı
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
                                  const Icon(Icons.cake_outlined, size: 18, color: AppTheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Yaş Durumu Seçimi (Zorunlu)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // 18 Yaş Seçenekleri
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => setState(() => _isOver18 = true),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _isOver18 == true ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _isOver18 == true ? AppTheme.primary : const Color(0xFFD1D5DB),
                                            width: _isOver18 == true ? 1.8 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isOver18 == true ? Icons.radio_button_checked : Icons.radio_button_off,
                                              size: 18,
                                              color: _isOver18 == true ? AppTheme.primary : const Color(0xFF9CA3AF),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '18 Yaşından Büyüğüm',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: _isOver18 == true ? FontWeight.bold : FontWeight.w500,
                                                  color: const Color(0xFF1F2937),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: () => setState(() => _isOver18 = false),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: _isOver18 == false ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: _isOver18 == false ? AppTheme.primary : const Color(0xFFD1D5DB),
                                            width: _isOver18 == false ? 1.8 : 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isOver18 == false ? Icons.radio_button_checked : Icons.radio_button_off,
                                              size: 18,
                                              color: _isOver18 == false ? AppTheme.primary : const Color(0xFF9CA3AF),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '18 Yaşından Küçüğüm',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  fontWeight: _isOver18 == false ? FontWeight.bold : FontWeight.w500,
                                                  color: const Color(0xFF1F2937),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // 18 Yaşından Küçüğüm Seçildiğinde Veli Bilgileri Bölümü
                              if (_isOver18 == false) ...[
                                const SizedBox(height: 16),
                                const Divider(color: Color(0xFFE5E7EB)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.supervisor_account_outlined, size: 18, color: AppTheme.accent),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Veli / Yasal Temsilci Bilgileri',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '18 yaşından küçük kullanıcıların kaydolabilmesi için veli bilgilerini girmesi zorunludur.',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 14),

                                // Veli Ad Soyadı
                                TextFormField(
                                  controller: _guardianNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'Veli Ad Soyadı *',
                                    hintText: 'Örn: Mehmet Yılmaz',
                                    prefixIcon: Icon(Icons.person_pin_outlined),
                                  ),
                                  validator: (val) {
                                    if (_isOver18 == false && (val == null || val.trim().isEmpty)) {
                                      return 'Lütfen velinizin ad soyadını girin.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Veli Telefonu
                                TextFormField(
                                  controller: _guardianPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Veli Telefon Numarası *',
                                    hintText: '05xx xxx xx xx',
                                    prefixIcon: Icon(Icons.phone_outlined),
                                  ),
                                  validator: (val) {
                                    if (_isOver18 == false && (val == null || val.trim().isEmpty)) {
                                      return 'Lütfen velinizin telefon numarasını girin.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ],
                          ),
                        ).animate().fadeIn(delay: 250.ms),

                        const SizedBox(height: 20),

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
                                onTap: isLoading ? null : _handleGoogleRegister,
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
                                              'Gmail ile Kayıt Ol',
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
                        ).animate().fadeIn(delay: 450.ms),

                        const SizedBox(height: 20),

                        // OR DIVIDER / TOGGLE BUTTON
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

                        // EMAIL ILE KAYIT TOGGLE / FORM
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
                                'E-posta ile Kayıt Ol',
                                style: GoogleFonts.outfit(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 500.ms)
                        else
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'E-posta ile Üyelik Bilgileri',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Ad Soyad Field
                                TextFormField(
                                  controller: _fullNameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: const InputDecoration(
                                    labelText: 'İsim Soyisim',
                                    hintText: 'Örn: Ahmet Yılmaz',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Lütfen ad ve soyadınızı girin.';
                                    }
                                    if (value.trim().length < 2) {
                                      return 'Geçerli bir isim girin.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

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
                                    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                    if (!emailRegex.hasMatch(value.trim())) {
                                      return 'Lütfen geçerli bir e-posta adresi girin.';
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
                                    hintText: 'En az 6 karakter',
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
                                      return 'Lütfen bir şifre belirleyin.';
                                    }
                                    if (value.length < 6) {
                                      return 'Şifre en az 6 karakter olmalıdır.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),

                                // E-posta Kayıt Tamamla Butonu
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
                                    onPressed: isLoading ? null : _handleEmailRegister,
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
                                            'Hesabımı Oluştur',
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
