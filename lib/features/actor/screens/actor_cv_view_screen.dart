import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:castelle/core/widgets/policy_dialogs.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/actor/providers/actor_profile_provider.dart';
import 'package:castelle/features/actor/screens/actor_profile_edit_screen.dart';
import 'package:castelle/features/chat/screens/chat_room_screen.dart';
import 'package:castelle/features/actor/widgets/skills_input_widget.dart';
import 'package:castelle/core/widgets/video_record_screen.dart';


/// Castelle - Oyuncu CV / Cast Profil Görüntüleme Ekranı
/// Hem oyuncunun kendi profil sekmesinde hem de yönetmen/işveren detaylarında kullanılır.
class ActorCvViewScreen extends StatefulWidget {
  final bool isOwner;
  final ActorProfileModel? actor;

  const ActorCvViewScreen({
    super.key,
    required this.isOwner,
    this.actor,
  });

  @override
  State<ActorCvViewScreen> createState() => _ActorCvViewScreenState();
}

class _ActorCvViewScreenState extends State<ActorCvViewScreen> {
  // Scroll konumlandırması için GlobalKey'ler
  final GlobalKey _detailsSectionKey = GlobalKey();
  final GlobalKey _videosSectionKey = GlobalKey();
  final GlobalKey _filmographySectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  // Inline edit state variables
  bool _isHeaderEditing = false;
  bool _isBioEditing = false;
  bool _isPhysicalEditing = false;
  bool _isGalleryEditing = false;
  bool _isHobbiesEditing = false;
  bool _isSkillsEditing = false;
  bool _isFilmographyEditing = false;
  bool _isVideosEditing = false;
  String? _processingVideoKey;

  // Controllers
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _bioController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _hobbyInputController;

  // Filmography add form controllers
  late TextEditingController _newProjectTitleController;
  late TextEditingController _newProjectDirectorController;
  late TextEditingController _newProjectYearController;
  late TextEditingController _newProjectLinkController;
  String _newProjectType = 'Dizi';

  // Edit models
  Gender? _editGender;
  EyeColor? _editEyeColor;
  HairColor? _editHairColor;
  List<String> _editHobbies = [];
  List<String> _editSkills = [];
  List<Map<String, dynamic>> _editFilmography = [];

  final ImagePicker _picker = ImagePicker();

  ActorProfileModel? _loadedActor;
  bool _isLoadingActor = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _bioController = TextEditingController();
    _ageController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();
    _hobbyInputController = TextEditingController();

    _newProjectTitleController = TextEditingController();
    _newProjectDirectorController = TextEditingController();
    _newProjectYearController = TextEditingController();
    _newProjectLinkController = TextEditingController();

