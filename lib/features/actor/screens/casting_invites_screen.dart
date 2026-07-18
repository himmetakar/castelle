import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/features/actor/providers/actor_profile_provider.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';
import 'package:castelle/core/services/project_service.dart';
import 'package:castelle/features/actor/widgets/nda_agreement_dialog.dart';
import 'package:castelle/core/widgets/project_details_bottom_sheet.dart';

/// Castelle - Casting Çağrıları / Talepleri Ekranı
/// Oyuncuya özel 5 tablı Casting ekranı
class CastingInvitesScreen extends StatefulWidget {
  const CastingInvitesScreen({super.key});

  @override
  State<CastingInvitesScreen> createState() => _CastingInvitesScreenState();
}

class _CastingInvitesScreenState extends State<CastingInvitesScreen> {
  final ProjectService _projectService = ProjectService();
  bool _loadingProject = false;

  List<ProjectModel> _allProjects = [];
  bool _loadingAllProjects = false;

  @override
  void initState() {
    super.initState();
    _loadAllProjects();
  }

  Future<void> _loadAllProjects() async {
    setState(() => _loadingAllProjects = true);
    try {
      final projects = await _projectService.getActiveProjects();
      setState(() {
        _allProjects = projects;
        _loadingAllProjects = false;
      });
    } catch (e) {
      setState(() {
        _allProjects = [];
        _loadingAllProjects = false;
      });
    }
  }

  String getFirstSentences(String? text, {int limit = 2}) {
    if (text == null || text.trim().isEmpty) return 'Açıklama bulunmuyor.';
    final regex = RegExp(r'[^.!?]+[.!?]');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return text.length > 80 ? '${text.substring(0, 80)}...' : text;
    }
    return matches.take(limit).map((m) => m.group(0)?.trim()).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final auditionProvider = context.watch<AuditionProvider>();
    final auditions = auditionProvider.auditions;
    final approvedProjectIds = auditions
        .where((a) => a.status == AuditionStatus.approved)
        .map((a) => a.projectId)
        .toSet();

