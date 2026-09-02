import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:castelle/core/widgets/app_shell.dart';
import 'package:castelle/core/widgets/dashboard_header.dart';
import 'package:castelle/core/widgets/profile_screen.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/features/admin/screens/actor_filter_results_screen.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/widgets/project_details_bottom_sheet.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/services/project_service.dart';
import 'package:castelle/features/actor/providers/actor_profile_provider.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';
import 'package:castelle/features/actor/screens/actor_profile_edit_screen.dart';
import 'package:castelle/features/actor/screens/audition_history_screen.dart';
import 'package:castelle/features/actor/screens/audition_submit_screen.dart';
import 'package:castelle/features/actor/screens/casting_invites_screen.dart';
import 'package:castelle/features/actor/widgets/nda_agreement_dialog.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';


/// Oyuncu / Sanatçı Ana Ekranı

class ActorHomeScreen extends StatefulWidget {
  const ActorHomeScreen({super.key});

  @override
  State<ActorHomeScreen> createState() => _ActorHomeScreenState();
}

class _ActorHomeScreenState extends State<ActorHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Profil ve audition verilerini yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<ActorProfileProvider>().loadProfile(uid);
        context.read<AuditionProvider>().loadActorAuditions(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ActorProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    if (profile.approvalStatus == 'rejected') {
      return Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.block,
                    color: AppTheme.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Üyeliğiniz Donduruldu',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Castelle üyelik haklarınız yönetici tarafından dondurulmuştur. Detaylar ve üyelik aktivasyonu için ajans yönetimi ile iletişime geçebilirsiniz.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (profile.adminNote != null && profile.adminNote!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
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
                          'Gerekçe / Yönetici Notu:',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.adminNote!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await context.read<AuthProvider>().signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(
                      'Çıkış Yap',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isApproved = profile.approvalStatus == 'approved';

    final tabs = [
      const AppShellTab(
        label: 'Panel',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        screen: _ActorDashboard(),
      ),
      if (isApproved) ...[
        const AppShellTab(
          label: 'Oyuncular',
          icon: Icons.person_search_outlined,
          activeIcon: Icons.person_search,
          screen: ActorFilterResultsScreen(),
        ),
        const AppShellTab(
          label: 'Casting',
          icon: Icons.campaign_outlined,
          activeIcon: Icons.campaign,
          screen: CastingInvitesScreen(),
        ),
        const AppShellTab(
          label: 'Başvurularım',
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment,
          screen: AuditionHistoryScreen(),
        ),
      ],
      const AppShellTab(
        label: 'Profil',
        icon: Icons.person_outlined,
        activeIcon: Icons.person,
        screen: ProfileScreen(),
      ),
    ];

    return AppShell(
      role: UserRole.actor,
      tabs: tabs,
    );
  }
}

class _ActorDashboard extends StatefulWidget {
  const _ActorDashboard();

  @override
  State<_ActorDashboard> createState() => _ActorDashboardState();
}

class _ActorDashboardState extends State<_ActorDashboard> {
  final ProjectService _projectService = ProjectService();
  bool _loadingProject = false;
  bool _showProfileCard = true;

  late DateTime _selectedMonth;
  late DateTime _selectedDay;
  List<ProjectModel> _projects = [];
  bool _loadingProjects = false;

  @override
  void initState() {
    super.initState();
    _loadProfileCardVisibility();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadProjects();
  }

  Future<void> _loadProfileCardVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _showProfileCard = prefs.getBool('show_profile_completion_card') ?? true;
      });
    } catch (_) {}
  }

  Future<void> _dismissProfileCard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_profile_completion_card', false);
      setState(() {
        _showProfileCard = false;
      });
    } catch (_) {}
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() => _loadingProjects = true);
    try {
      final list = await _projectService.getActiveProjects();
      if (mounted) {
        setState(() {
          _projects = list;
          _loadingProjects = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingProjects = false);
      }
    }
  }

  bool _doesProjectMatchDate(ProjectModel project, DateTime date) {
    if (project.shootDate == null || project.shootDate!.trim().isEmpty) return false;
    final shootStr = project.shootDate!.toLowerCase().trim();

    final turkishMonths = [
      'ocak', 'şubat', 'mart', 'nisan', 'mayıs', 'haziran',
      'temmuz', 'ağustos', 'eylül', 'ekim', 'kasım', 'aralık'
    ];

    final dateStr = '${date.day} ${turkishMonths[date.month - 1]} ${date.year}';

    if (shootStr.contains(dateStr)) {
      return true;
    }

    try {
      if (shootStr.contains('-')) {
        final parts = shootStr.split('-');
        if (parts.length == 2) {
          final start = _parseTurkishDate(parts[0].trim());
          final end = _parseTurkishDate(parts[1].trim());
          if (start != null && end != null) {
            final checkDate = DateTime(date.year, date.month, date.day);
            final checkStart = DateTime(start.year, start.month, start.day);
            final checkEnd = DateTime(end.year, end.month, end.day);
            return (checkDate.isAfter(checkStart) || checkDate.isAtSameMomentAs(checkStart)) &&
                   (checkDate.isBefore(checkEnd) || checkDate.isAtSameMomentAs(checkEnd));
          }
        }
      }
    } catch (_) {}

    return false;
  }

  DateTime? _parseTurkishDate(String str) {
    final months = [
      'ocak', 'şubat', 'mart', 'nisan', 'mayıs', 'haziran',
      'temmuz', 'ağustos', 'eylül', 'ekim', 'kasım', 'aralık'
    ];
    try {
      final parts = str.toLowerCase().split(' ');
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]);
        final monthIdx = months.indexOf(parts[1]);
        final year = int.tryParse(parts[2]);
        if (day != null && monthIdx != -1 && year != null) {
          return DateTime(year, monthIdx + 1, day);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _handleProjectTap(ProjectModel project) async {
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

    final profileProvider = context.read<ActorProfileProvider>();
    final acceptedNdas = profileProvider.profile?.acceptedNdas ?? [];
    if (!acceptedNdas.contains(project.id)) {
      final accepted = await NdaAgreementDialog.show(
        context,
        projectId: project.id,
        projectTitle: project.title,
      );
      if (!accepted) return;
    }

    if (mounted) {
      ProjectDetailsBottomSheet.show(context, project);
    }
  }

  Widget _buildCalendarWidget() {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final startWeekday = _selectedMonth.weekday; // 1 = Mon, 7 = Sun
    final blankCells = startWeekday - 1;
    final totalCells = blankCells + daysInMonth;

    final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);
    final selectedDayProjects = _projects.where((p) => _doesProjectMatchDate(p, _selectedDay)).toList();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month Selector Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppTheme.accent),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  monthName,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppTheme.accent),
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),

          // Weekday Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((day) {
                return SizedBox(
                  width: 32,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Calendar Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < blankCells) {
                  return const SizedBox();
                }

                final dayNum = index - blankCells + 1;
                final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayNum);
                final isSelected = _selectedDay.year == date.year &&
                    _selectedDay.month == date.month &&
                    _selectedDay.day == date.day;

                final dayProjects = _projects.where((p) => _doesProjectMatchDate(p, date)).toList();

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = date;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accent : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : AppTheme.border.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        if (dayProjects.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: dayProjects.take(3).map((proj) {
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1),
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: proj.primaryImageUrl != null && proj.primaryImageUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: proj.primaryImageUrl!,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: Colors.grey[300]),
                                          errorWidget: (_, __, ___) => const Icon(Icons.movie, size: 8, color: Colors.white),
                                        )
                                      : Container(
                                          color: AppTheme.accent,
                                          child: const Icon(Icons.movie, size: 8, color: Colors.white),
                                        ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Selected Day Projects Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_selectedDay),
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '${selectedDayProjects.length} Çekim',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          if (selectedDayProjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_note, size: 32, color: AppTheme.textTertiary.withValues(alpha: 0.4)),
                    const SizedBox(height: 6),
                    Text(
                      'Bugün için çekim planlanmadı.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: selectedDayProjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final project = selectedDayProjects[idx];
                return GestureDetector(
                  onTap: () => _handleProjectTap(project),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: project.primaryImageUrl != null && project.primaryImageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: project.primaryImageUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.grey[300]),
                                    errorWidget: (_, __, ___) => Image.asset('assets/images/ana-logo-siyah.png', fit: BoxFit.contain),
                                  )
                                : Container(
                                    color: Colors.white,
                                    child: Image.asset('assets/images/ana-logo-siyah.png', fit: BoxFit.contain),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    '${project.projectTypeLabel} · ${project.shootDate ?? "Tarih Belirtilmedi"}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                  if (project.deadline != null && DateTime.now().isAfter(project.deadline!))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Başvuru Süresi Geçti',
                                        style: GoogleFonts.inter(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.error,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, size: 18, color: AppTheme.accent),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ActorProfileProvider>();
    final profile = profileProvider.profile;
    final completion = profileProvider.completionPercentage;
    final isApproved = profile?.approvalStatus == 'approved';

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
          if (_loadingProjects && _projects.isEmpty) return true;
          final projectIndex = _projects.indexWhere((p) => p.id == n.projectId);
          if (projectIndex == -1) return false;
          
          final project = _projects[projectIndex];
          if (approvedProjectIds.contains(project.id)) return false;
          if (project.deadline != null && DateTime.now().isAfter(project.deadline!)) return false;
          
          return true;
        })
        .toList();

    final invitesCount = invites.length;
    final submissionsCount = auditions.length;
    final approvalsCount = auditions.where((a) => a.status == AuditionStatus.approved).length;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                DashboardHeader(
                  greeting: 'Oyuncu Paneli',
                  roleIcon: Icons.person,
                  stats: isApproved
                      ? [
                          DashboardStat(
                            label: 'Davet',
                            value: '$invitesCount',
                            icon: Icons.mail,
                            color: AppTheme.primary,
                          ),
                          DashboardStat(
                            label: 'Gönderim',
                            value: '$submissionsCount',
                            icon: Icons.upload,
                            color: AppTheme.primarySoft,
                          ),
                          DashboardStat(
                            label: 'Onay',
                            value: '$approvalsCount',
                            icon: Icons.check_circle,
                            color: AppTheme.success,
                          ),
                        ]
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Yönetici onayı bekleyen üyeler için uyarı kartı
                      if (!isApproved) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.warning.withValues(alpha: 0.15),
                                AppTheme.warning.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.hourglass_top_rounded,
                                      color: AppTheme.warning,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile?.approvalStatus == 'pending'
                                              ? 'Profiliniz Yönetici Onayı Bekliyor ⏳'
                                              : 'Profilinizi Tamamlayın ✨',
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          profile?.approvalStatus == 'pending'
                                              ? 'Yöneticilerimiz profil bilgilerinizi inceledikten sonra üyeliğinizi onaylayacaktır. Bu süreçte profilinizi güncelleyebilirsiniz.'
                                              : 'Profilinizi tamamlayarak admin onayına sunun ve oyuncularımız arasına katılın.',
                                          style: GoogleFonts.inter(
                                            fontSize: 12.5,
                                            color: AppTheme.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ActorProfileEditScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    profile?.approvalStatus == 'pending'
                                        ? Icons.edit_outlined
                                        : Icons.rocket_launch_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    profile?.approvalStatus == 'pending'
                                        ? 'Profilimi Düzenle'
                                        : 'Profilimi Tamamla & Onaya Sun 🚀',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: profile?.approvalStatus == 'pending'
                                        ? AppTheme.warning
                                        : AppTheme.accent,
                                    foregroundColor: profile?.approvalStatus == 'pending'
                                        ? Colors.black87
                                        : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn().slideY(begin: 0.1),
                        const SizedBox(height: 20),
                      ],

                      // Profil tamamlama kartı
                      if (_showProfileCard) ...[
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ActorProfileEditScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.accent.withValues(alpha: 0.12),
                                      AppTheme.primary.withValues(alpha: 0.05),
                                    ],
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(
                                    color: AppTheme.accent.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color:
                                                AppTheme.accent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.star,
                                              color: AppTheme.accent, size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                completion >= 70
                                                    ? 'Profilin Hazır!'
                                                    : 'Profilini Tamamla',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                completion >= 70
                                                    ? 'Düzenlemek için dokun'
                                                    : 'Yeteneklerini ekle, daha fazla casting davetiyesi al!',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: AppTheme.textTertiary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right,
                                            color: AppTheme.accent, size: 22),
                                      ],
                                    ),

                                    const SizedBox(height: 14),

                                    // Progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: completion / 100,
                                        backgroundColor: AppTheme.surfaceElevated,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          completion >= 70
                                              ? AppTheme.success
                                              : completion >= 40
                                                  ? AppTheme.primarySoft
                                                  : AppTheme.primaryLight,
                                        ),
                                        minHeight: 5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        '%$completion tamamlandı',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppTheme.textTertiary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _dismissProfileCard,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceElevated.withValues(alpha: 0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05),
                        const SizedBox(height: 16),
                      ],

                      if (isApproved) ...[
                        // Günün Mottosu Kartı
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('settings')
                              .doc('motto')
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox.shrink();
                            final data = snapshot.data?.data();
                            final motto = data?['text'] as String?;
                            if (motto == null || motto.trim().isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppTheme.primary.withValues(alpha: 0.08),
                                    AppTheme.primarySoft.withValues(alpha: 0.03),
                                  ],
                                ),
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_outline,
                                      color: AppTheme.accent,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Günün Mottosu',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.accent,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        MarqueeText(
                                          text: motto,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildCalendarWidget(),
                        const SizedBox(height: 24),
                        // Casting çağrıları bölümü
                        Text(
                          'Casting Talepleri',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ).animate().fadeIn(delay: 750.ms),
                        const SizedBox(height: 10),

                        if (invites.isEmpty)
                          // Boş durum
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceCard,
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              border: Border.all(color: AppTheme.border, width: 0.5),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.campaign, size: 36, color: AppTheme.textTertiary),
                                const SizedBox(height: 14),
                                Text(
                                  'Casting çağrısı bekleniyor',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Profiliniz tamamlandığında size uygun casting davetleri gelecektir.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 800.ms)
                        else
                          // Davet listesi
                          ...List.generate(invites.length, (index) {
                            final invite = invites[index];
                            return _buildInviteCard(invite, index);
                          }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_loadingProject)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
            ),
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
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
                children: [
                  _buildInviteImage(invite, size: 80),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 22, color: AppTheme.accent),
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

  void _showProjectDetailsBottomSheet(ProjectModel project, {NotificationModel? invite}) {
    ProjectDetailsBottomSheet.show(context, project, invite: invite);
  }

  Widget _buildRoleItem(ProjectModel project, ProjectRole role, {NotificationModel? invite}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
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
                role.roleName,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Kota: ${role.quota}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
          if (role.description != null && role.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              role.description!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (role.auditionNotes != null && role.auditionNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎬 Audition Notu:',
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
          const SizedBox(height: 12),
          // Gereksinimler & Bütçe
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (role.ageMin != null || role.ageMax != null)
                _buildRequirementChip(
                  Icons.cake_outlined,
                  role.ageMin != null && role.ageMax != null
                      ? '${role.ageMin}-${role.ageMax} yaş'
                      : role.ageMin != null
                          ? '${role.ageMin}+ yaş'
                          : '${role.ageMax}- yaş',
                ),
              if (role.gender != null)
                _buildRequirementChip(
                  Icons.person_outline,
                  role.gender == 'male'
                      ? 'Erkek'
                      : role.gender == 'female'
                          ? 'Kadın'
                          : 'Diğer',
                ),
              if (role.budget != null)
                _buildRequirementChip(
                  Icons.monetization_on_outlined,
                  'Bütçe: ${role.budget!.toStringAsFixed(0)} ₺',
                  backgroundColor: AppTheme.success.withValues(alpha: 0.12),
                  textColor: AppTheme.success,
                  borderColor: AppTheme.success.withValues(alpha: 0.3),
                ),
              if (role.requiredSkills.isNotEmpty)
                ...role.requiredSkills.map(
                  (s) => _buildRequirementChip(Icons.star_outline, s),
                ),
              if (role.ageMin == null &&
                  role.ageMax == null &&
                  role.gender == null &&
                  role.budget == null &&
                  role.requiredSkills.isEmpty)
                _buildRequirementChip(
                  Icons.info_outline,
                  'Gereksinim belirtilmedi',
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Builder(
                builder: (context) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  bool isDeadlinePassed = false;
                  if (project.deadline != null) {
                    final deadlineDate = DateTime(project.deadline!.year, project.deadline!.month, project.deadline!.day);
                    isDeadlinePassed = deadlineDate.isBefore(today);
                  }

                  return Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isDeadlinePassed
                          ? null
                          : () {
                              Navigator.pop(context); // Kapat details sheet
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AuditionSubmitScreen(
                                    project: project,
                                    role: role,
                                    customScript: invite?.data?['auditionScript'],
                                    budgetFlexible: invite?.data?['budgetFlexible'] as bool? ?? false,
                                  ),
                                ),
                              );
                            },
                      icon: Icon(
                        isDeadlinePassed ? Icons.lock_outline : Icons.videocam_outlined,
                        size: 18,
                      ),
                      label: Text(
                        isDeadlinePassed ? 'Başvuru Süresi Doldu' : 'Audition Gönder',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDeadlinePassed ? AppTheme.textTertiary : AppTheme.accent,
                        disabledForegroundColor: AppTheme.textTertiary,
                        side: BorderSide(
                          color: isDeadlinePassed ? AppTheme.border : AppTheme.accent,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: valueColor ?? AppTheme.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementChip(IconData icon, String text, {Color? backgroundColor, Color? textColor, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: borderColor ?? AppTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor ?? AppTheme.textTertiary),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: textColor ?? AppTheme.textSecondary,
              fontWeight: backgroundColor != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGalleryCarousel(BuildContext context, List<String> imageUrls) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          final url = imageUrls[index];
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
              width: 220,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border, width: 0.5),
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

class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double speed;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.speed = 30.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  Timer? _timer;
  double _offset = 0.0;
  bool _needsScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollNeeded();
    });
  }

  void _checkScrollNeeded() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      setState(() {
        _needsScrolling = true;
      });
      _startMarquee();
    }
  }

  void _startMarquee() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted || !_scrollController.hasClients) {
        timer.cancel();
        return;
      }
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      if (maxScrollExtent <= 0) return;

      _offset += widget.speed * 0.03;
      if (_offset >= maxScrollExtent) {
        _offset = 0.0;
        _scrollController.jumpTo(0.0);
      } else {
        _scrollController.jumpTo(_offset);
      }
    });
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      _offset = 0.0;
      _needsScrolling = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkScrollNeeded();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(
            widget.text,
            style: widget.style,
          ),
          if (_needsScrolling) ...[
            const SizedBox(width: 80),
            Text(
              widget.text,
              style: widget.style,
            ),
          ],
        ],
      ),
    );
  }
}

