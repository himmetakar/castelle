import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';
import 'package:castelle/features/director/screens/audition_review_screen.dart';
import 'package:castelle/core/services/pdf_service.dart';

/// Castelle - Audition İnceleme Listesi
/// Yönetmen ve Admin için gelen audition'ları filtrele ve incele

class AuditionListScreen extends StatefulWidget {
  final bool isAdmin;
  final bool isModerator;

  const AuditionListScreen({
    super.key,
    this.isAdmin = false,
    this.isModerator = false,
  });

  @override
  State<AuditionListScreen> createState() => _AuditionListScreenState();
}

class _AuditionListScreenState extends State<AuditionListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isSelectionMode = false;
  final Set<String> _selectedAuditionIds = {};
  bool _isDownloading = false;
  String _downloadProgressText = '';
  double _downloadPercentage = 0.0;

  // Tab sırası: İşlem Bekliyor, İnceleniyor, Opsiyon, Onaylandi, Reddedildi, Revizyon
  final _tabs = const [
    AuditionStatus.submitted,   // İşlem Bekliyor — gelen audition talepleri
    AuditionStatus.reviewing,   // İnceleniyor — işleme alınan
    AuditionStatus.options,     // Opsiyon — opsiyon talep edilen
    AuditionStatus.approved,
    AuditionStatus.rejected,
    AuditionStatus.revision,
  ];

  // Admin/Moderatör panelinde görünecek özel etiketler
  static const _tabLabels = [
    'İşlem Bekliyor',
    'İnceleniyor',
    'Opsiyon',
    'Onaylandı',
    'Reddedildi',
    'Revizyon',
  ];

  // Moderatör'ün atandığı proje ID'leri
  List<String> _moderatorProjectIds = [];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Moderatör ise önce proje ID'lerini çek
      if (widget.isModerator) {
        await _loadModeratorProjects();
      }
      _loadAuditions(AuditionStatus.submitted);
    });
  }

  /// Moderatörün atandığı projeleri Firestore'dan çek
  Future<void> _loadModeratorProjects() async {
    final authProvider = context.read<AuthProvider>();
    final uid = authProvider.user?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('coordinatorId', isEqualTo: uid)
          .get();
      setState(() {
        _moderatorProjectIds = snap.docs.map((d) => d.id).toList();
      });
      debugPrint('🔐 [Moderator] Atandığı ${_moderatorProjectIds.length} proje bulundu.');
    } catch (e) {
      debugPrint('⚠️ [Moderator] Proje yükleme hatası: $e');
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _loadAuditions(_tabs[_tabController.index]);
  }

  void _loadAuditions(AuditionStatus status) {
    if (widget.isModerator && _moderatorProjectIds.isNotEmpty) {
      // Moderatör: sadece kendi projelerindeki auditionları getir
      context.read<AuditionProvider>().loadAllAuditions(
        status: status,
        projectIds: _moderatorProjectIds,
      );
    } else if (widget.isModerator && _moderatorProjectIds.isEmpty) {
      // Moderatör ama henüz proje atanmamış — boş liste
      context.read<AuditionProvider>().clearAuditions();
    } else {
      context.read<AuditionProvider>().loadAllAuditions(status: status);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditionProvider>();
    final auditions = provider.auditions;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(_isSelectionMode 
            ? '${_selectedAuditionIds.length} Seçildi' 
            : (widget.isAdmin ? 'Tüm Audition\'lar' : 'İnceleme Paneli')),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedAuditionIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (widget.isAdmin && auditions.isNotEmpty) ...[
            if (_isSelectionMode) ...[
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: 'Tümünü Seç / Kaldır',
                onPressed: () {
                  setState(() {
                    if (_selectedAuditionIds.length == auditions.length) {
                      _selectedAuditionIds.clear();
                    } else {
                      _selectedAuditionIds.addAll(auditions.map((a) => a.id));
                    }
                  });
                },
              ),
            ] else ...[
              IconButton(
                icon: const Icon(Icons.playlist_add_check),
                tooltip: 'Çoklu Seçim',
                onPressed: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedAuditionIds.clear();
                  });
                },
              ),
            ],
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textTertiary,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          tabAlignment: TabAlignment.start,
          tabs: _tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            return Tab(text: _tabLabels[idx]);
          }).toList(),
        ),
      ),
      body: Stack(
        children: [
          provider.isLoading && auditions.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                )
              : auditions.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        _loadAuditions(_tabs[_tabController.index]);
                      },
                      color: AppTheme.accent,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: auditions.length,
                        separatorBuilder: (_, i) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          return _buildAuditionCard(
                              auditions[index], index);
                        },
                      ),
                    ),
          if (_isDownloading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  color: AppTheme.surfaceCard,
                  margin: const EdgeInsets.all(32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppTheme.accent),
                        const SizedBox(height: 20),
                        Text(
                          'Başvurular İndiriliyor...',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _downloadPercentage,
                          backgroundColor: AppTheme.border,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _downloadProgressText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (_isSelectionMode && _selectedAuditionIds.isNotEmpty)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.5), width: 0.5)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedAuditionIds.length} audition seçildi',
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        final list = auditions.where((a) => _selectedAuditionIds.contains(a.id)).toList();
                        _startDownloadFlow(list);
                      },
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      label: const Text('Klasör Seç & İndir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    final status = _tabs[_tabController.index];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _statusIcon(status),
            size: 56,
            color: AppTheme.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            _emptyMessage(status),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Bu kategoride henüz audition bulunmuyor',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditionCard(AuditionModel audition, int index) {
    final isSelected = _selectedAuditionIds.contains(audition.id);

    return GestureDetector(
      onTap: () async {
        if (_isSelectionMode) {
          setState(() {
            if (isSelected) {
              _selectedAuditionIds.remove(audition.id);
            } else {
              _selectedAuditionIds.add(audition.id);
            }
          });
          return;
        }
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AuditionReviewScreen(audition: audition),
          ),
        );
        if (result == true) {
          _loadAuditions(_tabs[_tabController.index]);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border, 
            width: isSelected ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            if (_isSelectionMode) ...[
              Checkbox(
                value: isSelected,
                activeColor: AppTheme.accent,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedAuditionIds.add(audition.id);
                    } else {
                      _selectedAuditionIds.remove(audition.id);
                    }
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getInitials(audition.actorName),
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Bilgi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    audition.actorName,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildMiniChip(
                          audition.projectTitle, AppTheme.info),
                      _buildMiniChip(
                          audition.roleName, AppTheme.accent),
                      if (audition.requestedBudget != null)
                        _buildMiniChip(
                          audition.isBudgetChanged
                              ? '⚠️ Bütçe Değişti: ${audition.requestedBudget!.toStringAsFixed(0)} ₺'
                              : '💰 Bütçe: ${audition.requestedBudget!.toStringAsFixed(0)} ₺',
                          audition.isBudgetChanged ? AppTheme.warning : AppTheme.success,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.timer,
                          size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        audition.formattedDuration,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.sd_storage,
                          size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(
                        audition.formattedSize,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _timeAgo(audition.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            Icon(
              _isSelectionMode 
                  ? (isSelected ? Icons.check_circle : Icons.radio_button_unchecked)
                  : Icons.play_circle_outline,
              size: 28, 
              color: isSelected ? AppTheme.accent : AppTheme.textTertiary,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (30 + index * 25).ms);
  }

  Widget _buildMiniChip(String text, Color color) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  IconData _statusIcon(AuditionStatus status) {
    return switch (status) {
      AuditionStatus.submitted => Icons.inbox,
      AuditionStatus.reviewing => Icons.visibility,
      AuditionStatus.options => Icons.help_outline,
      AuditionStatus.approved => Icons.check_circle,
      AuditionStatus.rejected => Icons.cancel,
      AuditionStatus.revision => Icons.replay,
      AuditionStatus.uploading => Icons.cloud_upload,
    };
  }

  String _emptyMessage(AuditionStatus status) {
    return switch (status) {
      AuditionStatus.submitted => 'Bekleyen audition yok',
      AuditionStatus.reviewing => 'İncelenen audition yok',
      AuditionStatus.options => 'Opsiyonlanan audition yok',
      AuditionStatus.approved => 'Onaylanan audition yok',
      AuditionStatus.rejected => 'Reddedilen audition yok',
      AuditionStatus.revision => 'Revizyon bekleyen audition yok',
      AuditionStatus.uploading => 'Yüklenen audition yok',
    };
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
  }

  Future<void> _startDownloadFlow(List<AuditionModel> auditionsToDownload) async {
    if (auditionsToDownload.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context); // await'ten önce al

    // 1. Hedef Klasör Seçimi
    String? selectedDir;
    try {
      selectedDir = await FilePicker.platform.getDirectoryPath();
    } catch (e) {
      debugPrint('Folder picker error: $e');
    }

    if (selectedDir == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('İndirme iptal edildi. Klasör seçilmedi.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    debugPrint('📁 [Selected Directory] Path: $selectedDir');
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Seçilen dizin: $selectedDir'),
          duration: const Duration(seconds: 4),
        ),
      );
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

    setState(() {
      _isDownloading = true;
      _downloadProgressText = 'İndirme işlemi hazırlanıyor...';
      _downloadPercentage = 0.0;
    });

    int downloadedCount = 0;
    int errorCount = 0;

    for (int i = 0; i < auditionsToDownload.length; i++) {
      final audition = auditionsToDownload[i];
      final currentOverallProgress = i / auditionsToDownload.length;
      final stepWeight = 1.0 / auditionsToDownload.length;

      try {
        setState(() {
          _downloadProgressText = '${audition.actorName} - Profil verileri alınıyor (${i + 1}/${auditionsToDownload.length})...';
          _downloadPercentage = currentOverallProgress;
        });

        // 1. Oyuncu Profil Belgesini Firestore'dan Çek
        final doc = await FirebaseFirestore.instance.collection('users').doc(audition.actorId).get();
        if (!doc.exists) {
          throw Exception('Oyuncu profil verisi bulunamadı.');
        }

        final actorProfile = ActorProfileModel.fromMap(doc.data()!, doc.id);

        // 2. Klasör Oluştur: (Proje Adı) - (Oyuncu Adı)
        final rawFolderName = "${audition.projectTitle} - ${audition.actorName}";
        final cleanFolderName = rawFolderName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
        final actorFolderPath = "$selectedDir/$cleanFolderName";

        final actorDir = Directory(actorFolderPath);
        if (!await actorDir.exists()) {
          await actorDir.create(recursive: true);
        }

        // 3. PDF Profil Kartı Oluştur ve Kaydet
        setState(() {
          _downloadProgressText = '${audition.actorName} - Profil PDF oluşturuluyor...';
          _downloadPercentage = currentOverallProgress + (stepWeight * 0.2);
        });

        final pdfPath = "$actorFolderPath/${audition.actorName} - Profil.pdf";
        await PdfService.generateProfilePdf(actorProfile, pdfPath);

        // 4. Audition Videosunu İndir
        if (audition.videoUrl.isNotEmpty) {
          setState(() {
            _downloadProgressText = '${audition.actorName} - Video indiriliyor...';
            _downloadPercentage = currentOverallProgress + (stepWeight * 0.3);
          });

          // Dosya uzantısını belirle (varsayılan mp4)
          String ext = 'mp4';
          final lowerUrl = audition.videoUrl.toLowerCase();
          if (lowerUrl.contains('.mov') || lowerUrl.contains('.mov?')) {
            ext = 'mov';
          } else if (lowerUrl.contains('.m4v') || lowerUrl.contains('.m4v?')) {
            ext = 'm4v';
          }

          final videoPath = "$actorFolderPath/${audition.actorName} - Audition.$ext";
          final isLocal = !audition.videoUrl.startsWith('http://') && !audition.videoUrl.startsWith('https://');

          if (isLocal) {
            String cleanLocalPath = audition.videoUrl;
            if (cleanLocalPath.startsWith('file://')) {
              cleanLocalPath = Uri.parse(cleanLocalPath).toFilePath();
            }
            final sourceFile = File(cleanLocalPath);
            if (await sourceFile.exists()) {
              await sourceFile.copy(videoPath);
              setState(() {
                _downloadPercentage = currentOverallProgress + stepWeight;
              });
            } else {
              throw Exception('Yerel video dosyasi bulunamadi: $cleanLocalPath');
            }
          } else {
            await Dio().download(
              audition.videoUrl,
              videoPath,
              onReceiveProgress: (received, total) {
                if (total != -1) {
                  final percent = received / total;
                  setState(() {
                    _downloadProgressText = '${audition.actorName} - Video indiriliyor: %${(percent * 100).toStringAsFixed(0)}';
                    _downloadPercentage = currentOverallProgress + (stepWeight * 0.3) + (percent * stepWeight * 0.7);
                  });
                }
              },
            );
          }
        }

        // 5. Oyuncunun Fotoğraflarını İndir
        final photoUrls = <String>[];
        if (actorProfile.profilePhotoUrl != null && actorProfile.profilePhotoUrl!.isNotEmpty) {
          photoUrls.add(actorProfile.profilePhotoUrl!);
        }
        photoUrls.addAll(actorProfile.galleryPhotoUrls.where((url) => url.isNotEmpty));

        if (photoUrls.isNotEmpty) {
          setState(() {
            _downloadProgressText = '${audition.actorName} - Fotograflar indiriliyor...';
          });

          final photosFolder = Directory("$actorFolderPath/Fotograflar");
          if (!await photosFolder.exists()) {
            await photosFolder.create(recursive: true);
          }

          for (int pIdx = 0; pIdx < photoUrls.length; pIdx++) {
            final url = photoUrls[pIdx];
            final isProfile = pIdx == 0 && (actorProfile.profilePhotoUrl != null && actorProfile.profilePhotoUrl!.isNotEmpty);

            String ext = 'jpg';
            final lowerUrl = url.toLowerCase();
            if (lowerUrl.contains('.png') || lowerUrl.contains('.png?')) {
              ext = 'png';
            } else if (lowerUrl.contains('.jpeg') || lowerUrl.contains('.jpeg?')) {
              ext = 'jpeg';
            }

            final photoPath = isProfile
                ? "${photosFolder.path}/Profil Resmi.$ext"
                : "${photosFolder.path}/Fotograf_${isProfile ? pIdx : pIdx + 1}.$ext";

            try {
              final isLocalPhoto = !url.startsWith('http://') && !url.startsWith('https://');
              if (isLocalPhoto) {
                String cleanLocalPath = url;
                if (cleanLocalPath.startsWith('file://')) {
                  cleanLocalPath = Uri.parse(cleanLocalPath).toFilePath();
                }
                final file = File(cleanLocalPath);
                if (await file.exists()) {
                  await file.copy(photoPath);
                }
              } else {
                await Dio().download(url, photoPath);
              }
            } catch (photoErr) {
              debugPrint('Photo download error: $photoErr');
            }
          }
        }

        downloadedCount++;
      } catch (e, s) {
        debugPrint('⚠️ [Download Error] ${audition.actorName}: $e\n$s');
        errorCount++;
      }
    }

    setState(() {
      _isDownloading = false;
      _isSelectionMode = false;
      _selectedAuditionIds.clear();
    });

    if (mounted) {
      if (errorCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$downloadedCount başvuru başarıyla seçtiğiniz klasöre kaydedildi! 🎉'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$downloadedCount başvuru kaydedildi, $errorCount başvuru indirilirken hata oluştu.'),
            backgroundColor: downloadedCount > 0 ? AppTheme.warning : AppTheme.error,
          ),
        );
      }
    }
  }
}