    final notificationProvider = context.watch<NotificationProvider>();
    final invites = notificationProvider.notifications
        .where((n) => n.type == NotificationType.castingInvite)
        .where((n) {
          final projectIndex = _allProjects.indexWhere((p) => p.id == n.projectId);
          if (projectIndex == -1) return false;
          
          final project = _allProjects[projectIndex];
          if (approvedProjectIds.contains(project.id)) return false;
          if (project.deadline != null && DateTime.now().isAfter(project.deadline!)) return false;
          
          return true;
        })
        .toList();
    final unreadInvites = invites.where((n) => !n.isRead).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: Text(
            'Casting Talepleri',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          ),
          bottom: TabBar(
            indicatorColor: AppTheme.accent,
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.textTertiary,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
            tabs: [
              _buildTabHeader('Sizin İçin', unreadInvites),
              const Tab(text: 'Tüm Projeler'),
            ],
          ),
        ),
        body: _loadingProject
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : TabBarView(
                children: [
                  _buildCastingInvitesList(invites),
                  _buildAllProjectsList(),
                ],
              ),
      ),
    );
  }

  Widget _buildTabHeader(String title, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllProjectsList() {
    if (_loadingAllProjects && _allProjects.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
    }
    if (_allProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_creation_outlined, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Aktif Proje Bulunmuyor',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAllProjects,
      color: AppTheme.accent,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _allProjects.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final project = _allProjects[index];
          return _buildProjectPreviewCard(project, index);
        },
      ),
    );
  }

  Widget _buildProjectImage(ProjectModel project, {double size = 80.0}) {
    final primaryImageUrl = project.primaryImageUrl;

    if (primaryImageUrl == null || primaryImageUrl.isEmpty) {
      // Castelle logosu göster
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.border.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/ana-logo-siyah.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.movie_creation_outlined,
              size: size * 0.4,
              color: AppTheme.textTertiary,
            ),
          ),
        ),
      );
    }

    Widget imageWidget;
    if (primaryImageUrl.startsWith('http')) {
      imageWidget = Image.network(
        primaryImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/ana-logo-siyah.png',
          fit: BoxFit.contain,
        ),
      );
    } else {
      imageWidget = Image.file(
        File(primaryImageUrl),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/ana-logo-siyah.png',
          fit: BoxFit.contain,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11.0),
        child: imageWidget,
      ),
    );
  }

  Widget _buildProjectPreviewCard(ProjectModel project, int index) {
    final typeLabel = project.projectTypeLabel;
    final cleanDesc = getFirstSentences(project.description, limit: 2);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleProjectTap(project),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProjectImage(project, size: 80.0),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Başlık + Önizleme badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                project.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_outline, size: 9, color: AppTheme.textTertiary),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Önizleme',
                                    style: GoogleFonts.inter(
                                      fontSize: 8,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Tur + Lokasyon
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                typeLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (project.location != null) ...[
                              Text(
                                '  •  ',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  project.location!,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cleanDesc,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.03);
  }


  Widget _buildCastingInvitesList(List<NotificationModel> invites) {
    if (invites.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: invites.length,
      itemBuilder: (context, index) {
        return _buildInviteCard(invites[index], index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 48,
              color: AppTheme.textTertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Casting Çağrısı Yok',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Size uygun yeni bir proje için audition talebi geldiğinde burada listelenecektir.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildInviteImage(NotificationModel invite, {double size = 80}) {
    if (invite.projectId == null || invite.projectId!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.campaign, size: size * 0.5, color: AppTheme.accent),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('projects')
          .doc(invite.projectId)
          .get(),
      builder: (context, snapshot) {
        String? primaryImageUrl;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null) {
            primaryImageUrl = data['primaryImageUrl'] as String?;
          }
        }

        Widget imageWidget;
        if (primaryImageUrl != null && primaryImageUrl.isNotEmpty) {
          if (primaryImageUrl.startsWith('http')) {
            imageWidget = Image.network(
              primaryImageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/ana-logo-siyah.png',
                fit: BoxFit.contain,
              ),
            );
          } else {
            imageWidget = Image.file(
              File(primaryImageUrl),
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
          width: size,
          height: size,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: imageWidget,
          ),
        );
      },
    );
  }

  Widget _buildInviteCard(NotificationModel invite, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: invite.isRead
              ? AppTheme.border.withValues(alpha: 0.3)
              : AppTheme.accent.withValues(alpha: 0.4),
          width: invite.isRead ? 0.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleInviteTap(invite),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInviteImage(invite, size: 80),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AUDITION TALEBİ',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              _formatTime(invite.createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          invite.title,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invite.body,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Detayları İncele',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.accent,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppTheme.accent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.05);
  }

  Future<void> _handleInviteTap(NotificationModel invite) async {
    if (!invite.isRead) {
      context.read<NotificationProvider>().markAsRead(invite.id);
    }

    if (invite.projectId == null) return;

    // Gizlilik Taahhütnamesi (NDA) Kontrolü
    final profileProvider = context.read<ActorProfileProvider>();
    final acceptedNdas = profileProvider.profile?.acceptedNdas ?? [];
    if (!acceptedNdas.contains(invite.projectId!)) {
      final accepted = await NdaAgreementDialog.show(
        context,
        projectId: invite.projectId!,
        projectTitle: invite.title,
      );
      if (!accepted) return; // Kullanıcı taahhütnameyi onaylamadı
    }

    setState(() => _loadingProject = true);
    try {
      final project = await _projectService.getProject(invite.projectId!);
      setState(() => _loadingProject = false);

      if (project != null && mounted) {
        _showProjectDetailsBottomSheet(project, invite: invite);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Proje detayları yüklenemedi.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _loadingProject = false);
    }
  }

  Future<void> _handleProjectTap(ProjectModel project) async {
    // 1. Audition talebi kontrolü (castingInvite tipinde bildirim olmalı)
    final notifications = context.read<NotificationProvider>().notifications;
    final hasInvite = notifications.any(
      (n) => n.type == NotificationType.castingInvite && n.projectId == project.id,
    );

    if (!hasInvite) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu proje sizin için uygun değil.'),
            backgroundColor: AppTheme.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 2. Gizlilik Taahhütnamesi (NDA) Kontrolü
    final profileProvider = context.read<ActorProfileProvider>();
    final acceptedNdas = profileProvider.profile?.acceptedNdas ?? [];
    if (!acceptedNdas.contains(project.id)) {
      final accepted = await NdaAgreementDialog.show(
        context,
        projectId: project.id,
        projectTitle: project.title,
      );
      if (!accepted) return; // Kullanıcı taahhütnameyi onaylamadı
    }

    if (mounted) {
      _showProjectDetailsBottomSheet(project);
    }
  }

  void _showProjectDetailsBottomSheet(ProjectModel project, {NotificationModel? invite}) {
    ProjectDetailsBottomSheet.show(context, project, invite: invite);
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} sa önce';
    return DateFormat('dd.MM.yyyy').format(date);
  }
}
