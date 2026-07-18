import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/features/actor/providers/actor_profile_provider.dart';
import 'package:castelle/features/actor/widgets/skills_input_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:castelle/core/widgets/video_record_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

/// Castelle - Oyuncu Profil Düzenleme Ekranı
/// Tüm statik bilgiler + portfolio + videolar + filmografi + gizlilik kilitleri
class ActorProfileEditScreen extends StatefulWidget {
  const ActorProfileEditScreen({super.key});

  @override
  State<ActorProfileEditScreen> createState() => _ActorProfileEditScreenState();
}

class _ActorProfileEditScreenState extends State<ActorProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _cityController;
  late TextEditingController _bioController;
  late TextEditingController _instagramController;
  late TextEditingController _tiktokController;
  late TextEditingController _xController;
  late TextEditingController _bankIbanController;
  late TextEditingController _bankHolderController;
  late TextEditingController _hobbyInputController;

  // Seçilen değerler
  Gender? _selectedGender;
  EyeColor? _selectedEyeColor;
  HairColor? _selectedHairColor;
  String? _selectedExperienceLevel;
  List<String> _skills = [];
  List<String> _hobbies = [];

  bool _isInitialized = false;
  String? _processingVideoKey; // Şu an sıkıştırılan/yüklenen video anahtarı
  bool _forceClose = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emergencyPhoneController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _cityController = TextEditingController();
    _bioController = TextEditingController();
    _instagramController = TextEditingController();
    _tiktokController = TextEditingController();
    _xController = TextEditingController();
    _bankIbanController = TextEditingController();
    _bankHolderController = TextEditingController();
    _hobbyInputController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadExistingProfile();
      _isInitialized = true;
    }
  }

  void _loadExistingProfile() {
    final profileProvider = context.read<ActorProfileProvider>();
    final profile = profileProvider.profile;

    if (profile != null) {
      _fullNameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _emergencyPhoneController.text = profile.emergencyPhone ?? '';
      _ageController.text = profile.age?.toString() ?? '';
      _heightController.text = profile.heightCm?.toString() ?? '';
      _weightController.text = profile.weightKg?.toString() ?? '';
      _cityController.text = profile.city ?? '';
      _bioController.text = profile.bio ?? '';
      _instagramController.text = profile.instagramHandle ?? '';
      _tiktokController.text = profile.tiktokHandle ?? '';
      _xController.text = profile.xHandle ?? '';
      _bankIbanController.text = profile.bankIban ?? '';
      _bankHolderController.text = profile.bankAccountHolder ?? '';
      _selectedGender = profile.gender;
      _selectedEyeColor = profile.eyeColor;
      _selectedHairColor = profile.hairColor;
      _selectedExperienceLevel = profile.experienceLevel;
      _skills = List.from(profile.skills);
      _hobbies = List.from(profile.hobbies);
    } else {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      if (user != null) {
        _fullNameController.text = user.fullName;
        _phoneController.text = user.phone;
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emergencyPhoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _xController.dispose();
    _bankIbanController.dispose();
    _bankHolderController.dispose();
    _hobbyInputController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final profileProvider = context.read<ActorProfileProvider>();
    final uid = authProvider.user!.uid;

    final currentProfile = profileProvider.profile;

    final profile = ActorProfileModel(
      uid: uid,
      fullName: _fullNameController.text.trim(),
      email: authProvider.user!.email,
      phone: _phoneController.text.trim(),
      emergencyPhone: _emergencyPhoneController.text.trim().isEmpty ? null : _emergencyPhoneController.text.trim(),
      bankIban: _bankIbanController.text.trim().isEmpty ? null : _bankIbanController.text.trim(),
      bankAccountHolder: _bankHolderController.text.trim().isEmpty ? null : _bankHolderController.text.trim(),
      profilePhotoUrl: currentProfile?.profilePhotoUrl,
      age: int.tryParse(_ageController.text),
      gender: _selectedGender,
      heightCm: int.tryParse(_heightController.text),
      weightKg: int.tryParse(_weightController.text),
      eyeColor: _selectedEyeColor,
      hairColor: _selectedHairColor,
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
      experienceLevel: _selectedExperienceLevel,
      skills: _skills,
      hobbies: _hobbies,
      instagramHandle: _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
      tiktokHandle: _tiktokController.text.trim().isEmpty ? null : _tiktokController.text.trim(),
      xHandle: _xController.text.trim().isEmpty ? null : _xController.text.trim(),
      galleryPhotoUrls: currentProfile?.galleryPhotoUrls ?? const [],
      filmography: currentProfile?.filmography ?? const [],
      introVideoUrl: currentProfile?.introVideoUrl,
      showreelVideoUrl: currentProfile?.showreelVideoUrl,
      performanceVideoUrl: currentProfile?.performanceVideoUrl,
      expressionVideoUrl: currentProfile?.expressionVideoUrl,
      lockedSections: currentProfile?.lockedSections ?? const {},
      isHidden: currentProfile?.isHidden ?? false,
      acceptedNdas: currentProfile?.acceptedNdas ?? const [],
    );

    final success = await profileProvider.saveProfile(profile);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil başarıyla kaydedildi!'),
            backgroundColor: AppTheme.success,
          ),
        );
        setState(() {
          _forceClose = true;
        });
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileProvider.errorMessage ?? 'Kaydetme başarısız.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  bool _hasUnsavedChanges() {
    final profileProvider = context.read<ActorProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return _fullNameController.text.trim().isNotEmpty ||
          _phoneController.text.trim().isNotEmpty ||
          _emergencyPhoneController.text.trim().isNotEmpty ||
          _ageController.text.trim().isNotEmpty ||
          _heightController.text.trim().isNotEmpty ||
          _weightController.text.trim().isNotEmpty ||
          _cityController.text.trim().isNotEmpty ||
          _bioController.text.trim().isNotEmpty ||
          _instagramController.text.trim().isNotEmpty ||
          _tiktokController.text.trim().isNotEmpty ||
          _xController.text.trim().isNotEmpty ||
          _bankIbanController.text.trim().isNotEmpty ||
          _bankHolderController.text.trim().isNotEmpty ||
          _skills.isNotEmpty ||
          _hobbies.isNotEmpty ||
          _selectedGender != null ||
          _selectedEyeColor != null ||
          _selectedHairColor != null;
    }

    final ageStr = profile.age?.toString() ?? '';
    final heightStr = profile.heightCm?.toString() ?? '';
    final weightStr = profile.weightKg?.toString() ?? '';
    final cityStr = profile.city ?? '';
    final bioStr = profile.bio ?? '';
    final instagramStr = profile.instagramHandle ?? '';
    final emergencyPhoneStr = profile.emergencyPhone ?? '';
    final tiktokStr = profile.tiktokHandle ?? '';
    final xStr = profile.xHandle ?? '';
    final bankIbanStr = profile.bankIban ?? '';
    final bankHolderStr = profile.bankAccountHolder ?? '';

    bool listEquals(List a, List b) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (a[i] != b[i]) return false;
      }
      return true;
    }

    return _fullNameController.text.trim() != profile.fullName ||
        _phoneController.text.trim() != profile.phone ||
        _emergencyPhoneController.text.trim() != emergencyPhoneStr ||
        _ageController.text.trim() != ageStr ||
        _heightController.text.trim() != heightStr ||
        _weightController.text.trim() != weightStr ||
        _cityController.text.trim() != cityStr ||
        _bioController.text.trim() != bioStr ||
        _instagramController.text.trim() != instagramStr ||
        _tiktokController.text.trim() != tiktokStr ||
        _xController.text.trim() != xStr ||
        _bankIbanController.text.trim() != bankIbanStr ||
        _bankHolderController.text.trim() != bankHolderStr ||
        _selectedGender != profile.gender ||
        _selectedEyeColor != profile.eyeColor ||
        _selectedHairColor != profile.hairColor ||
        !listEquals(_skills, profile.skills) ||
        !listEquals(_hobbies, profile.hobbies);
  }

  Future<bool> _showUnsavedChangesDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceCard,
            title: Text(
              'Değişiklikleri Kaydet?',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            content: Text(
              'Kaydedilmemiş değişiklikleriniz var. Çıkmadan önce kaydetmek ister misiniz?',
              style: GoogleFonts.inter(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false), // Çık (Değişiklikleri at)
                child: const Text('Değişiklikleri At', style: TextStyle(color: AppTheme.error)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true), // Kaydet
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('Kaydet'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ═══════════════════════════════════════
  // MEDYA İŞLEMLERİ (YÜKLEME)
  // ═══════════════════════════════════════

  Future<void> _pickProfilePhoto(ImageSource source) async {
    debugPrint('📸 [EditProfile] _pickProfilePhoto tetiklendi: $source');
    try {
      final xFile = await _picker.pickImage(source: source, imageQuality: 80);
      if (xFile == null) {
        debugPrint('📸 [EditProfile] Görsel seçimi iptal edildi.');
        return;
      }
      debugPrint('📸 [EditProfile] Görsel seçildi: ${xFile.path}');
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.user?.uid;
      final provider = context.read<ActorProfileProvider>();
      final success = await provider.uploadProfilePhoto(File(xFile.path), fallbackUid: uid);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil resmi yüklendi.'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      debugPrint('❌ [EditProfile] Profil resmi seçme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil resmi seçilemedi: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _pickGalleryPhoto() async {
    debugPrint('📸 [EditProfile] _pickGalleryPhoto (toplu seçim) tetiklendi');
    try {
      final provider = context.read<ActorProfileProvider>();
      final currentCount = provider.profile?.galleryPhotoUrls.length ?? 0;
      if (currentCount >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En fazla 10 adet portfolyo fotoğrafı yükleyebilirsiniz.'), backgroundColor: AppTheme.warning),
        );
        return;
      }

      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) {
        debugPrint('📸 [EditProfile] Galeri seçimi iptal edildi veya görsel seçilmedi.');
        return;
      }
      debugPrint('📸 [EditProfile] Galeri görselleri seçildi: ${files.length} adet');
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.user?.uid;
      
      final fileList = files.map((x) => File(x.path)).toList();
      final success = await provider.uploadMultipleGalleryPhotos(fileList, fallbackUid: uid);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${fileList.length} adet fotoğraf portfolyoya eklendi.'), 
              backgroundColor: AppTheme.success
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? 'Fotoğraflar yüklenemedi.'), 
              backgroundColor: AppTheme.error
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [EditProfile] Portfolyo görseli seçme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf seçilemedi: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _pickProfileVideo(ImageSource source, String videoKey) async {
    debugPrint('📹 [EditProfile] _pickProfileVideo tetiklendi: $source | key: $videoKey');
    try {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.surfaceCard,
          title: Row(
            children: [
              const Icon(Icons.videocam, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text('Yatay Video Kuralı', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Lütfen çekeceğiniz veya yükleyeceğiniz videonun YATAY (landscape) olduğundan emin olun.\nDikey videolar sisteme yüklenemez.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
              child: const Text('Devam Et'),
            ),
          ],
        ),
      ) ?? false;

      if (!proceed) return;

      final String? videoPath;
      if (source == ImageSource.camera) {
        videoPath = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => VideoRecordScreen(
              prefilledScript: null,
              isMimicMode: videoKey == 'expressionVideo',
            ),
          ),
        );
      } else {
        final xFile = await _picker.pickVideo(
          source: source,
          maxDuration: videoKey == 'expressionVideo'
              ? const Duration(seconds: 50)
              : (videoKey == 'showreelVideo'
                  ? const Duration(minutes: 4)
                  : (videoKey == 'performanceVideo'
                      ? const Duration(minutes: 2)
                      : (videoKey == 'introVideo'
                          ? const Duration(seconds: 30)
                          : const Duration(seconds: 20)))),
        );
        videoPath = xFile?.path;
      }

      if (videoPath == null || videoPath.isEmpty) {
        debugPrint('📹 [EditProfile] Video seçimi iptal edildi.');
        return;
      }
      debugPrint('📹 [EditProfile] Video seçildi: $videoPath');
      if (!mounted) return;

      // Video yataylık kontrolü
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      final size = controller.value.size;
      final isLandscape = size.width > size.height;
      await controller.dispose();

      if (!isLandscape) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.surfaceCard,
            title: const Text('Hata: Dikey Video'),
            content: const Text('Yüklemeye çalıştığınız video dikey. Lütfen sadece yatay (landscape) çekilmiş videolar yükleyin.'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
        return;
      }

      setState(() => _processingVideoKey = videoKey);

      final authProvider = context.read<AuthProvider>();
      final uid = authProvider.user?.uid;
      final provider = context.read<ActorProfileProvider>();
      final success = await provider.uploadAndCompressProfileVideo(File(videoPath), videoKey, fallbackUid: uid);

      if (!mounted) return;
      setState(() => _processingVideoKey = null);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video başarıyla yüklendi.'), backgroundColor: AppTheme.success),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? 'Video yüklenemedi.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [EditProfile] Video seçme/yükleme hatası: $e');
      setState(() => _processingVideoKey = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video seçilemedi: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // ═══════════════════════════════════════
  // HOBİ EKLEME/ÇIKARMA
  // ═══════════════════════════════════════

  void _addHobby(String hobby) {
    final trimmed = hobby.trim();
    if (trimmed.isEmpty) return;
    if (_hobbies.contains(trimmed)) return;
    setState(() {
      _hobbies.add(trimmed);
      _hobbyInputController.clear();
    });
  }

  void _removeHobby(String hobby) {
    setState(() {
      _hobbies.remove(hobby);
    });
  }

  // ═══════════════════════════════════════
  // FİLMOGRAFİ EKLEME MODALI
  // ═══════════════════════════════════════

  void _showAddFilmographyDialog() {
    final yearController = TextEditingController();
    final titleController = TextEditingController();
    final directorController = TextEditingController();
    final linkController = TextEditingController();
    String selectedType = 'Dizi';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              title: Text(
                'Proje Ekle',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: yearController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Yıl (Örn: 2024)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: AppTheme.surfaceCard,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Proje Türü'),
                      items: const [
                        DropdownMenuItem(value: 'Dizi', child: Text('Dizi')),
                        DropdownMenuItem(value: 'Sinema', child: Text('Sinema')),
                        DropdownMenuItem(value: 'Reklam', child: Text('Reklam')),
                        DropdownMenuItem(value: 'Tiyatro', child: Text('Tiyatro')),
                        DropdownMenuItem(value: 'Klip', child: Text('Klip')),
                        DropdownMenuItem(value: 'Kısa Film', child: Text('Kısa Film')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedType = v ?? 'Dizi'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Proje Adı'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: directorController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Yönetmen'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: linkController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Proje Linki (Opsiyonel)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final year = yearController.text.trim();
                    final title = titleController.text.trim();
                    final director = directorController.text.trim();
                    final link = linkController.text.trim();

                    if (year.isEmpty || title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yıl ve Proje Adı alanları zorunludur.'), backgroundColor: AppTheme.warning),
                      );
                      return;
                    }

                    context.read<ActorProfileProvider>().addFilmographyItem({
                      'year': year,
                      'projectType': selectedType,
                      'projectTitle': title,
                      'director': director.isEmpty ? 'Belirtilmedi' : director,
                      'projectLink': link,
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proje eklendi.'), backgroundColor: AppTheme.success),
                    );
                  },
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════
  // EKRAN RENDER
  // ═══════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ActorProfileProvider>();
    final profile = profileProvider.profile;

    return PopScope(
      canPop: !_hasUnsavedChanges() || _forceClose,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        final shouldSave = await _showUnsavedChangesDialog();
        if (shouldSave) {
          await _handleSave();
        } else {
          if (mounted) {
            setState(() {
              _forceClose = true;
            });
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: const Text('Profilimi Düzenle'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // ══════════════════════════════
                // BÖLÜM 1: PROFİL VE PORTFOLYO FOTOĞRAFLARI
                // ══════════════════════════════
                _buildSectionHeader('Profil & Portfolyo Fotoğrafları', Icons.photo_library, profile, 'gallery', profileProvider),
                const SizedBox(height: 14),

                // Profil Fotoğrafı Seçici
                _buildProfilePhotoEditor(profile),
                const SizedBox(height: 24),

                // Portfolyo 10 Fotoğraf Galerisi
                _buildGalleryPhotoEditor(profile),
                const SizedBox(height: 28),

                // ══════════════════════════════
                // BÖLÜM 2: KİŞİSEL BİLGİLER
                // ══════════════════════════════
                _buildSectionHeader('Kişisel Bilgiler', Icons.person_outline, profile, 'bio', profileProvider),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _fullNameController,
                  label: 'Ad Soyad',
                  icon: Icons.person,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ad soyad gerekli' : null,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _phoneController,
                  label: 'Telefon',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _emergencyPhoneController,
                  label: 'Ulaşılamazsa Aranacak Kişi Telefonu',
                  icon: Icons.contact_phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _ageController,
                        label: 'Yaş',
                        icon: Icons.cake,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildDropdown<Gender>(
                        label: 'Cinsiyet',
                        value: _selectedGender,
                        items: Gender.values
                            .map((g) => DropdownMenuItem(value: g, child: Text(g.displayName)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedGender = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _cityController,
                  label: 'Şehir',
                  icon: Icons.location_city,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 500,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Hakkımda',
                    hintText: 'Kendinizi kısaca tanıtın...',
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 64),
                      child: Icon(Icons.edit_note, size: 20),
                    ),
                    counterStyle: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 28),

                // ══════════════════════════════
                // BÖLÜM 3: FİZİKSEL ÖZELLİKLER
                // ══════════════════════════════
                _buildSectionHeader('Fiziksel Özellikler', Icons.accessibility_new, profile, 'physical', profileProvider),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _heightController,
                        label: 'Boy (cm)',
                        icon: Icons.height,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildTextField(
                        controller: _weightController,
                        label: 'Kilo (kg)',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown<EyeColor>(
                        label: 'Göz Rengi',
                        value: _selectedEyeColor,
                        items: EyeColor.values
                            .map((e) => DropdownMenuItem(value: e, child: Text(e.displayName)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedEyeColor = v),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildDropdown<HairColor>(
                        label: 'Saç Rengi',
                        value: _selectedHairColor,
                        items: HairColor.values
                            .map((h) => DropdownMenuItem(value: h, child: Text(h.displayName)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedHairColor = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ══════════════════════════════
                // BÖLÜM 5.5: YETENEKLER
                // ══════════════════════════════
                _buildSectionHeader('Yetenekler & Beceriler', Icons.star_outline_rounded, profile, 'skills', profileProvider),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yetenek etiketleri ekle — casting yönetmenleri bu yeteneklere göre sizi bulur.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SkillsInputWidget(
                        skills: _skills,
                        onSkillsChanged: (updated) {
                          setState(() => _skills = updated);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ══════════════════════════════
                // BÖLÜM 6: FİLMOGRAFİ (PROJELER)
                // ══════════════════════════════
                _buildSectionHeader('Filmografi (Projeler)', Icons.movie_creation_outlined, profile, 'filmography', profileProvider),

                const SizedBox(height: 14),
                _buildFilmographyEditor(profile),
                const SizedBox(height: 28),

                // ══════════════════════════════
                // BÖLÜM 7: VİDEOLAR
                // ══════════════════════════════
                _buildSectionHeader('Videolar', Icons.video_collection_outlined, profile, 'videos', profileProvider),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'UYARI: Yükleyeceğiniz tüm videolar yatay (landscape) çekilmelidir. Dikey videolar sistem tarafından otomatik olarak reddedilecektir.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildProfileVideoUploader(
                  title: 'Tanıtım Videosu',
                  videoUrl: profile?.introVideoUrl,
                  videoKey: 'introVideo',
                  lockedKey: 'introVideo',
                  profile: profile,
                  provider: profileProvider,
                ),
                const SizedBox(height: 14),

                _buildProfileVideoUploader(
                  title: 'Showreel',
                  videoUrl: profile?.showreelVideoUrl,
                  videoKey: 'showreelVideo',
                  lockedKey: 'showreel',
                  profile: profile,
                  provider: profileProvider,
                ),
                const SizedBox(height: 14),

                _buildProfileVideoUploader(
                  title: 'Performans Videosu',
                  videoUrl: profile?.performanceVideoUrl,
                  videoKey: 'performanceVideo',
                  lockedKey: 'performanceVideo',
                  profile: profile,
                  provider: profileProvider,
                  showCameraRecord: true,
                ),
                const SizedBox(height: 14),

                _buildProfileVideoUploader(
                  title: 'Mimik Videosu',
                  videoUrl: profile?.expressionVideoUrl,
                  videoKey: 'expressionVideo',
                  lockedKey: 'expressionVideo',
                  profile: profile,
                  provider: profileProvider,
                  showCameraRecord: true,
                ),
                const SizedBox(height: 28),

                // ══════════════════════════════
                // BÖLÜM 7.5: BANKA HESAP BİLGİLERİ
                // ══════════════════════════════
                _buildSectionHeader('Banka Hesap Bilgileri', Icons.account_balance_outlined, profile, 'bank', profileProvider),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _bankHolderController,
                  label: 'Hesap Sahibi Adı Soyadı',
                  icon: Icons.person_outline,
                  hintText: 'Ad Soyad',
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _bankIbanController,
                  label: 'IBAN Numarası',
                  icon: Icons.account_balance_wallet_outlined,
                  hintText: 'TR00 0000 0000 0000 0000 0000 00',
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 28),

                // ══════════════════════════════
                // BÖLÜM 8: SOSYAL MEDYA
                // ══════════════════════════════
                _buildSectionHeader('Sosyal Medya', Icons.share, profile, 'social', profileProvider),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _instagramController,
                  label: 'Instagram',
                  icon: Icons.camera_alt_outlined,
                  hintText: '@kullaniciadi',
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _tiktokController,
                  label: 'TikTok',
                  icon: Icons.music_note_outlined,
                  hintText: '@kullaniciadi',
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _xController,
                  label: 'X (Twitter)',
                  icon: Icons.alternate_email,
                  hintText: '@kullaniciadi',
                ),
                const SizedBox(height: 100), // FAB için boşluk bırakıyoruz
              ],
            ),
          ),
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.glowAccent,
          ),
          child: FloatingActionButton.extended(
            onPressed: profileProvider.isLoading ? null : _handleSave,
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            label: profileProvider.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    'KAYDET',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // FORM BİLEŞENLERİ & ALT EDİTÖRLER
  // ═══════════════════════════════════════

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    ActorProfileModel? profile,
    String lockKey,
    ActorProfileProvider provider,
  ) {
    final isLocked = profile?.lockedSections[lockKey] ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
          ],
        ),
        if (profile != null)
          GestureDetector(
            onTap: () {
              provider.toggleSectionLock(lockKey);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isLocked
                        ? 'Bölüm herkese açık yapıldı.'
                        : 'Bölüm gizlendi (kilitlendi).',
                  ),
                  backgroundColor: isLocked ? AppTheme.success : AppTheme.warning,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isLocked ? AppTheme.error.withValues(alpha: 0.1) : AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isLocked ? Icons.lock : Icons.lock_open,
                size: 16,
                color: isLocked ? AppTheme.error : AppTheme.success,
              ),
            ),
          ),
      ],
    );
  }

  // PROFİL RESMİ EDİTÖRÜ
  Widget _buildProfilePhotoEditor(ActorProfileModel? profile) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2),
            ),
            child: ClipOval(
              child: profile?.profilePhotoUrl != null
                  ? (profile!.profilePhotoUrl!.startsWith('http')
                      ? Image.network(profile.profilePhotoUrl!, fit: BoxFit.cover)
                      : Image.file(File(profile.profilePhotoUrl!), fit: BoxFit.cover))
                  : Container(
                      color: AppTheme.surfaceLight,
                      child: const Icon(Icons.person, size: 48, color: AppTheme.textTertiary),
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _showPhotoSourceBottomSheet(true),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
              ),
            ),
          ),
          if (profile?.profilePhotoUrl != null && profile!.profilePhotoUrl!.isNotEmpty)
            Positioned(
              left: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.surfaceCard,
                      title: Text('Profil Fotoğrafını Sil', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      content: const Text('Profil fotoğrafınızı silmek istediğinize emin misiniz?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textTertiary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Sil'),
                        ),
                      ],
                    ),
                  ) ?? false;
                  if (confirmed) {
                    final updatedProfile = profile.copyWith(profilePhotoUrl: '');
                    final success = await context.read<ActorProfileProvider>().saveProfile(updatedProfile);
                    if (mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profil fotoğrafı silindi.'), backgroundColor: AppTheme.success),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                  child: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 10 FOTOĞRAF PORTFOLYO GRID EDİTÖRÜ
  Widget _buildGalleryPhotoEditor(ActorProfileModel? profile) {
    final urls = profile?.galleryPhotoUrls ?? [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Portfolyo Görselleri (${urls.length}/10)',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (urls.length < 10) ? urls.length + 1 : 10,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemBuilder: (context, index) {
              if (index == urls.length && urls.length < 10) {
                // Fotoğraf Ekleme Butonu
                return GestureDetector(
                  onTap: _pickGalleryPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border, style: BorderStyle.solid, width: 0.5),
                    ),
                    child: const Center(
                      child: Icon(Icons.add_a_photo_outlined, color: AppTheme.accent),
                    ),
                  ),
                );
              }

              // Yüklenmiş görsel kartı
              final url = urls[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: url.startsWith('http')
                        ? Image.network(url, fit: BoxFit.cover)
                        : Image.file(File(url), fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () {
                        context.read<ActorProfileProvider>().deleteGalleryPhoto(index);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPhotoSourceBottomSheet(bool isProfilePhoto) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppTheme.accent),
                title: const Text('Kamerayı Aç'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfilePhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppTheme.accent),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProfilePhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // HOBİ EDİTÖRÜ
  Widget _buildHobbiesEditor() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hobbies.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hobbies.map((hobi) {
                return Chip(
                  label: Text(hobi),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  onDeleted: () => _removeHobby(hobi),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hobbyInputController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Hobi yazın (Örn: Yüzme, Kitap Okumak)',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onSubmitted: _addHobby,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.accent),
                onPressed: () => _addHobby(_hobbyInputController.text),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FİLMOGRAFİ EDİTÖRÜ
  Widget _buildFilmographyEditor(ActorProfileModel? profile) {
    final list = profile?.filmography ?? [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Projeler (${list.length})',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              TextButton.icon(
                onPressed: _showAddFilmographyDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni Ekle', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Kayıtlı proje bulunmuyor.', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textTertiary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final job = list[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          job['year']?.toString() ?? '',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: job['projectLink'] != null && job['projectLink'].toString().isNotEmpty
                              ? () => _launchProjectUrl(job['projectLink'].toString())
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      job['projectTitle']?.toString() ?? '',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: (job['projectLink'] != null && job['projectLink'].toString().isNotEmpty)
                                            ? AppTheme.accent
                                            : AppTheme.textPrimary,
                                        decoration: (job['projectLink'] != null && job['projectLink'].toString().isNotEmpty)
                                            ? TextDecoration.underline
                                            : TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                  if (job['projectLink'] != null && job['projectLink'].toString().isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: job['projectLink'].toString()));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Proje linki kopyalandı! 📋'),
                                            backgroundColor: AppTheme.info,
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.copy_rounded, size: 14, color: AppTheme.textTertiary),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${job['projectType']} • Yönetmen: ${job['director']}',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                        onPressed: () {
                          context.read<ActorProfileProvider>().removeFilmographyItem(index);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Proje kaldırıldı.'), backgroundColor: AppTheme.success),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // VİDEO YÜKLEYİCİ KARTI
  Widget _buildProfileVideoUploader({
    required String title,
    required String? videoUrl,
    required String videoKey,
    required String lockedKey,
    required ActorProfileModel? profile,
    required ActorProfileProvider provider,
    bool showCameraRecord = false,
  }) {
    final isProcessingThis = _processingVideoKey == videoKey && provider.isProcessing;
    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    
    final String description = switch (videoKey) {
      'introVideo' => 'Kendinizi tanıtan, deneyimlerinizden bahsettiğiniz kısa bir video çekin. Işığın önden gelmesine ve sesinizin net duyulmasına özen gösterin.',
      'showreelVideo' => 'Daha önce yer aldığınız projelerden kesitleri veya oyunculuk yeteneğinizi sergileyen sahneleri içeren kolaj videonuz.',
      'performanceVideo' => 'Bir tirad veya monolog üzerinden sergilediğiniz oyunculuk performansınız.',
      'expressionVideo' => 'Kameraya bakarak farklı temel duyguları (mutluluk, öfke, üzüntü, şaşkınlık vb.) sırayla sergilediğiniz mimik videosu.',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.video_collection_outlined, color: AppTheme.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              if (profile != null)
                GestureDetector(
                  onTap: () => provider.toggleSectionLock(lockedKey),
                  child: Icon(
                    (profile.lockedSections[lockedKey] ?? false) ? Icons.lock : Icons.lock_open,
                    size: 16,
                    color: (profile.lockedSections[lockedKey] ?? false) ? AppTheme.error : AppTheme.success,
                  ),
                ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 12),

          if (isProcessingThis)
            _buildVideoProcessingProgress(provider)
          else if (hasVideo)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                    const SizedBox(width: 8),
                    Text('Video Yüklendi', style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary)),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _downloadVideoFile(context, videoUrl, title),
                      icon: const Icon(Icons.download_rounded, size: 14),
                      label: const Text('İndir', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _pickProfileVideo(ImageSource.gallery, videoKey),
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('Değiştir', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceLight,
                        foregroundColor: AppTheme.textPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.surfaceCard,
                            title: Text('Videoyu Sil', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            content: const Text('Bu videoyu profilinizden silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textTertiary)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Sil'),
                              ),
                            ],
                          ),
                        ) ?? false;
                        if (confirmed) {
                          final success = await provider.deleteProfileVideo(videoKey);
                          if (mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Video başarıyla silindi.'), backgroundColor: AppTheme.success),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 14),
                      label: const Text('Sil', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.error,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: provider.isProcessing ? null : () => _pickProfileVideo(ImageSource.gallery, videoKey),
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: Text('Galeriden Seç (Maks 20s)', style: GoogleFonts.outfit(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.accent),
                          foregroundColor: AppTheme.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                if (showCameraRecord) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: provider.isProcessing ? null : () => _pickProfileVideo(ImageSource.camera, videoKey),
                          icon: const Icon(Icons.videocam, size: 16),
                          label: Text(
                            videoKey == 'expressionVideo'
                                ? 'Mimik Videosu Çek'
                                : 'Performans Videosu Çek (Maks 20s)',
                            style: GoogleFonts.outfit(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primarySoft,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildVideoProcessingProgress(ActorProfileProvider provider) {
    final isComp = provider.isCompressing;
    final progress = isComp ? provider.compressProgress : provider.uploadProgress;
    final label = isComp ? 'Sıkıştırılıyor...' : 'Yükleniyor...';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accent)),
            Text('${(progress * 100).toStringAsFixed(0)}%', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.surfaceLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════
  // GENEL FORM UTILS
  // ═══════════════════════════════════════

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, size: 20),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppTheme.surfaceCard,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _launchProjectUrl(String urlString) async {
    if (urlString.isEmpty) return;
    var uri = Uri.tryParse(urlString);
    if (uri != null) {
      if (!uri.hasScheme) {
        uri = Uri.tryParse('https://$urlString');
      }
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _downloadVideoFile(BuildContext context, String? url, String title) async {
    if (url == null || url.isEmpty) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // 1. Hedef Klasör Seçimi
    String? selectedDir;
    try {
      selectedDir = await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      debugPrint('Folder picker error: $e');
    }

    if (selectedDir == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('İndirme iptal edildi. Klasör seçilmedi.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    // 2. Depolama İzni İste (Sadece Android ve iOS için)
    if (Platform.isAndroid || Platform.isIOS) {
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      } else {
        await Permission.storage.request();
      }
    }

    // 3. İndirme Diyaloğu Göster
    double progress = 0.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Download in background
          Dio().download(
            url,
            "$selectedDir/$title.mp4",
            onReceiveProgress: (received, total) {
              if (total != -1) {
                setDialogState(() {
                  progress = received / total;
                });
              }
            },
          ).then((_) {
            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('$title başarıyla kaydedildi! 🎉'),
                backgroundColor: AppTheme.success,
              ),
            );
          }).catchError((err) {
            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('İndirme hatası: $err'),
                backgroundColor: AppTheme.error,
              ),
            );
          });

          return AlertDialog(
            backgroundColor: AppTheme.surfaceCard,
            title: Text('Video İndiriliyor', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.border,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                ),
                const SizedBox(height: 12),
                Text(
                  '%${(progress * 100).toStringAsFixed(0)} indirildi',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}