    if (!widget.isOwner && widget.actor != null) {
      _loadLatestActorProfile();
    }
  }

  Future<void> _loadLatestActorProfile() async {
    final actorId = widget.actor?.uid;
    if (actorId == null) return;

    if (mounted) setState(() => _isLoadingActor = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(actorId)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _loadedActor = ActorProfileModel.fromMap(doc.data()!, doc.id);
          _isLoadingActor = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingActor = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingActor = false);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _hobbyInputController.dispose();
    _newProjectTitleController.dispose();
    _newProjectDirectorController.dispose();
    _newProjectYearController.dispose();
    _newProjectLinkController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  // INLINE EDIT HELPERS
  // ═══════════════════════════════════════

  void _startHeaderEditing(ActorProfileModel profile) {
    setState(() {
      _fullNameController.text = profile.fullName;
      _phoneController.text = profile.phone;
      _cityController.text = profile.city ?? '';
      _isHeaderEditing = true;
    });
  }

  Future<void> _saveHeader(ActorProfileProvider provider) async {
    if (provider.profile == null) return;
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad Soyad boş olamaz.'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    final updated = provider.profile!.copyWith(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
    );
    final success = await provider.saveProfile(updated);
    if (success) {
      setState(() => _isHeaderEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık bilgileri güncellendi.'), backgroundColor: AppTheme.success),
      );
    }
  }

  void _startBioEditing(ActorProfileModel profile) {
    setState(() {
      _bioController.text = profile.bio ?? '';
      _isBioEditing = true;
    });
  }

  Future<void> _saveBio(ActorProfileProvider provider) async {
    if (provider.profile == null) return;
    final updated = provider.profile!.copyWith(
      bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
    );
    final success = await provider.saveProfile(updated);
    if (success) {
      setState(() => _isBioEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hakkımda bölümü güncellendi.'), backgroundColor: AppTheme.success),
      );
    }
  }

  void _startPhysicalEditing(ActorProfileModel profile) {
    setState(() {
      _ageController.text = profile.age?.toString() ?? '';
      _heightController.text = profile.heightCm?.toString() ?? '';
      _weightController.text = profile.weightKg?.toString() ?? '';
      _editGender = profile.gender;
      _editEyeColor = profile.eyeColor;
      _editHairColor = profile.hairColor;
      _isPhysicalEditing = true;
    });
  }

  Future<void> _savePhysical(ActorProfileProvider provider) async {
    if (provider.profile == null) return;
    final updated = provider.profile!.copyWith(
      age: int.tryParse(_ageController.text),
      heightCm: int.tryParse(_heightController.text),
      weightKg: int.tryParse(_weightController.text),
      gender: _editGender,
      eyeColor: _editEyeColor,
      hairColor: _editHairColor,
    );
    final success = await provider.saveProfile(updated);
    if (success) {
      setState(() => _isPhysicalEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fiziksel özellikler güncellendi.'), backgroundColor: AppTheme.success),
      );
    }
  }

  void _startHobbiesEditing(ActorProfileModel profile) {
    setState(() {
      _editHobbies = List.from(profile.hobbies);
      _isHobbiesEditing = true;
    });
  }

  Future<void> _saveHobbies(ActorProfileProvider provider) async {
    if (provider.profile == null) return;
    final updated = provider.profile!.copyWith(hobbies: _editHobbies);
    final success = await provider.saveProfile(updated);
    if (success) {
      setState(() => _isHobbiesEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hobiler güncellendi.'), backgroundColor: AppTheme.success),
      );
    }
  }

  void _startSkillsEditing(ActorProfileModel profile) {
    setState(() {
      _editSkills = List.from(profile.skills);
      _isSkillsEditing = true;
    });
  }

  Future<void> _saveSkills(ActorProfileProvider provider) async {
    if (provider.profile == null) return;
    final updated = provider.profile!.copyWith(skills: _editSkills);
    final success = await provider.saveProfile(updated);
    if (success) {
      setState(() => _isSkillsEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yetenekler güncellendi.'), backgroundColor: AppTheme.success),
      );
    }
  }

  void _startFilmographyEditing(ActorProfileModel profile) {
    setState(() {
      _editFilmography = List.from(profile.filmography);
      _isFilmographyEditing = true;
    });
  }

  Future<void> _saveFilmography(ActorProfileProvider provider) async {
    if (provider.profile == null) return;
    final updated = provider.profile!.copyWith(filmography: _editFilmography);
    final success = await provider.saveProfile(updated);
    if (success) {
      setState(() => _isFilmographyEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Filmografi güncellendi.'), backgroundColor: AppTheme.success),
      );
    }
  }

  Future<void> _pickProfilePhotoDirect(ActorProfileProvider provider) async {
    try {
      final xFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (xFile == null) return;
      await provider.uploadProfilePhoto(File(xFile.path));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil resmi güncellendi.'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil resmi seçilemedi: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _pickGalleryPhotoDirect(ActorProfileProvider provider) async {
    try {
      final currentCount = provider.profile?.galleryPhotoUrls.length ?? 0;
      if (currentCount >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En fazla 10 adet portfolyo fotoğrafı yükleyebilirsiniz.'), backgroundColor: AppTheme.warning),
        );
        return;
      }
      final files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;
      final fileList = files.map((x) => File(x.path)).toList();
      await provider.uploadMultipleGalleryPhotos(fileList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${fileList.length} adet fotoğraf portfolyoya eklendi.'), backgroundColor: AppTheme.success),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotoğraf seçilemedi: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _pickProfileVideoDirect(ActorProfileProvider provider, String videoKey) async {
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

      final ImageSource? selectedSource = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppTheme.surfaceCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Video Kaynağı Seçin',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.videocam_rounded, color: AppTheme.accent),
                title: Text(
                  videoKey == 'expressionVideo' ? 'Mimik Videosu Çek' : 'Video Çek',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.video_library_rounded, color: AppTheme.accent),
                title: Text(
                  'Galeriden Seç',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (selectedSource == null) return;

      final String? videoPath;
      if (selectedSource == ImageSource.camera) {
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
          source: ImageSource.gallery,
          maxDuration: videoKey == 'expressionVideo'
              ? const Duration(seconds: 50)
              : (videoKey == 'showreel'
                  ? const Duration(minutes: 4)
                  : (videoKey == 'performanceVideo'
                      ? const Duration(minutes: 2)
                      : (videoKey == 'introVideo'
                          ? const Duration(seconds: 30)
                          : const Duration(seconds: 20)))),
        );
        videoPath = xFile?.path;
      }

      if (videoPath == null || videoPath.isEmpty) return;

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
      final success = await provider.uploadAndCompressProfileVideo(File(videoPath), videoKey);
      setState(() => _processingVideoKey = null);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video başarıyla yüklendi.'), backgroundColor: AppTheme.success),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'Video yüklenemedi.'), backgroundColor: AppTheme.error),
        );
      }
    } catch (e) {
      setState(() => _processingVideoKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Video seçilemedi: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Widget _buildInlineEditTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildInlineEditDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: AppTheme.surfaceCard,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isSectionLocked(ActorProfileModel profile, String sectionKey) {
    if (widget.isOwner) return false; // Sahibi her şeyi görür
    return profile.lockedSections[sectionKey] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profileProvider = context.watch<ActorProfileProvider>();

    // Eğer sahibi ise provider'daki güncel profili al, değilse parametreyle geleni kullan
    final profile = widget.isOwner ? profileProvider.profile : (_loadedActor ?? widget.actor);

    if (profile == null) {
      return const Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    // "Profili Gizle" kontrolü (Sahibi ve admin/director hariç gizliyse engelle)
    final isActorHidden = profile.isHidden;
    final canViewHidden = widget.isOwner || 
        authProvider.isAdmin || 
        authProvider.userRole?.value == 'director' || 
        authProvider.userRole?.value == 'employer';

    if (isActorHidden && !canViewHidden) {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(title: const Text('Profil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 64, color: AppTheme.textTertiary),
                const SizedBox(height: 16),
                Text(
                  'Bu Profil Gizlidir',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Kullanıcı profilini gizlemeyi tercih etmiştir.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isOwner ? 'Profilim (CV)' : 'Oyuncu Profili',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.isOwner) ...[
            IconButton(
              icon: const Icon(Icons.settings, color: AppTheme.accent),
              tooltip: 'Ayarlar ve Politikalar',
              onPressed: () {
                _showActorSettingsBottomSheet(context);
              },
            ),
            IconButton(
              icon: const Icon(Icons.account_balance_outlined, color: AppTheme.accent),
              tooltip: 'Banka Hesap Bilgileri',
              onPressed: () {
                _showBankAccountDialog(context, profile, profileProvider);
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_note, color: AppTheme.accent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActorProfileEditScreen()),
                );
              },
            ),
          ]
          else if (authProvider.isAdmin || authProvider.isModerator)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.accent),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      actorId: profile.uid,
                      actorName: profile.fullName,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // 1. ÜST ALAN: Profil Resmi, İsim, Şehir ve Gizlilik Durumu
            _buildProfileHeader(profile, profileProvider),

            // 2. KISAYOL İCONLARI (Scroll Tetikleyiciler)
            _buildQuickNavIcons(),

            // 3. FOTOĞRAFLAR (PORTFOLYO GALERİSİ)
            if (!_isSectionLocked(profile, 'gallery')) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildSectionHeader(
                  'Fotoğraflar',
                  Icons.photo_library,
                  profile,
                  'gallery',
                  profileProvider,
                  isEditing: _isGalleryEditing,
                  onEditPressed: widget.isOwner ? () => setState(() => _isGalleryEditing = !_isGalleryEditing) : null,
                ),
              ),
              const SizedBox(height: 10),
              _buildPortfolioGallery(profile, profileProvider),
            ] else if (!authProvider.isActor || widget.isOwner) ...[
              _buildLockedPlaceholder('Fotoğraflar'),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 4. HAKKINDA / BİYOGRAFİ BÖLÜMÜ
                  if (!_isSectionLocked(profile, 'bio')) ...[
                    _buildBioSection(profile, profileProvider),
                    const SizedBox(height: 24),
                  ] else if (!authProvider.isActor || widget.isOwner) ...[
                    _buildLockedPlaceholder('Hakkımda'),
                    const SizedBox(height: 24),
                  ],

                  // 5. FİZİKSEL ÖZELLİKLER BÖLÜMÜ
                  if (!_isSectionLocked(profile, 'physical')) ...[
                    _buildPhysicalSection(profile, profileProvider),
                    const SizedBox(height: 24),
                  ] else if (!authProvider.isActor || widget.isOwner) ...[
                    _buildLockedPlaceholder('Fiziksel Özellikler'),
                    const SizedBox(height: 24),
                  ],

                  // 5.5. İLETİŞİM & BANKA HESAP BİLGİLERİ (Sadece Sahibi ve Adminler Görür)
                  if (widget.isOwner || authProvider.isAdmin || authProvider.isModerator) ...[
                    _buildContactAndBankSection(profile, profileProvider, authProvider.isAdmin || authProvider.isModerator),
                    const SizedBox(height: 24),
                  ],



                  // 8. FİLMOGRAFİ / ROL ALDIĞI İŞLER BÖLÜMÜ
                  if (!_isSectionLocked(profile, 'filmography')) ...[
                    _buildFilmographySection(profile, profileProvider),
                    const SizedBox(height: 24),
                  ] else if (!authProvider.isActor || widget.isOwner) ...[
                    _buildLockedPlaceholder('Filmografi'),
                    const SizedBox(height: 24),
                  ],

                  // 8.5. SOSYAL MEDYA BÖLÜMÜ
                  if (!_isSectionLocked(profile, 'social') && (profile.instagramHandle != null || profile.tiktokHandle != null || profile.xHandle != null)) ...[
                    _buildSocialMediaSection(profile),
                    const SizedBox(height: 24),
                  ],

                  // 9. VİDEOLAR BÖLÜMÜ (Tanıtım, Showreel, Performans, Mimik)
                  if (!_isSectionLocked(profile, 'videos')) ...[
                    _buildVideosSection(profile, profileProvider),
                  ] else if (!authProvider.isActor || widget.isOwner) ...[
                    _buildLockedPlaceholder('Video Galerisi'),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // WİDGET PARÇALARI
  // ═══════════════════════════════════════

  Widget _buildProfileHeader(ActorProfileModel profile, ActorProfileProvider provider) {
    if (_isHeaderEditing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryDark, AppTheme.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Profile photo editor
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                    boxShadow: AppTheme.glowAccent,
                  ),
                  child: ClipOval(
                    child: profile.profilePhotoUrl != null
                        ? (profile.profilePhotoUrl!.startsWith('http')
                            ? Image.network(profile.profilePhotoUrl!, fit: BoxFit.cover)
                            : Image.file(File(profile.profilePhotoUrl!), fit: BoxFit.cover))
                        : Container(
                            color: AppTheme.surfaceLight,
                            child: Center(
                              child: Text(
                                _getInitials(profile.fullName),
                                style: GoogleFonts.outfit(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _pickProfilePhotoDirect(provider),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInlineEditTextField(
              controller: _fullNameController,
              label: 'Ad Soyad',
              icon: Icons.person,
            ),
            const SizedBox(height: 12),
            _buildInlineEditTextField(
              controller: _phoneController,
              label: 'Telefon',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            _buildInlineEditTextField(
              controller: _cityController,
              label: 'Şehir',
              icon: Icons.location_city,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _isHeaderEditing = false),
                  child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _saveHeader(provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Profili Gizle Switche (Sadece Sahibi İçin)
              if (widget.isOwner)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              profile.isHidden ? Icons.visibility_off : Icons.visibility,
                              color: profile.isHidden ? AppTheme.warning : AppTheme.success,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Profili Komple Gizle',
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: profile.isHidden,
                            activeColor: AppTheme.accent,
                            onChanged: (val) {
                              provider.toggleProfileVisibility(val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Spacer(),
              if (widget.isOwner) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.accent, size: 20),
                  onPressed: () => _startHeaderEditing(profile),
                ),
              ]
            ],
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          // Profil Resmi Kilit ve Görseli
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (widget.isOwner) {
                    _startHeaderEditing(profile);
                  }
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.6),
                      width: 2.5,
                    ),
                    boxShadow: AppTheme.glowAccent,
                  ),
                  child: ClipOval(
                    child: profile.profilePhotoUrl != null
                        ? (profile.profilePhotoUrl!.startsWith('http')
                            ? Image.network(profile.profilePhotoUrl!, fit: BoxFit.cover)
                            : Image.file(File(profile.profilePhotoUrl!), fit: BoxFit.cover))
                        : Container(
                            color: AppTheme.surfaceLight,
                            child: Center(
                              child: Text(
                                _getInitials(profile.fullName),
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              if (widget.isOwner)
                Positioned(
                  right: 0,
                  top: 0,
                  child: _buildLockIcon(profile, 'profilePhoto', provider),
                ),
            ],
          ).animate().scale(begin: const Offset(0.9, 0.9), duration: 400.ms),

          const SizedBox(height: 14),

          // İsim
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isOwner) ...[
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.accent, size: 18),
                  onPressed: () => _startHeaderEditing(profile),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.only(right: 8),
                ),
              ],
              Text(
                profile.fullName,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Konum / Şehir
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 14, color: AppTheme.textTertiary),
              const SizedBox(width: 4),
              Text(
                '${profile.city ?? 'Belirtilmedi'}/${profile.country ?? 'Türkiye'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          if (profile.isHidden && widget.isOwner) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '🔒 Profiliniz Arama Sonuçlarında Gizlidir',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickNavIcons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildNavIconButton(
            Icons.badge_outlined,
            'CV',
            () => _scrollToSection(_detailsSectionKey),
          ),
          const SizedBox(width: 24),
          _buildNavIconButton(
            Icons.play_circle_outline,
            'Videolar',
            () => _scrollToSection(_videosSectionKey),
          ),
          const SizedBox(width: 24),
          _buildNavIconButton(
            Icons.history,
            'Deneyim',
            () => _scrollToSection(_filmographySectionKey),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildNavIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: AppTheme.accent),
        ),
      ),
    );
  }

  // PORTFOLYO FOTOĞRAFLARI GRID DÜZENİ
  Widget _buildPortfolioGallery(ActorProfileModel profile, ActorProfileProvider provider) {
    final urls = profile.galleryPhotoUrls;

    if (_isGalleryEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Görselleri Yönet (Silmek için çöpe dokunun, en fazla 10 adet)',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: urls.length + 1,
                itemBuilder: (context, idx) {
                  if (idx == urls.length) {
                    if (urls.length >= 10) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () => _pickGalleryPhotoDirect(provider),
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.add_photo_alternate, color: AppTheme.accent, size: 28),
                      ),
                    );
                  }
                  
                  final url = urls[idx];
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: url.startsWith('http')
                              ? Image.network(url, fit: BoxFit.cover)
                              : Image.file(File(url), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () async {
                            final success = await provider.deleteGalleryPhoto(idx);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Fotoğraf silindi.'), backgroundColor: AppTheme.success),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete, color: AppTheme.error, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() => _isGalleryEditing = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (urls.isEmpty) {
      return GestureDetector(
        onTap: () {
          if (widget.isOwner) {
            setState(() {
              _isGalleryEditing = true;
            });
          }
        },
        child: Container(
          height: 180,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppTheme.textTertiary),
                const SizedBox(height: 8),
                Text(
                  widget.isOwner
                      ? 'Portfolyo Fotoğrafı Eklemek İçin Tıklayın'
                      : 'Portfolyo Fotoğrafı Eklenmemiş',
                  style: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Fotoğrafları 3'lü gruplar halinde sayfalayalım
    final List<List<String>> pages = [];
    for (int i = 0; i < urls.length; i += 3) {
      pages.add(urls.sublist(i, (i + 3).clamp(0, urls.length)));
    }

    return Column(
      children: [
        SizedBox(
          height: 380,
          child: PageView.builder(
            itemCount: pages.length,
            itemBuilder: (context, pageIdx) {
              final pagePhotos = pages[pageIdx];
              return _buildCastingPhotoGrid(pagePhotos);
            },
          ),
        ),
        if (pages.length > 1) ...[
          const SizedBox(height: 8),
          Text(
            '← Diğer görseller için kaydırın →',
            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
          ),
        ],
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  Widget _buildCastingPhotoGrid(List<String> photos) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = 380.0;

          if (photos.length == 1) {
            // Sadece 1 fotoğraf var, tam ekran
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              child: _buildGalleryImage(photos[0], width, height),
            );
          } else if (photos.length == 2) {
            // 2 fotoğraf var, yan yana
            return Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: _buildGalleryImage(photos[0], width / 2, height),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: _buildGalleryImage(photos[1], width / 2, height),
                  ),
                ),
              ],
            );
          } else {
            // 3 fotoğraf var: Sol taraf dikey büyük, sağ taraf alt alta 2 adet kare/yatay
            final leftWidth = width * 0.58;
            final rightWidth = width * 0.40;

            return Row(
              children: [
                // Sol Dikey Büyük
                SizedBox(
                  width: leftWidth,
                  height: height,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusMd),
                      bottomLeft: Radius.circular(AppTheme.radiusMd),
                    ),
                    child: _buildGalleryImage(photos[0], leftWidth, height),
                  ),
                ),
                const SizedBox(width: 8),
                // Sağ Alt Alta 2 Küçük
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: (height - 8) / 2,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(AppTheme.radiusMd),
                          ),
                          child: _buildGalleryImage(photos[1], rightWidth, (height - 8) / 2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: (height - 8) / 2,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomRight: Radius.circular(AppTheme.radiusMd),
                          ),
                          child: _buildGalleryImage(photos[2], rightWidth, (height - 8) / 2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildGalleryImage(String url, double width, double height) {
    return GestureDetector(
      onTap: () => _showImageOverlay(url),
      child: url.startsWith('http')
          ? Image.network(
              url,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: AppTheme.surfaceLight, child: const Icon(Icons.broken_image)),
            )
          : Image.file(
              File(url),
              width: width,
              height: height,
              fit: BoxFit.cover,
            ),
    );
  }

  void _showImageOverlay(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black87,
              ),
            ),
            InteractiveViewer(
              child: url.startsWith('http')
                  ? Image.network(url)
                  : Image.file(File(url)),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BİYOGRAFİ BÖLÜMÜ
  Widget _buildBioSection(ActorProfileModel profile, ActorProfileProvider provider) {
    if (_isBioEditing) {
      return Column(
        key: _detailsSectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Hakkımda',
            Icons.info_outline,
            profile,
            'bio',
            provider,
            isEditing: true,
            onEditPressed: () => setState(() => _isBioEditing = false),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 500,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Kendinizi kısaca tanıtın...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isBioEditing = false),
                      child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _saveBio(provider),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      key: _detailsSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Hakkımda',
          Icons.info_outline,
          profile,
          'bio',
          provider,
          isEditing: false,
          onEditPressed: widget.isOwner ? () => _startBioEditing(profile) : null,
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Text(
            profile.bio ?? 'Biyografi belirtilmemiş.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // FİZİKSEL BİLGİLER BÖLÜMÜ
  Widget _buildPhysicalSection(ActorProfileModel profile, ActorProfileProvider provider) {
    if (_isPhysicalEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Fiziksel Özellikler',
            Icons.accessibility_new,
            profile,
            'physical',
            provider,
            isEditing: true,
            onEditPressed: () => setState(() => _isPhysicalEditing = false),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineEditTextField(
                        controller: _ageController,
                        label: 'Yaş',
                        icon: Icons.cake,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineEditDropdown<Gender>(
                        label: 'Cinsiyet',
                        value: _editGender,
                        items: Gender.values
                            .map((g) => DropdownMenuItem(value: g, child: Text(g.displayName)))
                            .toList(),
                        onChanged: (v) => setState(() => _editGender = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineEditTextField(
                        controller: _heightController,
                        label: 'Boy (cm)',
                        icon: Icons.height,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineEditTextField(
                        controller: _weightController,
                        label: 'Kilo (kg)',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineEditDropdown<EyeColor>(
                        label: 'Göz Rengi',
                        value: _editEyeColor,
                        items: EyeColor.values
                            .map((e) => DropdownMenuItem(value: e, child: Text(e.displayName)))
                            .toList(),
                        onChanged: (v) => setState(() => _editEyeColor = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInlineEditDropdown<HairColor>(
                        label: 'Saç Rengi',
                        value: _editHairColor,
                        items: HairColor.values
                            .map((h) => DropdownMenuItem(value: h, child: Text(h.displayName)))
                            .toList(),
                        onChanged: (v) => setState(() => _editHairColor = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isPhysicalEditing = false),
                      child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _savePhysical(provider),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    final details = <_PhysicalLabel>[];
    if (profile.age != null) details.add(_PhysicalLabel('Yaş', '${profile.age}'));
    if (profile.heightCm != null) details.add(_PhysicalLabel('Boy', '${profile.heightCm} cm'));
    if (profile.weightKg != null) details.add(_PhysicalLabel('Kilo', '${profile.weightKg} kg'));
    if (profile.gender != null) details.add(_PhysicalLabel('Cinsiyet', profile.gender!.displayName));
    if (profile.eyeColor != null) details.add(_PhysicalLabel('Göz Rengi', profile.eyeColor!.displayName));
    if (profile.hairColor != null) details.add(_PhysicalLabel('Saç Rengi', profile.hairColor!.displayName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Fiziksel Özellikler',
          Icons.accessibility_new,
          profile,
          'physical',
          provider,
          isEditing: false,
          onEditPressed: widget.isOwner ? () => _startPhysicalEditing(profile) : null,
        ),
        const SizedBox(height: 10),
        if (details.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Fiziksel özellikler belirtilmemiş.',
              style: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: details.length,
              itemBuilder: (context, index) {
                final d = details[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      d.title,
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.value,
                      style: GoogleFonts.outfit(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  // HOBİLER BÖLÜMÜ
  Widget _buildHobbiesSection(ActorProfileModel profile, ActorProfileProvider provider) {
    if (_isHobbiesEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Hobiler & İlgi Alanları',
            Icons.favorite_border,
            profile,
            'hobbies',
            provider,
            isEditing: true,
            onEditPressed: () => setState(() => _isHobbiesEditing = false),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_editHobbies.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _editHobbies.map((hobi) {
                      return Chip(
                        label: Text(hobi, style: const TextStyle(fontSize: 12)),
                        onDeleted: () {
                          setState(() {
                            _editHobbies.remove(hobi);
                          });
                        },
                        deleteIconColor: AppTheme.error,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
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
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Hobi yazın...',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty && !_editHobbies.contains(val.trim())) {
                            setState(() {
                              _editHobbies.add(val.trim());
                              _hobbyInputController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.accent),
                      onPressed: () {
                        final val = _hobbyInputController.text.trim();
                        if (val.isNotEmpty && !_editHobbies.contains(val)) {
                          setState(() {
                            _editHobbies.add(val);
                            _hobbyInputController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isHobbiesEditing = false),
                      child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _saveHobbies(provider),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Hobiler & İlgi Alanları',
          Icons.favorite_border,
          profile,
          'hobbies',
          provider,
          isEditing: false,
          onEditPressed: widget.isOwner ? () => _startHobbiesEditing(profile) : null,
        ),
        const SizedBox(height: 10),
        if (profile.hobbies.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Hobi eklenmemiş.',
              style: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.hobbies.map((hobi) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  hobi,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // YETENEKLER BÖLÜMÜ
  Widget _buildSkillsSection(ActorProfileModel profile, ActorProfileProvider provider) {
    if (_isSkillsEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Yetenekler',
            Icons.star_outline,
            profile,
            'skills',
            provider,
            isEditing: true,
            onEditPressed: () => setState(() => _isSkillsEditing = false),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                SkillsInputWidget(
                  skills: _editSkills,
                  onSkillsChanged: (updated) {
                    setState(() {
                      _editSkills = updated;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isSkillsEditing = false),
                      child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _saveSkills(provider),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Yetenekler',
          Icons.star_outline,
          profile,
          'skills',
          provider,
          isEditing: false,
          onEditPressed: widget.isOwner ? () => _startSkillsEditing(profile) : null,
        ),
        const SizedBox(height: 10),
        if (profile.skills.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Yetenek eklenmemiş.',
              style: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.skills.map((yetenek) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                child: Text(
                  yetenek,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // FİZİKSEL BİLGİLER BÖLÜMÜ
  // FİLMOGRAFİ BÖLÜMÜ (Rol aldığı işler)
  Widget _buildFilmographySection(ActorProfileModel profile, ActorProfileProvider provider) {
    if (_isFilmographyEditing) {
      return Column(
        key: _filmographySectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Rol Aldığı İşler / Projeler',
            Icons.movie_outlined,
            profile,
            'filmography',
            provider,
            isEditing: true,
            onEditPressed: () => setState(() => _isFilmographyEditing = false),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // List of current items to delete
                if (_editFilmography.isNotEmpty) ...[
                  Text(
                    'Projeleri Yönet (Silmek için çöpe tıklayın)',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(_editFilmography.length, (idx) {
                    final item = _editFilmography[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item['year'] ?? ''} - ${item['projectType'] ?? ''}: ${item['projectTitle'] ?? ''} (${item['director'] ?? 'Yönetmen belirtilmedi'})',
                              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                            onPressed: () {
                              setState(() {
                                _editFilmography.removeAt(idx);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                ],
                // Add New Project Form Inline
                Text(
                  'Yeni Proje Ekle',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildInlineEditTextField(
                  controller: _newProjectTitleController,
                  label: 'Proje Adı',
                  icon: Icons.movie_creation_outlined,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildInlineEditTextField(
                        controller: _newProjectYearController,
                        label: 'Yıl',
                        icon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildInlineEditDropdown<String>(
                        label: 'Tür',
                        value: _newProjectType,
                        items: const [
                          DropdownMenuItem(value: 'Dizi', child: Text('Dizi')),
                          DropdownMenuItem(value: 'Sinema', child: Text('Sinema')),
                          DropdownMenuItem(value: 'Reklam', child: Text('Reklam')),
                          DropdownMenuItem(value: 'Tiyatro', child: Text('Tiyatro')),
                          DropdownMenuItem(value: 'Klip', child: Text('Klip')),
                          DropdownMenuItem(value: 'Kısa Film', child: Text('Kısa Film')),
                          DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                        ],
                        onChanged: (v) => setState(() => _newProjectType = v ?? 'Dizi'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildInlineEditTextField(
                  controller: _newProjectDirectorController,
                  label: 'Yönetmen',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                _buildInlineEditTextField(
                  controller: _newProjectLinkController,
                  label: 'Proje Linki (Opsiyonel)',
                  icon: Icons.link,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final year = _newProjectYearController.text.trim();
                    final title = _newProjectTitleController.text.trim();
                    final director = _newProjectDirectorController.text.trim();
                    if (year.isEmpty || title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yıl ve Proje Adı alanları zorunludur.'), backgroundColor: AppTheme.warning),
                      );
                      return;
                    }
                    setState(() {
                      _editFilmography.add({
                        'year': year,
                        'projectType': _newProjectType,
                        'projectTitle': title,
                        'director': director.isEmpty ? 'Belirtilmedi' : director,
                        'projectLink': _newProjectLinkController.text.trim(),
                      });
                      _newProjectYearController.clear();
                      _newProjectTitleController.clear();
                      _newProjectDirectorController.clear();
                      _newProjectLinkController.clear();
                      _newProjectType = 'Dizi';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proje listeye eklendi.'), backgroundColor: AppTheme.success),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Listeye Ekle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isFilmographyEditing = false),
                      child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _saveFilmography(provider),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }

    final list = profile.filmography;
    
    if (list.isEmpty) {
      return Column(
        key: _filmographySectionKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Rol Aldığı İşler / Projeler',
            Icons.movie_outlined,
            profile,
            'filmography',
            provider,
            isEditing: false,
            onEditPressed: widget.isOwner ? () => _startFilmographyEditing(profile) : null,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.movie_creation_outlined, size: 36, color: AppTheme.textTertiary),
                  const SizedBox(height: 8),
                  Text(
                    'Eklenmiş proje bulunmuyor.',
                    style: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Group by category
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in list) {
      final type = item['projectType']?.toString() ?? 'Diğer';
      if (!grouped.containsKey(type)) {
        grouped[type] = [];
      }
      grouped[type]!.add(item);
    }

    // Sort projects within each category by year descending
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final yA = int.tryParse(a['year']?.toString() ?? '0') ?? 0;
        final yB = int.tryParse(b['year']?.toString() ?? '0') ?? 0;
        return yB.compareTo(yA); // Newest first
      });
    }

    // Fixed order of categories
    final categoryOrder = ['Dizi', 'Sinema', 'Reklam', 'Tiyatro', 'Klip', 'Kısa Film', 'Diğer'];
    final sortedCategories = grouped.keys.toList()
      ..sort((a, b) {
        final idxA = categoryOrder.indexOf(a);
        final idxB = categoryOrder.indexOf(b);
        if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
        if (idxA != -1) return -1;
        if (idxB != -1) return 1;
        return a.compareTo(b);
      });

    return Column(
      key: _filmographySectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Rol Aldığı İşler / Projeler',
          Icons.movie_outlined,
          profile,
          'filmography',
          provider,
          isEditing: false,
          onEditPressed: widget.isOwner ? () => _startFilmographyEditing(profile) : null,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(sortedCategories.length, (catIdx) {
              final category = sortedCategories[catIdx];
              final categoryProjects = grouped[category]!;
              final isLastCategory = catIdx == sortedCategories.length - 1;

              return Padding(
                padding: EdgeInsets.only(bottom: isLastCategory ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kategori Başlığı
                    Row(
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Proje Listesi
                    ...categoryProjects.map((project) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Yıl
                            SizedBox(
                              width: 42,
                              child: Text(
                                project['year']?.toString() ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                            // Dikey Ayraç
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 1,
                              height: 12,
                              color: AppTheme.border.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 12),
                            // Proje Adı & Yönetmen
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: project['projectLink'] != null && project['projectLink'].toString().isNotEmpty
                                          ? () => _launchProjectUrl(project['projectLink'].toString())
                                          : null,
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: AppTheme.textPrimary,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: project['projectTitle']?.toString() ?? '',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: (project['projectLink'] != null && project['projectLink'].toString().isNotEmpty)
                                                    ? AppTheme.accent
                                                    : AppTheme.textPrimary,
                                                decoration: (project['projectLink'] != null && project['projectLink'].toString().isNotEmpty)
                                                    ? TextDecoration.underline
                                                    : TextDecoration.none,
                                              ),
                                            ),
                                            if (project['director'] != null &&
                                                project['director'].toString().isNotEmpty &&
                                                project['director'].toString() != 'Belirtilmedi')
                                              TextSpan(
                                                text: '  •  Yönetmen: ${project['director']}',
                                                style: const TextStyle(
                                                  color: AppTheme.textTertiary,
                                                  fontWeight: FontWeight.w400,
                                                  fontSize: 11.5,
                                                  decoration: TextDecoration.none,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (project['projectLink'] != null && project['projectLink'].toString().isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: project['projectLink'].toString()));
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
                            ),
                          ],
                        ),
                      );
                    }),
                    if (!isLastCategory) ...[
                      const SizedBox(height: 12),
                      Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.15)),
                    ],
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // VİDEOLAR BÖLÜMÜ
  Widget _buildVideosSection(ActorProfileModel profile, ActorProfileProvider provider) {
    return Column(
      key: _videosSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Video Galerisi',
          Icons.play_circle_outline,
          profile,
          'videos',
          provider,
          isEditing: _isVideosEditing,
          onEditPressed: widget.isOwner ? () => setState(() => _isVideosEditing = !_isVideosEditing) : null,
        ),
        const SizedBox(height: 10),

        // 1. Tanıtım Videosu
        _buildVideoCard(
          title: 'Tanıtım Videosu (30s)',
          videoUrl: profile.introVideoUrl,
          lockedKey: 'introVideo',
          profile: profile,
          provider: provider,
        ),
        const SizedBox(height: 12),

        // 2. Showreel
        _buildVideoCard(
          title: 'Showreel (4dk)',
          videoUrl: profile.showreelVideoUrl,
          lockedKey: 'showreel',
          profile: profile,
          provider: provider,
        ),
        const SizedBox(height: 12),

        // 3. Performans Videosu
        _buildVideoCard(
          title: 'Performans Videosu (2dk)',
          videoUrl: profile.performanceVideoUrl,
          lockedKey: 'performanceVideo',
          profile: profile,
          provider: provider,
        ),
        const SizedBox(height: 12),

        // 4. Mimik Videosu
        _buildVideoCard(
          title: 'Mimik Videosu',
          videoUrl: profile.expressionVideoUrl,
          lockedKey: 'expressionVideo',
          profile: profile,
          provider: provider,
        ),
      ],
    );
  }

  Widget _buildVideoCard({
    required String title,
    required String? videoUrl,
    required String lockedKey,
    required ActorProfileModel profile,
    required ActorProfileProvider provider,
  }) {
    final isLocked = _isSectionLocked(profile, lockedKey);

    if (isLocked) {
      return _buildLockedPlaceholder(title);
    }

    final hasVideo = videoUrl != null && videoUrl.isNotEmpty;
    final isProcessingThis = _processingVideoKey == lockedKey && provider.isProcessing;

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
                  const Icon(Icons.movie, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (widget.isOwner)
                _buildLockIcon(profile, lockedKey, provider),
            ],
          ),
          const SizedBox(height: 10),
          if (isProcessingThis) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: provider.isCompressing ? provider.compressProgress : provider.uploadProgress,
                    backgroundColor: AppTheme.border,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.isCompressing
                        ? 'Video Sıkıştırılıyor (%${(provider.compressProgress * 100).toStringAsFixed(0)})...'
                        : 'Video Yükleniyor (%${(provider.uploadProgress * 100).toStringAsFixed(0)})...',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ] else ...[
            if (hasVideo) ...[
              _buildVideoPlayerWidget(videoUrl, title),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildSmallIconButton(
                    icon: Icons.file_download_outlined,
                    color: AppTheme.accent,
                    tooltip: 'Videoyu İndir',
                    onTap: () => _downloadVideoFile(context, videoUrl, title),
                  ),
                  if (_isVideosEditing) ...[
                    const SizedBox(width: 8),
                    _buildSmallIconButton(
                      icon: Icons.refresh_rounded,
                      color: Colors.orange,
                      tooltip: 'Videoyu Değiştir',
                      onTap: () => _pickProfileVideoDirect(provider, lockedKey),
                    ),
                    const SizedBox(width: 8),
                    _buildSmallIconButton(
                      icon: Icons.delete_outline_rounded,
                      color: AppTheme.error,
                      tooltip: 'Videoyu Sil',
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppTheme.surfaceCard,
                            title: Text('Videoyu Sil', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            content: Text('$title videosunu silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                                child: const Text('Sil'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final success = await provider.deleteProfileVideo(lockedKey);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$title başarıyla silindi.'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ] else ...[
              GestureDetector(
                onTap: widget.isOwner ? () => _pickProfileVideoDirect(provider, lockedKey) : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: widget.isOwner ? Border.all(color: AppTheme.accent.withValues(alpha: 0.3), style: BorderStyle.solid) : null,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          widget.isOwner ? Icons.cloud_upload_outlined : Icons.play_circle_outline,
                          size: 28,
                          color: widget.isOwner ? AppTheme.accent : AppTheme.textTertiary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.isOwner
                              ? 'Video Yüklemek İçin Dokunun'
                              : 'Video eklenmemiş.',
                          style: GoogleFonts.inter(
                            color: widget.isOwner ? AppTheme.accent : AppTheme.textTertiary,
                            fontSize: 13,
                            fontWeight: widget.isOwner ? FontWeight.w500 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVideoPlayerWidget(String videoUrl, String title) {
    return _ProfileInlineVideoPlayer(videoUrl: videoUrl, title: title);
  }

  Widget _buildSmallIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // KİLİT VE GİZLİLİK YARDIMCILARI
  // ═══════════════════════════════════════

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    ActorProfileModel profile,
    String lockKey,
    ActorProfileProvider provider, {
    bool isEditing = false,
    VoidCallback? onEditPressed,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (widget.isOwner && onEditPressed != null) ...[
              IconButton(
                icon: Icon(
                  isEditing ? Icons.close : Icons.edit,
                  size: 18,
                  color: isEditing ? AppTheme.error : AppTheme.accent,
                ),
                onPressed: onEditPressed,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(right: 8),
              ),
            ],
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 16, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        if (widget.isOwner)
          _buildLockIcon(profile, lockKey, provider),
      ],
    );
  }

  Widget _buildLockIcon(ActorProfileModel profile, String sectionKey, ActorProfileProvider provider) {
    final isLocked = profile.lockedSections[sectionKey] ?? false;
    return GestureDetector(
      onTap: () {
        provider.toggleSectionLock(sectionKey);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isLocked
                  ? 'Bölüm herkese açık hale getirildi.'
                  : 'Bölüm kilitlendi. Sadece siz görebilirsiniz.',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: isLocked ? AppTheme.success : AppTheme.warning,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isLocked
              ? AppTheme.error.withValues(alpha: 0.15)
              : AppTheme.success.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isLocked ? Icons.lock : Icons.lock_open,
          size: 16,
          color: isLocked ? AppTheme.error : AppTheme.success,
        ),
      ),
    );
  }

  Widget _buildLockedPlaceholder(String sectionName) {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isActor && !widget.isOwner) {
        return const SizedBox.shrink();
      }
    } catch (_) {}

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 18, color: AppTheme.textTertiary),
          const SizedBox(width: 12),
          Text(
            '$sectionName (Kullanıcı Tarafından Gizlendi)',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showBankAccountDialog(BuildContext context, ActorProfileModel profile, ActorProfileProvider provider) {
    final holderController = TextEditingController(text: profile.bankAccountHolder ?? '');
    final ibanController = TextEditingController(text: profile.bankIban ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Row(
          children: [
            const Icon(Icons.account_balance_outlined, color: AppTheme.accent),
            const SizedBox(width: 10),
            Text(
              'Banka Hesap Bilgileri',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'İşi almanız durumunda ödemenin yatacağı hesap bilgilerini giriniz.',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: holderController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Hesap Sahibi Adı Soyadı',
                  prefixIcon: Icon(Icons.person_outline, size: 18),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Hesap sahibi gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ibanController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'IBAN Numarası',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  hintText: 'TR...',
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'IBAN numarası gerekli' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final updated = profile.copyWith(
                bankAccountHolder: holderController.text.trim(),
                bankIban: ibanController.text.trim(),
              );
              final success = await provider.saveProfile(updated);
              if (ctx.mounted) Navigator.pop(ctx);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Banka hesap bilgileri kaydedildi.'), backgroundColor: AppTheme.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactAndBankSection(ActorProfileModel profile, ActorProfileProvider provider, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.lock_outline, size: 16, color: AppTheme.accent),
                ),
                const SizedBox(width: 10),
                Text(
                  'İletişim & Banka Bilgileri',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '🔐 Sadece Admin & Siz',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İLETİŞİM BİLGİLERİ',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.email_outlined, size: 18, color: AppTheme.textSecondary),
                ),
                title: Text(
                  'E-posta',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                ),
                subtitle: Text(
                  profile.email,
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.textTertiary),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: profile.email));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('E-posta kopyalandı.')),
                    );
                  },
                ),
              ),
              
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_outlined, size: 18, color: AppTheme.textSecondary),
                ),
                title: Text(
                  'Telefon',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                ),
                subtitle: Text(
                  profile.phone.isNotEmpty ? profile.phone : 'Belirtilmedi',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (profile.phone.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.phone, size: 16, color: AppTheme.success),
                        onPressed: () => _launchSocialUrl('tel:${profile.phone}'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16, color: AppTheme.textTertiary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: profile.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Telefon numarası kopyalandı.')),
                        );
                      },
                    ),
                  ],
                ),
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.contact_phone_outlined, size: 18, color: AppTheme.textSecondary),
                ),
                title: Text(
                  'Ulaşılamazsa Aranacak Kişi',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                ),
                subtitle: Text(
                  (profile.emergencyPhone != null && profile.emergencyPhone!.isNotEmpty)
                      ? profile.emergencyPhone!
                      : 'Belirtilmedi',
                  style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (profile.emergencyPhone != null && profile.emergencyPhone!.isNotEmpty) ...[
                      IconButton(
                        icon: const Icon(Icons.phone, size: 16, color: AppTheme.success),
                        onPressed: () => _launchSocialUrl('tel:${profile.emergencyPhone}'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16, color: AppTheme.textTertiary),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: profile.emergencyPhone!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Alternatif telefon kopyalandı.')),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 24),
              
              Text(
                'BANKA HESAP BİLGİLERİ (ÖDEME HESABI)',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              if (profile.bankIban != null && profile.bankIban!.isNotEmpty) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_pin_outlined, size: 18, color: AppTheme.textSecondary),
                  ),
                  title: Text(
                    'Hesap Sahibi',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                  ),
                  subtitle: Text(
                    profile.bankAccountHolder ?? 'Belirtilmedi',
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: AppTheme.textTertiary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: profile.bankAccountHolder ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hesap sahibi kopyalandı.')),
                      );
                    },
                  ),
                ),
                
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppTheme.textSecondary),
                  ),
                  title: Text(
                    'IBAN',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                  ),
                  subtitle: Text(
                    profile.bankIban!,
                    style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: AppTheme.textTertiary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: profile.bankIban!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('IBAN kopyalandı.')),
                      );
                    },
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Banka hesap bilgileri girilmemiş.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialMediaSection(ActorProfileModel profile) {
    String cleanHandle(String? handle) {
      if (handle == null) return '';
      return handle.replaceAll('@', '').trim();
    }

    final hasInsta = profile.instagramHandle != null && profile.instagramHandle!.isNotEmpty;
    final hasTiktok = profile.tiktokHandle != null && profile.tiktokHandle!.isNotEmpty;
    final hasX = profile.xHandle != null && profile.xHandle!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.share, size: 16, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Text(
              'Sosyal Medya',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              if (hasInsta) ...[
                _buildSocialTile(
                  icon: Icons.camera_alt_outlined,
                  name: 'Instagram',
                  handle: profile.instagramHandle!,
                  url: 'https://instagram.com/${cleanHandle(profile.instagramHandle)}',
                ),
                if (hasTiktok || hasX) const Divider(height: 16),
              ],
              if (hasTiktok) ...[
                _buildSocialTile(
                  icon: Icons.music_note_outlined,
                  name: 'TikTok',
                  handle: profile.tiktokHandle!,
                  url: 'https://tiktok.com/@${cleanHandle(profile.tiktokHandle)}',
                ),
                if (hasX) const Divider(height: 16),
              ],
              if (hasX) ...[
                _buildSocialTile(
                  icon: Icons.alternate_email,
                  name: 'X (Twitter)',
                  handle: profile.xHandle!,
                  url: 'https://x.com/${cleanHandle(profile.xHandle)}',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialTile({
    required IconData icon,
    required String name,
    required String handle,
    required String url,
  }) {
    return InkWell(
      onTap: () => _launchSocialUrl(url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppTheme.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: AppTheme.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    handle.startsWith('@') ? handle : '@$handle',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }

  Future<void> _launchSocialUrl(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint('Could not launch URL: $e');
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _launchProjectUrl(String urlString) async {
    if (urlString.isEmpty) return;
    var uri = Uri.tryParse(urlString);
    if (uri != null) {
      if (!uri.hasScheme) {
        uri = Uri.tryParse('https://$urlString');
      }
      if (uri != null) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            await launchUrl(uri);
          }
        } catch (e) {
          debugPrint('Could not launch URL: $e');
        }
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

class _PhysicalLabel {
  final String title;
  final String value;
  _PhysicalLabel(this.title, this.value);
}

/// Profil içi inline video oynatıcı (Chewie ile)
class _ProfileInlineVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;

  const _ProfileInlineVideoPlayer({
    required this.videoUrl,
    required this.title,
  });

  @override
  State<_ProfileInlineVideoPlayer> createState() => _ProfileInlineVideoPlayerState();
}

class _ProfileInlineVideoPlayerState extends State<_ProfileInlineVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInit = false;
  bool _isLoading = false;
  String? _error;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında ön izleme için videoyu otomatik yükle (oynatmadan)
    _initPlayer(autoPlay: false);
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_videoListener);
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  void _videoListener() {
    if (_videoPlayerController == null) return;
    final isPlaying = _videoPlayerController!.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
  }

  Future<void> _initPlayer({bool autoPlay = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final isLocal = widget.videoUrl.startsWith('/') ||
          widget.videoUrl.startsWith('file://') ||
          widget.videoUrl.contains('/data/') ||
          widget.videoUrl.contains('/storage/');

      if (isLocal) {
        final cleanPath = widget.videoUrl.replaceFirst(RegExp(r'^file://'), '');
        _videoPlayerController = VideoPlayerController.file(File(cleanPath));
      } else {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      }

      await _videoPlayerController!.initialize();
      _videoPlayerController!.addListener(_videoListener);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: autoPlay,
        looping: false,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accent,
          handleColor: AppTheme.accent,
          backgroundColor: AppTheme.surfaceElevated,
          bufferedColor: AppTheme.primary.withValues(alpha: 0.3),
        ),
      );

      if (mounted) {
        setState(() {
          _isInit = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Video yüklenemedi: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInit && _chewieController != null && _videoPlayerController != null) {
      return AspectRatio(
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Chewie(controller: _chewieController!),
              if (!_isPlaying)
                GestureDetector(
                  onTap: () {
                    _chewieController!.play();
                  },
                  child: Container(
                    color: Colors.black38, // Ön izleme hafif karartma
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.95),
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowAccent,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: AppTheme.accent)
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.error, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: AppTheme.error, fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () => _initPlayer(autoPlay: false),
                          child: const Text('Tekrar Dene', style: TextStyle(color: AppTheme.accent)),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.play_circle_fill, size: 48, color: AppTheme.accent),
                        onPressed: () => _initPlayer(autoPlay: true),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Videoyu Oynat',
                        style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
      ),
    );
  }
}

  void _showActorSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Ayarlar ve Politikalar',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppTheme.border),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.accent),
                title: Text('Gizlilik Politikası', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  PolicyDialogs.showPrivacyPolicy(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AppTheme.accent),
                title: Text('Kullanım Koşulları', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  PolicyDialogs.showTermsOfUse(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined, color: AppTheme.accent),
                title: Text('KVKK Aydınlatma Metni', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  PolicyDialogs.showKvkk(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cookie_outlined, color: AppTheme.accent),
                title: Text('Çerez Politikası', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  PolicyDialogs.showCookiePolicy(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.error),
                title: Text('Hesabımı Kalıcı Olarak Sil', style: GoogleFonts.inter(color: AppTheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteAccountDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppTheme.textTertiary),
                title: Text('Çıkış Yap', style: GoogleFonts.inter(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showLogoutDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.border, width: 0.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            const SizedBox(width: 8),
            Text(
              'Hesabımı Sil',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppTheme.error,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hesabınızı silmek istediğinizden emin misiniz?',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu işlem kalıcıdır ve geri alınamaz. Profiliniz, tüm video ve fotoğraflarınız kalıcı olarak silinecektir.',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'İptal',
              style: GoogleFonts.inter(color: AppTheme.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingCtx) => const Center(
                  child: CircularProgressIndicator(color: AppTheme.error),
                ),
              );

              final success = await context.read<AuthProvider>().deleteAccount();
              
              // Pop loading dialog
              if (context.mounted) {
                Navigator.pop(context);
              }

              if (success) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hesabınız başarıyla silinmiştir.'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  final err = context.read<AuthProvider>().errorMessage;
                  showDialog(
                    context: context,
                    builder: (errCtx) => AlertDialog(
                      backgroundColor: AppTheme.surfaceCard,
                      title: const Text('Hata'),
                      content: Text(err ?? 'Hesap silinirken bir hata oluştu.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(errCtx),
                          child: const Text('Tamam'),
                        ),
                      ],
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
