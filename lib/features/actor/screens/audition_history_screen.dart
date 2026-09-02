import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/core/services/audition_service.dart';
import 'package:castelle/core/services/project_service.dart';
import 'package:castelle/core/widgets/project_details_bottom_sheet.dart';
import 'package:castelle/features/actor/screens/audition_submit_screen.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';

/// Castelle - Oyuncu Audition Geçmişi Ekranı
/// 6 tab: İşlem Bekliyor | Gönderildi | İnceleniyor | Onaylandı | Reddedildi | Revizyon
/// Gerçek zamanlı Firestore stream — admin müdahalesi gerekmez

class AuditionHistoryScreen extends StatefulWidget {
  final int? initialTabIndex;
  final String? highlightAuditionId;
  const AuditionHistoryScreen({
    super.key,
    this.initialTabIndex,
    this.highlightAuditionId,
  });

  @override
  State<AuditionHistoryScreen> createState() => _AuditionHistoryScreenState();
}

class _AuditionHistoryScreenState extends State<AuditionHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuditionService _auditionService = AuditionService();

  StreamSubscription<List<AuditionModel>>? _streamSub;
  List<AuditionModel> _auditions = [];
  bool _loading = true;
  bool _hasProcessedHighlight = false;

  // Tab sırası ve etiketleri
  static const _tabLabels = [
    'İşlem Bekliyor', // submitted
    'Gönderildi',     // submitted→reviewing geçiş öncesi
    'İnceleniyor',    // reviewing
    'Opsiyon',        // options
    'Onaylandı',      // approved
    'Reddedildi',     // rejected
    'Revizyon',       // revision
  ];

  static const _tabStatuses = [
    AuditionStatus.submitted,
    AuditionStatus.submitted,   // placeholder — Gerçekte “Gönderildi” tabı, submitted gösterir
    AuditionStatus.reviewing,
    AuditionStatus.options,
    AuditionStatus.approved,
    AuditionStatus.rejected,
    AuditionStatus.revision,
  ];

  // Tab indexine göre gerçek status
  static AuditionStatus _statusForTab(int i) {
    switch (i) {
      case 0: return AuditionStatus.submitted;
      case 1: return AuditionStatus.submitted;
      case 2: return AuditionStatus.reviewing;
      case 3: return AuditionStatus.options;
      case 4: return AuditionStatus.approved;
      case 5: return AuditionStatus.rejected;
      case 6: return AuditionStatus.revision;
      default: return AuditionStatus.submitted;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    _tabController.addListener(_handleTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startStream();
    });
  }

  void _startStream() {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    _streamSub = _auditionService.streamActorAuditions(uid).listen(
      (list) {
        if (mounted) {
          setState(() {
            _auditions = list;
            _loading = false;
          });
          // Mevcut tabın bildirimlerini okundu işaretle
          _markNotificationsAsRead(_tabController.index);

          // highlightAuditionId varsa, dialog'u aç
          if (widget.highlightAuditionId != null && !_hasProcessedHighlight) {
            _hasProcessedHighlight = true;
            final audition = _auditions.cast<AuditionModel?>().firstWhere(
              (a) => a?.id == widget.highlightAuditionId,
              orElse: () => null,
            );
            if (audition != null &&
                audition.status == AuditionStatus.options &&
                audition.optionAvailable == null) {
              Future.microtask(() {
                _showOptionResponseDialog(audition);
              });
            }
          }
        }
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    _markNotificationsAsRead(_tabController.index);
  }

  void _markNotificationsAsRead(int tabIndex) {
    if (!mounted) return;
    final notifProvider = context.read<NotificationProvider>();
    final unreadNotifs = notifProvider.notifications
        .where((n) => !n.isRead && n.type == NotificationType.auditionResult)
        .toList();

    if (unreadNotifs.isEmpty) return;
    final targetStatus = _statusForTab(tabIndex);

    for (final n in unreadNotifs) {
      final audition = _auditions
          .where((a) => a.projectId == n.projectId)
          .firstOrNull;
      if (audition?.status == targetStatus) {
        notifProvider.markAsRead(n.id);
      }
    }
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  // Statuse göre filtreleme
  List<AuditionModel> _filtered(AuditionStatus status) =>
      _auditions.where((a) => a.status == status).toList();

  // Unread badge count per tab
  int _badgeCount(int tabIndex) {
    final notifProvider = context.read<NotificationProvider>();
    final unreadNotifs = notifProvider.notifications
        .where((n) => !n.isRead && n.type == NotificationType.auditionResult)
        .toList();

    final targetStatus = _statusForTab(tabIndex);
    return unreadNotifs.where((n) {
      final audition = _auditions.where((a) => a.projectId == n.projectId).firstOrNull;
      return audition?.status == targetStatus;
    }).length;
  }

  Widget _buildTabItem(String text, int index) {
    final count = _badgeCount(index);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch notifications for badge updates
    context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          'Başvurularım',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textTertiary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle:
              GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
          tabAlignment: TabAlignment.start,
          tabs: List.generate(
            7,
            (i) => _buildTabItem(_tabLabels[i], i),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_filtered(AuditionStatus.submitted), AuditionStatus.submitted),
                _buildList(_filtered(AuditionStatus.submitted), AuditionStatus.submitted), // Gönderildi = submitted
                _buildList(_filtered(AuditionStatus.reviewing), AuditionStatus.reviewing),
                _buildList(_filtered(AuditionStatus.options), AuditionStatus.options),
                _buildList(_filtered(AuditionStatus.approved), AuditionStatus.approved),
                _buildList(_filtered(AuditionStatus.rejected), AuditionStatus.rejected),
                _buildList(_filtered(AuditionStatus.revision), AuditionStatus.revision),
              ],
            ),
    );
  }

  Widget _buildList(List<AuditionModel> list, AuditionStatus status) {
    if (list.isEmpty) {
      return _buildEmptyState(status);
    }
    return RefreshIndicator(
      onRefresh: () async {
        // Stream zaten canlı, sadece UI yenile
        setState(() {});
      },
      color: AppTheme.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, i) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildAuditionCard(list[index], index);
        },
      ),
    );
  }

  Widget _buildEmptyState(AuditionStatus status) {
    final icon = switch (status) {
      AuditionStatus.submitted => Icons.hourglass_top_rounded,
      AuditionStatus.reviewing => Icons.send_outlined,
      AuditionStatus.options => Icons.star_outline_rounded,
      AuditionStatus.approved => Icons.check_circle_outline,
      AuditionStatus.rejected => Icons.cancel_outlined,
      AuditionStatus.revision => Icons.refresh_outlined,
      _ => Icons.videocam_off,
    };

    final label = switch (status) {
      AuditionStatus.submitted => 'Bekleyen başvuru yok',
      AuditionStatus.reviewing => 'İncelemede başvuru yok',
      AuditionStatus.options => 'Opsiyonlu başvuru yok',
      AuditionStatus.approved => 'Onaylanan başvuru yok',
      AuditionStatus.rejected => 'Reddedilen başvuru yok',
      AuditionStatus.revision => 'Revizyon bekleyen yok',
      _ => 'Başvuru yok',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppTheme.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buraya yeni başvurular geldiğinde otomatik görünecek',
            textAlign: TextAlign.center,
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
    final isRevision = audition.status == AuditionStatus.revision;

    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isRevision
              ? AppTheme.accent.withValues(alpha: 0.4)
              : AppTheme.border,
          width: isRevision ? 1.2 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst: Proje + Durum
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      audition.status == AuditionStatus.options || audition.projectTitle.toUpperCase().startsWith('OPSİYON')
                          ? (audition.projectTitle.toUpperCase().startsWith('OPSİYON')
                              ? audition.projectTitle.toUpperCase()
                              : 'OPSİYON ${audition.projectTitle.toUpperCase()}')
                          : audition.projectTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            audition.roleName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.info,
                            ),
                          ),
                        ),
                        if (audition.requestedBudget != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              '💰 ${audition.requestedBudget!.toStringAsFixed(0)} ₺',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.success,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildStatusChip(audition),
            ],
          ),

          const SizedBox(height: 14),

          // Video bilgileri
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildMiniInfo(Icons.timer, audition.formattedDuration),
              _buildMiniInfo(Icons.sd_storage, audition.formattedSize),
              if (audition.compressionRatio > 0)
                _buildMiniInfo(
                  Icons.compress,
                  '${(audition.compressionRatio * 100).toStringAsFixed(0)}% sıkıştırma',
                ),
            ],
          ),

          // Geri bildirim
          if (audition.reviewerNote != null &&
              audition.reviewerNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _statusColor(audition.status).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(
                  color: _statusColor(audition.status).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.feedback_outlined,
                          size: 14, color: _statusColor(audition.status)),
                      const SizedBox(width: 6),
                      Text(
                        'Geri Bildirim${audition.reviewerName != null ? " — ${audition.reviewerName}" : ""}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(audition.status),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    audition.reviewerNote!,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Yeniden Audition Gönder (sadece Revizyon)
          if (isRevision) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _handleResubmit(audition),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  'Yeniden Audition Gönder',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],

          if (audition.status == AuditionStatus.options) ...[
            const SizedBox(height: 14),
            if (audition.optionAvailable == null) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showOptionResponseDialog(audition),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  icon: const Icon(Icons.star_rounded, size: 16),
                  label: Text(
                    'Opsiyon Talebini Yanıtla',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else ...[
              _buildOptionResponseDetails(audition),
            ],
          ],

          // İndirme Butonu
          const SizedBox(height: 10),
          _buildDownloadButton(audition),

          // Tarih
          const SizedBox(height: 10),
          Text(
            _formatDate(audition.createdAt),
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textTertiary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );

    if (audition.status == AuditionStatus.approved) {
      cardContent = GestureDetector(
        onTap: () => _handleApprovedTap(audition),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: cardContent,
        ),
      );
    }

    return cardContent.animate().fadeIn(delay: (40 + index * 30).ms);
  }

  // ─── İndirme Butonu ────────────────────────────────────────────────────────

  // Hangi audition indiriliyor? (indirme sürerken UI)
  final Map<String, double> _downloadProgress = {};

  Widget _buildDownloadButton(AuditionModel audition) {
    final isDownloading = _downloadProgress.containsKey(audition.id);
    final progress = _downloadProgress[audition.id] ?? 0.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: isDownloading
          ? _buildProgressBar(progress, audition.id)
          : OutlinedButton.icon(
              key: ValueKey('dl_${audition.id}'),
              onPressed: () => _downloadVideo(audition),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(
                'Videoyu Kaydet',
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: BorderSide(
                    color: AppTheme.accent.withValues(alpha: 0.4)),
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm)),
              ),
            ),
    );
  }

  Widget _buildProgressBar(double progress, String id) {
    return Container(
      key: ValueKey('prog_$id'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border:
            Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.download_rounded,
              size: 16, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İndiriliyor... ${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                        AppTheme.accent.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVideo(AuditionModel audition) async {
    final messenger = ScaffoldMessenger.of(context);

    // ── 1. İzin ──────────────────────────────────────────────────
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        // Android 13+ scoped storage — storage izni gerekmez, doğrudan devam
        final photos = await Permission.photos.status;
        if (!photos.isGranted && !photos.isLimited) {
          // Yeni API: Photos/videos izni de yoksa bildir
          debugPrint('⚠️ [Download] İzin reddedildi, devam ediliyor (scoped).');
        }
      }
    }

    // ── 2. Kayıt Dizini ──────────────────────────────────────────
    Directory? saveDir;
    if (Platform.isAndroid) {
      // Android — Downloads/Castelle
      saveDir = Directory('/storage/emulated/0/Download/Castelle');
    } else if (Platform.isIOS) {
      // iOS — Documents/Castelle
      final docs = await getApplicationDocumentsDirectory();
      saveDir = Directory('${docs.path}/Castelle');
    } else {
      final docs = await getDownloadsDirectory();
      saveDir = docs ?? await getApplicationDocumentsDirectory();
    }

    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    // ── 3. Dosya Adı ─────────────────────────────────────────────
    final safeProject = audition.projectTitle.replaceAll(RegExp(r'[^\w]'), '_');
    final safeRole = audition.roleName.replaceAll(RegExp(r'[^\w]'), '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'castelle_${safeProject}_${safeRole}_$timestamp.mp4';
    final savePath = '${saveDir.path}/$fileName';

    // İndirme başladı — UI güncelle
    setState(() {
      _downloadProgress[audition.id] = 0.0;
    });

    // ── 4. Dio İle İndir ─────────────────────────────────────────
    try {
      final dio = Dio();
      await dio.download(
        audition.videoUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          if (mounted) {
            setState(() {
              _downloadProgress[audition.id] = received / total;
            });
          }
        },
      );

      // İndirme tamamlandı
      if (mounted) {
        setState(() => _downloadProgress.remove(audition.id));
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Video kaydedildi! ✅',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      Text(
                        'Konum: Downloads/Castelle/$fileName',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on DioException catch (e) {
      debugPrint('❌ [Download] Dio hatası: $e');
      if (mounted) {
        setState(() => _downloadProgress.remove(audition.id));
        messenger.showSnackBar(
          SnackBar(
            content: Text('İndirme başarısız: ${e.message}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ [Download] Hata: $e');
      if (mounted) {
        setState(() => _downloadProgress.remove(audition.id));
        messenger.showSnackBar(
          SnackBar(
            content: Text('İndirme hatası: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleApprovedTap(AuditionModel audition) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
    );

    try {
      final project = await ProjectService().getProject(audition.projectId);
      if (!mounted) return;
      Navigator.pop(context); // Close loading indicator

      if (project == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proje detayları bulunamadı.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }

      final notifProvider = context.read<NotificationProvider>();
      final invite = notifProvider.notifications
          .where((n) => n.type == NotificationType.castingInvite && n.projectId == project.id)
          .firstOrNull;

      if (mounted) {
        ProjectDetailsBottomSheet.show(context, project, invite: invite);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleResubmit(AuditionModel audition) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
    );

    try {
      final project =
          await ProjectService().getProject(audition.projectId);
      if (!mounted) return;
      Navigator.pop(context);

      if (project == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proje bulunamadı.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
        return;
      }

      final role = project.roles.isNotEmpty
          ? project.roles.firstWhere(
              (r) => r.roleName == audition.roleName,
              orElse: () => project.roles.first,
            )
          : ProjectRole(roleName: audition.roleName);

      bool isBudgetFlexible = false;
      try {
        final currentUserUid = audition.actorId;
        final notifSnap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('projectId', isEqualTo: audition.projectId)
            .where('recipientId', isEqualTo: currentUserUid)
            .where('type', isEqualTo: 'casting_invite')
            .get();
        if (notifSnap.docs.isNotEmpty) {
          for (final doc in notifSnap.docs) {
            final data = doc.data();
            final roleData = data['data'] as Map<String, dynamic>?;
            if (roleData?['roleName'] == audition.roleName) {
              isBudgetFlexible = roleData?['budgetFlexible'] as bool? ?? false;
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [AuditionHistory] Error fetching budgetFlexible: $e');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AuditionSubmitScreen(
            project: project,
            role: role,
            budgetFlexible: isBudgetFlexible,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Widget _buildStatusChip(AuditionModel audition) {
    String label = audition.status.displayName;
    Color color = _statusColor(audition.status);

    if (audition.status == AuditionStatus.options) {
      if (audition.optionAvailable == null) {
        label = '🟡 Cevap Bekleniyor';
        color = AppTheme.warning;
      } else if (audition.optionAvailable == true) {
        label = '🟢 Opsiyonda';
        color = AppTheme.success;
      } else {
        label = '🔴 Müsait Değil';
        color = AppTheme.error;
      }
    } else if (audition.status == AuditionStatus.approved) {
      label = '🔵 Kesinleşti';
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  Color _statusColor(AuditionStatus status) {
    return switch (status) {
      AuditionStatus.uploading => AppTheme.textTertiary,
      AuditionStatus.submitted => AppTheme.warning,
      AuditionStatus.reviewing => AppTheme.info,
      AuditionStatus.options => AppTheme.accent,
      AuditionStatus.approved => AppTheme.success,
      AuditionStatus.rejected => AppTheme.error,
      AuditionStatus.revision => AppTheme.accent,
    };
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
        ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showOptionResponseDialog(AuditionModel audition) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return OptionResponseDialog(
          audition: audition,
          onSubmit: (available, explanation, answers) async {
            final success = await context.read<AuditionProvider>().submitOptionResponse(
              auditionId: audition.id,
              available: available,
              explanation: explanation,
              answers: answers,
            );

            if (mounted && success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opsiyon yanıtınız başarıyla iletildi.'),
                  backgroundColor: AppTheme.success,
                ),
              );
              Navigator.pop(dialogContext);
            }
          },
        );
      },
    );
  }

  Widget _buildOptionResponseDetails(AuditionModel audition) {
    final startStr = audition.optionStartDate != null ? _formatDateOnly(audition.optionStartDate!) : '';
    final endStr = audition.optionEndDate != null ? _formatDateOnly(audition.optionEndDate!) : '';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'Opsiyon Yanıtı İletildi',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Çekim Tarihleri: $startStr - $endStr',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Müsaitlik: ${audition.optionAvailable == true ? "Evet (Müsaitim)" : "Hayır (Müsait değilim)"}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: audition.optionAvailable == true ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (audition.optionAvailable == false && audition.optionExplanation != null) ...[
            const SizedBox(height: 4),
            Text(
              'Açıklama: ${audition.optionExplanation}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
          if (audition.optionQuestions != null && audition.optionQuestions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Sorular ve Cevaplarınız:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            for (final q in audition.optionQuestions!) ...[
              Text(
                'S: $q',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
              Text(
                'C: ${audition.optionAnswers?[q] ?? "Yanıtlanmadı"}',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDateOnly(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class OptionResponseDialog extends StatefulWidget {
  final AuditionModel audition;
  final Function(bool available, String? explanation, Map<String, String> answers) onSubmit;

  const OptionResponseDialog({
    super.key,
    required this.audition,
    required this.onSubmit,
  });

  @override
  State<OptionResponseDialog> createState() => _OptionResponseDialogState();
}

class _OptionResponseDialogState extends State<OptionResponseDialog> {
  bool? _isAvailable;
  final TextEditingController _explanationController = TextEditingController(
    text: 'Müsait olmama nedeninizi ve müsait tarihlerinizi yazın',
  );
  final FocusNode _explanationFocusNode = FocusNode();
  final Map<String, TextEditingController> _answerControllers = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _explanationFocusNode.addListener(() {
      if (_explanationFocusNode.hasFocus) {
        if (_explanationController.text == 'Müsait olmama nedeninizi ve müsait tarihlerinizi yazın') {
          _explanationController.clear();
        }
      }
    });

    if (widget.audition.optionQuestions != null) {
      for (final q in widget.audition.optionQuestions!) {
        _answerControllers[q] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _explanationController.dispose();
    _explanationFocusNode.dispose();
    for (final ctrl in _answerControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final startStr = widget.audition.optionStartDate != null ? _formatDate(widget.audition.optionStartDate!) : '';
    final endStr = widget.audition.optionEndDate != null ? _formatDate(widget.audition.optionEndDate!) : '';

    return Dialog(
      backgroundColor: AppTheme.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.audition.projectTitle.toUpperCase().startsWith('OPSİYON')
                  ? widget.audition.projectTitle.toUpperCase()
                  : 'OPSİYON ${widget.audition.projectTitle.toUpperCase()}',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aşağıdaki tarih ve soruları yanıtlayarak geri dönüş yapın.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: AppTheme.accent, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Öngörülen Çekim Tarihleri',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$startStr - $endStr',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Bu tarihlerde müsait misiniz?',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isAvailable = true;
                              });
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isAvailable == true
                                    ? AppTheme.success.withValues(alpha: 0.1)
                                    : AppTheme.surfaceLight,
                                border: Border.all(
                                  color: _isAvailable == true ? AppTheme.success : AppTheme.border,
                                  width: _isAvailable == true ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isAvailable == true ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: _isAvailable == true ? AppTheme.success : AppTheme.textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Evet',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _isAvailable == true ? AppTheme.success : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isAvailable = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isAvailable == false
                                    ? AppTheme.error.withValues(alpha: 0.1)
                                    : AppTheme.surfaceLight,
                                border: Border.all(
                                  color: _isAvailable == false ? AppTheme.error : AppTheme.border,
                                  width: _isAvailable == false ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isAvailable == false ? Icons.cancel : Icons.radio_button_unchecked,
                                    color: _isAvailable == false ? AppTheme.error : AppTheme.textSecondary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Hayır',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _isAvailable == false ? AppTheme.error : AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isAvailable == false) ...[
                      Text(
                        'Müsait Olmama Nedeni ve Müsait Tarihleriniz',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _explanationController,
                        focusNode: _explanationFocusNode,
                        maxLines: 3,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.all(12),
                          filled: true,
                          fillColor: AppTheme.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            borderSide: BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                          ),
                        ),
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (widget.audition.optionQuestions != null && widget.audition.optionQuestions!.isNotEmpty) ...[
                      const Divider(height: 24),
                      Text(
                        'Soruları Cevaplayın',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final q in widget.audition.optionQuestions!) ...[
                        Text(
                          q,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _answerControllers[q],
                          decoration: InputDecoration(
                            hintText: 'Cevabınızı yazın...',
                            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: AppTheme.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              borderSide: BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              borderSide: const BorderSide(color: AppTheme.accent, width: 1.5),
                            ),
                          ),
                          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'İptal',
                    style: GoogleFonts.outfit(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitting || _isAvailable == null
                      ? null
                      : () async {
                          final answers = <String, String>{};
                          _answerControllers.forEach((q, ctrl) {
                            answers[q] = ctrl.text.trim();
                          });
                          
                          setState(() {
                            _submitting = true;
                          });

                          String? exp = _isAvailable == false ? _explanationController.text.trim() : null;
                          if (exp == 'Müsait olmama nedeninizi ve müsait tarihlerinizi yazın') {
                            exp = '';
                          }

                          try {
                            await widget.onSubmit(_isAvailable!, exp, answers);
                          } finally {
                            if (mounted) {
                              setState(() {
                                _submitting = false;
                              });
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Yanıtı Gönder',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
