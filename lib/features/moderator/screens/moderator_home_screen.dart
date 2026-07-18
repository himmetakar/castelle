import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/widgets/app_shell.dart';
import 'package:castelle/core/widgets/dashboard_header.dart';
import 'package:castelle/core/widgets/profile_screen.dart';
import 'package:castelle/core/widgets/calendar_screen.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/features/admin/screens/actor_filter_results_screen.dart';
import 'package:castelle/features/director/screens/audition_list_screen.dart';
import 'package:castelle/features/employer/screens/project_list_screen.dart';

/// Moderatör Ana Ekranı

class ModeratorHomeScreen extends StatelessWidget {
  const ModeratorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      role: UserRole.moderator,
      tabs: const [
        AppShellTab(
          label: 'Panel',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          screen: _ModeratorDashboard(),
        ),
        AppShellTab(
          label: 'Projeler',
          icon: Icons.movie_outlined,
          activeIcon: Icons.movie,
          screen: ProjectListScreen(isModerator: true),
        ),
        AppShellTab(
          label: 'Oyuncular',
          icon: Icons.person_search_outlined,
          activeIcon: Icons.person_search,
          screen: ActorFilterResultsScreen(),
        ),
        AppShellTab(
          label: 'Videolar',
          icon: Icons.video_library_outlined,
          activeIcon: Icons.video_library,
          screen: AuditionListScreen(isModerator: true),
        ),

        AppShellTab(
          label: 'Profil',
          icon: Icons.person_outlined,
          activeIcon: Icons.person,
          screen: ProfileScreen(),
        ),
      ],
    );
  }
}

class _ModeratorDashboard extends StatelessWidget {
  const _ModeratorDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardHeader(
              greeting: 'Moderasyon Paneli',
              roleIcon: Icons.shield,
              stats: [
                DashboardStat(
                  label: 'Oyuncu',
                  value: '0',
                  icon: Icons.people,
                  color: AppTheme.primary,
                ),
                DashboardStat(
                  label: 'Bekleyen',
                  value: '0',
                  icon: Icons.pending,
                  color: AppTheme.primarySoft,
                ),
                DashboardStat(
                  label: 'Gönderim',
                  value: '0',
                  icon: Icons.send,
                  color: AppTheme.success,
                ),
              ],
            ),

            // Takvim Bölümü
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month,
                      size: 18, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Text(
                    'Takvim',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                      color: AppTheme.border.withValues(alpha: 0.4)),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: const CalendarWidget(),
              ),
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                      color: AppTheme.border.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.shield,
                        size: 48,
                        color: AppTheme.textTertiary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text(
                      'Moderasyon alanınız hazır',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Oyuncu filtreleme aktif! Oyuncular sekmesinden arama yapabilirsiniz.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 700.ms),
            ),
          ],
        ),
      ),
    );
  }
}
