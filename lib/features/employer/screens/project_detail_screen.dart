import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/employer/providers/project_provider.dart';
import 'package:castelle/features/employer/screens/project_create_screen.dart';

/// Castelle - Proje Detay Ekranı
/// İş Veren, Admin ve Yönetmenlerin proje ve rol detaylarını görebileceği ekran.
/// Adminler için uygun adayları listeleme ve Audition isteme fonksiyonlarını içerir.

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late ProjectModel _project;
  List<ActorProfileModel> _allActors = [];
  final Map<String, Set<String>> _roleSelectedCandidateIds = {};
  final Set<String> _requestedCandidateRoleKeys = {};
  int _expandedRoleIndex = 0;
  bool _loadingCandidates = false;

  // Bütçe esnekliği toggle — Map<roleName, Set<actorUid>>
  // Set içindekiler için toggle AÇIK (varsayılan tüm adaylar açık)
  final Map<String, Set<String>> _budgetFlexEnabled = {};

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadSuitableCandidates();
  }

  Future<void> _loadSuitableCandidates() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAdminOrModerator) return;

    setState(() => _loadingCandidates = true);

    List<ActorProfileModel> actors = [];
    try {
      // Tüm oyuncuları çek
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'actor')
          .get();

      actors = snapshot.docs
          .map((doc) => ActorProfileModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [ProjectDetailScreen] Actor load error: $e');
    }

    // 4. Daha önce audition talebi gönderilmiş adayları çek
    _requestedCandidateRoleKeys.clear();
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('projectId', isEqualTo: _project.id)
          .where('type', isEqualTo: 'casting_invite')
          .get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final recipientId = data['recipientId'] ?? data['userId'];
        if (recipientId != null) {
          final roleData = data['data'] as Map<String, dynamic>?;
          final roleName = roleData?['roleName'];
          if (roleName != null) {
            _requestedCandidateRoleKeys.add('${recipientId}_$roleName');
          } else {
            _requestedCandidateRoleKeys.add(recipientId.toString());
          }
        }
      }
    } catch (_) {}

    setState(() {
      _allActors = actors;
      _loadingCandidates = false;
      // Her rol için tüm adayların toggle'ını başlat (varsayılan: AÇIK)
      for (final role in _project.roles) {
        final roleCandidates = actors
            .where((a) => _isActorSuitableForRole(a, role))
            .map((a) => a.uid)
            .toSet();
        _budgetFlexEnabled[role.roleName] ??= Set.from(roleCandidates);
      }
    });
  }

  String _normalizeText(String text) {
    return text
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .toLowerCase()
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('ê', 'e')
        .replaceAll('î', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('û', 'u');
  }



  bool _isActorSuitableForRole(ActorProfileModel actor, ProjectRole role) {
    final hasGender = role.gender != null && role.gender!.isNotEmpty;
    final hasAge = role.ageMin != null || role.ageMax != null;

    // 1. Cinsiyet kontrolü
    if (hasGender) {
      if (actor.gender == null ||
          role.gender != actor.gender!.value) {
        return false;
      }
    }

    // 2. Yaş aralığı kontrolü
    if (hasAge) {
      if (actor.age == null) return false;
      if (role.ageMin != null && actor.age! < role.ageMin!) return false;
      if (role.ageMax != null && actor.age! > role.ageMax!) return false;
    }

    return true;
  }

  Future<void> _showAuditionRequestDialogForRole(ProjectRole role) async {
    final authProvider = context.read<AuthProvider>();
    if (!(authProvider.user?.hasModeratorPermission('auditionToplama') ?? true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audition toplama/isteme yetkiniz bulunmamaktadır.'), backgroundColor: AppTheme.error),
      );
      return;
    }

    final selectedIds = _roleSelectedCandidateIds[role.roleName] ?? {};
    if (selectedIds.isEmpty) return;

    // Seçili adaylar için bütçe esnekliği açık mı?
    final budgetFlexSet = _budgetFlexEnabled[role.roleName] ?? {};

    String defaultScript = role.auditionScript ?? '';
    final scriptController = TextEditingController(text: defaultScript);

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceCard,
            title: Text(
              'Audition Talebi Gönder',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '"${role.roleName}" rolü için ${selectedIds.length} adaya talep gönderilecek.',
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),

                  // Audition metni
                  Text(
                    'Audition Metni (Prompter için)',
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: scriptController,
                    maxLines: 6,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Oyuncunun prompter ekranında göreceği metin (opsiyonel)...',
                      hintStyle: const TextStyle(color: AppTheme.textTertiary),
                      fillColor: AppTheme.surfaceLight,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bütçe esnekliği özeti
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppTheme.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${selectedIds.where((id) => budgetFlexSet.contains(id)).length} adaya bütçe değişikliği talebi alanı gösterilecek.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.info),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('Talepleri Gönder'),
              ),
            ],
          );
        },
      ),
    );

    if (proceed == true) {
      _sendAuditionRequestsForRole(role, scriptController.text.trim());
    }
  }

  bool _isCandidateRequestedForRole(String actorId, String roleName) {
    return _requestedCandidateRoleKeys.contains('${actorId}_$roleName') ||
        _requestedCandidateRoleKeys.contains(actorId);
  }

  Future<void> _sendAuditionRequestsForRole(ProjectRole role, String customScript) async {
    final selectedIds = _roleSelectedCandidateIds[role.roleName] ?? {};
    if (selectedIds.isEmpty) return;

    setState(() => _loadingCandidates = true);
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final recipientId in selectedIds) {
        final docRef = FirebaseFirestore.instance.collection('notifications').doc();
        final isBudgetFlex = _budgetFlexEnabled[role.roleName]?.contains(recipientId) ?? false;
        batch.set(docRef, {
          'recipientId': recipientId,
          'userId': recipientId,
          'title': 'Audition Talebi: ${_project.title} - ${role.roleName}',
          'body': 'Admin veya Moderatör tarafından ${_project.title} projesindeki "${role.roleName}" rolü için audition videosu göndermeniz talep edildi. 🎬',
          'type': 'casting_invite',
          'isRead': false,
          'projectId': _project.id,
          'data': {
            'roleName': role.roleName,
            'auditionScript': customScript.isNotEmpty ? customScript : (role.auditionScript ?? ''),
            'budgetFlexible': isBudgetFlex, // Bütçe esnekliği toggle durumu
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        final count = selectedIds.length;
        setState(() {
          for (final recipientId in selectedIds) {
            _requestedCandidateRoleKeys.add('${recipientId}_${role.roleName}');
          }
          selectedIds.clear();
          _loadingCandidates = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count adaya "${role.roleName}" rolü için audition talebi gönderildi! 🎉'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCandidates = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdminOrModerator;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.surface,
            actions: [
              // Düzenle
              if (isAdmin && (authProvider.user?.hasModeratorPermission('duzenlemeYetkisi') ?? true))
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProjectCreateScreen(existingProject: _project),
                      ),
                    );
                    // Güncelleme başarılıysa projeyi yeniden yükle
                    if (updated == true && mounted) {
                      try {
                        final refreshed = await FirebaseFirestore.instance
                            .collection('projects')
                            .doc(_project.id)
                            .get();
                        if (refreshed.exists && mounted) {
                          setState(() {
                            _project = ProjectModel.fromMap(
                                refreshed.data()!, refreshed.id);
                          });
                          _loadSuitableCandidates();
                        }
                      } catch (_) {}
                    }
                  },
                ),
              // Durum değiştir & Sil
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  color: AppTheme.surfaceCard,
                  onSelected: (value) {
                    if (value == 'delete') {
                      if (!(authProvider.user?.hasModeratorPermission('silmeYetkisi') ?? true)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Proje silme yetkiniz bulunmamaktadır.'), backgroundColor: AppTheme.error),
                        );
                        return;
                      }
                      _showDeleteConfirmationDialog(context);
                    } else {
                      if (!(authProvider.user?.hasModeratorPermission('duzenlemeYetkisi') ?? true)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Proje durumunu değiştirme yetkiniz bulunmamaktadır.'), backgroundColor: AppTheme.error),
                        );
                        return;
                      }
                      final status = ProjectStatus.values.firstWhere((s) => s.name == value);
                      _changeStatus(context, status);
                    }
                  },
                  itemBuilder: (_) => [
                    ...ProjectStatus.values.map((s) {
                      return PopupMenuItem<String>(
                        value: s.name,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _statusColor(s),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              s.displayName,
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
                          const SizedBox(width: 10),
                          Text(
                            'Projeyi Sil',
                            style: GoogleFonts.inter(
                              color: AppTheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryDark, AppTheme.surface],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // Proje birincil fotoğrafı veya türü ikonu
                      _buildHeaderImage().animate().scale(
                            begin: const Offset(0.8, 0.8),
                            duration: 400.ms,
                            curve: Curves.elasticOut,
                          ),

                      const SizedBox(height: 10),

                      Text(
                        _project.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // İçerik
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum + Meta
                  _buildMetaRow(context).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 24),

                  // Açıklama
                  if (_project.description != null &&
                      _project.description!.isNotEmpty) ...[
                    _buildSection(
                      'Açıklama',
                      Icons.description_outlined,
                      child: Text(
                        _project.description!,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ).animate().fadeIn(delay: 350.ms),
                    const SizedBox(height: 24),
                  ],

                  // Detaylar
                  _buildSection(
                    'Proje Detayları',
                    Icons.info_outline,
                    child: _buildDetailsGrid(context),
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 24),

                  // Galeri (Carousel)
                  if (_project.galleryImageUrls.isNotEmpty) ...[
                    _buildSection(
                      'Proje Galerisi',
                      Icons.collections_outlined,
                      child: _buildImageGalleryCarousel(context),
                    ).animate().fadeIn(delay: 420.ms),
                    const SizedBox(height: 24),
                  ],

                  // Örnek Video (Video Player)
                  if (_project.sampleVideoUrl != null && _project.sampleVideoUrl!.isNotEmpty) ...[
                    _buildSection(
                      'Örnek/Tanıtım Videosu',
                      Icons.video_collection_outlined,
                      child: _ProjectSampleVideoPlayer(videoUrl: _project.sampleVideoUrl!),
                    ).animate().fadeIn(delay: 440.ms),
                    const SizedBox(height: 24),
                  ],

                  // Roller
                  _buildSection(
                    'Casting Rolleri (${_project.roles.length})',
                    Icons.group_outlined,
                    child: Column(
                      children: _project.roles.asMap().entries.map((entry) {
                        return _buildRoleCard(entry.key, entry.value);
                      }).toList(),
                    ),
                  ).animate().fadeIn(delay: 450.ms),

                  // Uygun Adaylar (Sadece Admin)
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    _buildSection(
                      'Uygun Oyuncu Adayları',
                      Icons.people_outline,
                      child: _buildSuitableCandidatesSection(context),
                    ).animate().fadeIn(delay: 500.ms),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleAccordion(ProjectRole role, int index) {
    // Uygun adayları bul ve yetenek eşleşmesine göre sırala
    final roleCandidates = _allActors
        .where((actor) => _isActorSuitableForRole(actor, role))
        .toList();

    // Yetenek eşleşme sayısını hesapla
    int _skillMatchCount(ActorProfileModel actor) {
      if (role.requiredSkills.isEmpty) return 0;
      final actorSkillsNorm =
          actor.skills.map((s) => _normalizeText(s)).toSet();
      final roleSkillsNorm =
          role.requiredSkills.map((s) => _normalizeText(s)).toSet();
      return actorSkillsNorm.intersection(roleSkillsNorm).length;
    }

    // Eşleşme sayısına göre azalan sırala — eşleşenler üstte
    roleCandidates.sort((a, b) =>
        _skillMatchCount(b).compareTo(_skillMatchCount(a)));

    final isOpen = _expandedRoleIndex == index;

    // Get selected count for this role
    final selectedIds = _roleSelectedCandidateIds[role.roleName] ?? {};
    final unrequestedCandidates = roleCandidates
        .where((c) => !_isCandidateRequestedForRole(c.uid, role.roleName))
        .toList();

    final isAllSelected = unrequestedCandidates.isNotEmpty &&
        selectedIds.length == unrequestedCandidates.length;

    // Eşleşme rozeti oluşturma yardımcısı
    Widget? _matchBadge(ActorProfileModel actor) {
      final count = _skillMatchCount(actor);
      if (count == 0) return null;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt, size: 11, color: Colors.red),
            const SizedBox(width: 2),
            Text(
              '$count yetenek',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
      );
    }


    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isOpen ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border,
          width: isOpen ? 1 : 0.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () {
              setState(() {
                _expandedRoleIndex = isOpen ? -1 : index;
              });
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isOpen ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.surfaceLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_search,
                      size: 18,
                      color: isOpen ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rol ${index + 1} - ${role.roleName}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${roleCandidates.length} Uygun Aday',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          if (isOpen) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roleCandidates.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Bu rolün kriterlerine uygun aday bulunamadı.',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                      ),
                    )
                  else ...[
                                        // Select all & Audition request action row (Responsive Layout)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: isAllSelected,
                              activeColor: AppTheme.accent,
                              checkColor: AppTheme.textOnAccent,
                              onChanged: unrequestedCandidates.isEmpty
                                  ? null
                                  : (val) {
                                      setState(() {
                                        if (val == true) {
                                          _roleSelectedCandidateIds[role.roleName] =
                                              unrequestedCandidates.map((c) => c.uid).toSet();
                                        } else {
                                          _roleSelectedCandidateIds[role.roleName]?.clear();
                                        }
                                      });
                                    },
                            ),
                            Text(
                              'Tümünü Seç (${unrequestedCandidates.length})',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            // Toplu bütçe toggle
                            _buildBulkBudgetToggle(role, unrequestedCandidates),
                          ],
                        ),
                        if (selectedIds.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () => _showAuditionRequestDialogForRole(role),
                              icon: const Icon(Icons.send_outlined, size: 15),
                              label: Text(
                                'Audition İste (${selectedIds.length} Oyuncu)',
                                style: GoogleFonts.outfit(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: AppTheme.textOnAccent,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    // Candidates List for this role
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: roleCandidates.length,
                      itemBuilder: (context, idx) {
                        final actor = roleCandidates[idx];
                        final isSelected = selectedIds.contains(actor.uid);
                        final isRequested = _isCandidateRequestedForRole(actor.uid, role.roleName);

                                                  final hasSkillMatch = _skillMatchCount(actor) > 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isRequested
                                  ? AppTheme.surfaceLight.withOpacity(0.6)
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accent.withValues(alpha: 0.4)
                                    : (hasSkillMatch
                                        ? Colors.red
                                        : AppTheme.border.withValues(alpha: 0.5)),
                                width: isSelected || hasSkillMatch ? 1.0 : 0.5,
                              ),
                            ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isRequested ? false : isSelected,
                                activeColor: AppTheme.accent,
                                checkColor: AppTheme.textOnAccent,
                                onChanged: isRequested
                                    ? null
                                    : (val) {
                                        setState(() {
                                          final currentSet = _roleSelectedCandidateIds[role.roleName] ??= {};
                                          if (val == true) {
                                            currentSet.add(actor.uid);
                                          } else {
                                            currentSet.remove(actor.uid);
                                          }
                                        });
                                      },
                              ),
                              const SizedBox(width: 4),
                              // Avatar
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                backgroundImage: actor.profilePhotoUrl != null
                                    ? NetworkImage(actor.profilePhotoUrl!)
                                    : null,
                                child: actor.profilePhotoUrl == null
                                    ? Text(
                                        actor.fullName.isNotEmpty ? actor.fullName[0].toUpperCase() : '?',
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.accent,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              // Candidate Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // İsim + Bütçe Toggle
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            actor.fullName,
                                            style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isRequested
                                                  ? AppTheme.textTertiary
                                                  : AppTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (isRequested) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary
                                                  .withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(
                                                  AppTheme.radiusSm),
                                            ),
                                            child: Text(
                                              'Talep Gönderildi',
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ] else ...[
                                          // Yetenek eşleşme rozeti
                                          if (_matchBadge(actor) != null) ...[
                                            const SizedBox(width: 6),
                                            _matchBadge(actor)!,
                                          ],
                                          // Bütçe Esnekliği Toggle
                                          _buildActorBudgetToggle(role, actor.uid),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${actor.age ?? "?"} Yaş · '
                                      '${actor.gender == Gender.male ? "Erkek" : actor.gender == Gender.female ? "Kadın" : "Diğer"} · '
                                      '${actor.city ?? "Şehir Belirtilmemiş"}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                    if (actor.skills.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 2,
                                        children: actor.skills.take(4).map((s) {
                                          final roleSkillsNorm = role.requiredSkills
                                              .map((r) => _normalizeText(r))
                                              .toSet();
                                          final isMatch = roleSkillsNorm
                                              .contains(_normalizeText(s));
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isMatch
                                                  ? Colors.red
                                                      .withValues(alpha: 0.08)
                                                  : AppTheme.accent
                                                      .withValues(alpha: 0.07),
                                              borderRadius: BorderRadius.circular(
                                                  AppTheme.radiusFull),
                                              border: isMatch
                                                  ? Border.all(
                                                      color: Colors.red
                                                          .withValues(alpha: 0.35),
                                                      width: 0.8,
                                                    )
                                                  : null,
                                            ),
                                            child: Text(
                                              s,
                                              style: GoogleFonts.inter(
                                                fontSize: 9,
                                                color: isMatch
                                                    ? Colors.red
                                                    : AppTheme.accent,
                                                fontWeight: isMatch
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Bütçe Esnekliği Toggle Metodları ─────────────────────────────────────

  /// Oyuncu bazlı bütçe esnekliği toggle'ı
      Widget _buildActorBudgetToggle(ProjectRole role, String actorUid) {
    final isEnabled =
        _budgetFlexEnabled[role.roleName]?.contains(actorUid) ?? true;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 8),
        Tooltip(
          message: 'Bütçe Değişiklik Talebi Yetkisi',
          child: Text(
            '₺',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: isEnabled ? AppTheme.success : AppTheme.textTertiary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: 36,
          height: 24,
          child: Transform.scale(
            scale: 0.7,
            child: Switch(
              value: isEnabled,
              activeColor: AppTheme.success,
              activeTrackColor: AppTheme.success.withValues(alpha: 0.3),
              inactiveThumbColor: AppTheme.textTertiary,
              inactiveTrackColor: AppTheme.border,
              onChanged: (val) {
                setState(() {
                  final set = _budgetFlexEnabled[role.roleName] ??= {};
                  if (val) {
                    set.add(actorUid);
                  } else {
                    set.remove(actorUid);
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Toplu bütçe esnekliği toggle'ı (tümünü aç/kapat)
  Widget _buildBulkBudgetToggle(
      ProjectRole role, List<ActorProfileModel> unrequestedCandidates) {
    if (unrequestedCandidates.isEmpty) return const SizedBox.shrink();

    final enabledSet = _budgetFlexEnabled[role.roleName] ?? {};
    final allEnabled = unrequestedCandidates
        .every((c) => enabledSet.contains(c.uid));

    return GestureDetector(
      onTap: () {
        setState(() {
          final set = _budgetFlexEnabled[role.roleName] ??= {};
          if (allEnabled) {
            // Hepsini kapat
            for (final c in unrequestedCandidates) {
              set.remove(c.uid);
            }
          } else {
            // Hepsini aç
            for (final c in unrequestedCandidates) {
              set.add(c.uid);
            }
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: allEnabled
              ? AppTheme.success.withValues(alpha: 0.1)
              : AppTheme.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: allEnabled
                ? AppTheme.success.withValues(alpha: 0.4)
                : AppTheme.border,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              allEnabled ? Icons.attach_money : Icons.money_off,
              size: 13,
              color: allEnabled ? AppTheme.success : AppTheme.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              allEnabled ? 'Bütçe Esnekliği Açık' : 'Bütçe Esnekliği Kapalı',
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: allEnabled ? AppTheme.success : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuitableCandidatesSection(BuildContext context) {

    if (_loadingCandidates) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_project.roles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Center(
          child: Text(
            'Bu projenin kriterlerine uygun aday bulunamadı.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ),
      );
    }

    return Column(
      children: _project.roles.asMap().entries.map((entry) {
        return _buildRoleAccordion(entry.value, entry.key);
      }).toList(),
    );
  }

  Widget _buildMetaRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Row(
        children: [
          // Durum
          Expanded(
            child: _buildMetaItem(
              'Durum',
              _project.status.displayName,
              _statusColor(_project.status),
            ),
          ),
          _buildDivider(),
          // Roller
          Expanded(
            child: _buildMetaItem(
              'Roller',
              '${_project.roles.length}',
              AppTheme.info,
            ),
          ),
          _buildDivider(),
          // Kota
          Expanded(
            child: _buildMetaItem(
              'Kota',
              '${_project.totalQuota}',
              AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      color: AppTheme.border,
    );
  }

  Widget _buildSection(String title, IconData icon, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 15, color: AppTheme.accent),
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
        const SizedBox(height: 14),
        child,
      ],
    );
  }

  Widget _buildDetailsGrid(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          _buildDetailRow('Tür', _project.projectTypeLabel),
          if (_project.location != null)
            _buildDetailRow('Lokasyon', _project.location!),
          _buildDetailRow('Oluşturan', _project.employerName),
          _buildDetailRow(
              'Oluşturma',
              '${_project.createdAt.day.toString().padLeft(2, '0')}.${_project.createdAt.month.toString().padLeft(2, '0')}.${_project.createdAt.year}'),
          if (_project.deadline != null)
            _buildDetailRow('Son Başvuru',
                '${_project.deadline!.day.toString().padLeft(2, '0')}.${_project.deadline!.month.toString().padLeft(2, '0')}.${_project.deadline!.year}'),
        ],
      ),
    );
  }

  Widget _buildHeaderImage() {
    Widget imageWidget;
    
    if (_project.primaryImageUrl != null && _project.primaryImageUrl!.isNotEmpty) {
      if (_project.primaryImageUrl!.startsWith('http')) {
        imageWidget = Image.network(
          _project.primaryImageUrl!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/ana-logo-siyah.png',
            fit: BoxFit.contain,
          ),
        );
      } else {
        imageWidget = Image.file(
          File(_project.primaryImageUrl!),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/ana-logo-siyah.png',
            fit: BoxFit.contain,
          ),
        );
      }
    } else {
      imageWidget = Image.asset(
        'assets/images/ana-logo-siyah.png',
        fit: BoxFit.contain,
      );
    }

    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: imageWidget,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: 16),
          const Spacer(),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(int index, ProjectRole role) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rol adı + Kota
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  role.roleName,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.info.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '${role.quota} kişi',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.info,
                  ),
                ),
              ),
            ],
          ),

          if (role.description != null) ...[
            const SizedBox(height: 8),
            Text(
              role.description!,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
              ),
            ),
          ],

          if (role.auditionNotes != null && role.auditionNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note_alt_outlined, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audition Notları:',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          role.auditionNotes!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Gereksinimler
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (role.ageMin != null || role.ageMax != null)
                _buildRequirementChip(
                  Icons.cake,
                  role.ageMin != null && role.ageMax != null
                      ? '${role.ageMin}-${role.ageMax} yaş'
                      : role.ageMin != null
                          ? '${role.ageMin}+ yaş'
                          : '${role.ageMax}- yaş',
                ),
              if (role.gender != null)
                _buildRequirementChip(
                  Icons.person,
                  role.gender == 'male'
                      ? 'Erkek'
                      : role.gender == 'female'
                          ? 'Kadın'
                          : 'Diğer',
                ),
              if (role.budget != null)
                _buildRequirementChip(
                  Icons.monetization_on_outlined,
                  '${role.budget!.toStringAsFixed(0)} ₺',
                ),
              if (role.requiredSkills.isNotEmpty)
                ...role.requiredSkills.map(
                  (s) => _buildRequirementChip(Icons.star, s),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(ProjectStatus status) {
    return switch (status) {
      ProjectStatus.draft => AppTheme.textTertiary,
      ProjectStatus.active => AppTheme.success,
      ProjectStatus.casting => AppTheme.info,
      ProjectStatus.completed => AppTheme.accent,
      ProjectStatus.cancelled => AppTheme.error,
    };
  }



  void _changeStatus(BuildContext context, ProjectStatus status) {
    context.read<ProjectProvider>().updateStatus(_project.id, status);
    setState(() {
      _project = _project.copyWith(status: status);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Durum "${status.displayName}" olarak güncellendi'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          'Proje Sil',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.error,
          ),
        ),
        content: Text(
          '"${_project.title}" isimli projeyi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: AppTheme.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await context.read<ProjectProvider>().deleteProject(_project.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proje başarıyla silindi.'),
            backgroundColor: AppTheme.success,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: ${context.read<ProjectProvider>().errorMessage ?? "Bilinmeyen hata"}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildImageGalleryCarousel(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _project.galleryImageUrls.length,
        itemBuilder: (context, index) {
          final url = _project.galleryImageUrls[index];
          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      InteractiveViewer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          child: Image.network(
                            url,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border, width: 0.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image_outlined, color: AppTheme.textTertiary),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProjectSampleVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _ProjectSampleVideoPlayer({required this.videoUrl});

  @override
  State<_ProjectSampleVideoPlayer> createState() => _ProjectSampleVideoPlayerState();
}

class _ProjectSampleVideoPlayerState extends State<_ProjectSampleVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInit = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.accent,
          handleColor: AppTheme.accent,
          backgroundColor: AppTheme.surfaceElevated,
          bufferedColor: AppTheme.primary.withOpacity(0.3),
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
          _error = 'Video yüklenirken hata oluştu: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (_error != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Center(
          child: Text(_error!, style: GoogleFonts.inter(color: AppTheme.error, fontSize: 13)),
        ),
      );
    }

    if (_isInit && _chewieController != null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