class RichTextRenderer extends StatelessWidget {
  final String text;
  final TextStyle style;

  const RichTextRenderer({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trimLeft();
        final isBullet = trimmed.startsWith('- ') || trimmed.startsWith('• ') || trimmed.startsWith('* ');
        final indent = line.length - trimmed.length;
        
        String cleanLine = line;
        if (isBullet) {
          if (trimmed.startsWith('- ')) cleanLine = trimmed.substring(2);
          else if (trimmed.startsWith('• ')) cleanLine = trimmed.substring(2);
          else if (trimmed.startsWith('* ')) cleanLine = trimmed.substring(2);
        }

        final List<TextSpan> spans = [];
        final RegExp regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*)');
        final matches = regex.allMatches(cleanLine);
        
        int lastIndex = 0;
        for (final match in matches) {
          if (match.start > lastIndex) {
            spans.add(TextSpan(
              text: cleanLine.substring(lastIndex, match.start),
            ));
          }
          
          final matchText = match.group(0)!;
          if (matchText.startsWith('**') && matchText.endsWith('**')) {
            spans.add(TextSpan(
              text: matchText.substring(2, matchText.length - 2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ));
          } else if (matchText.startsWith('*') && matchText.endsWith('*')) {
            spans.add(TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ));
          }
          
          lastIndex = match.end;
        }
        
        if (lastIndex < cleanLine.length) {
          spans.add(TextSpan(
            text: cleanLine.substring(lastIndex),
          ));
        }

        Widget lineWidget = RichText(
          text: TextSpan(
            children: spans,
            style: style,
          ),
        );

        if (isBullet) {
          lineWidget = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 8.0 + indent),
              Text('• ', style: style.copyWith(fontWeight: FontWeight.bold)),
              Expanded(child: lineWidget),
            ],
          );
        } else if (indent > 0) {
          lineWidget = Padding(
            padding: EdgeInsets.only(left: indent.toDouble()),
            child: lineWidget,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: lineWidget,
        );
      }).toList(),
    );
  }
}


