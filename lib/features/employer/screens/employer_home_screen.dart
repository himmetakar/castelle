import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/widgets/app_shell.dart';
import 'package:castelle/core/widgets/dashboard_header.dart';
import 'package:castelle/core/widgets/profile_screen.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/employer/providers/project_provider.dart';
import 'package:castelle/features/employer/screens/project_list_screen.dart';
import 'package:castelle/features/employer/screens/project_create_screen.dart';
import 'package:castelle/features/employer/screens/employer_auditions_screen.dart';

/// İş Veren Ana Ekranı

class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<ProjectProvider>().loadEmployerProjects(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      role: UserRole.admin,
      tabs: [
        const AppShellTab(
          label: 'Panel',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          screen: _EmployerDashboard(),
        ),
        const AppShellTab(
          label: 'Projeler',
          icon: Icons.movie_outlined,
          activeIcon: Icons.movie,
          screen: ProjectListScreen(),
        ),
        const AppShellTab(
          label: 'Başvurular',
          icon: Icons.inbox_outlined,
          activeIcon: Icons.inbox,
          screen: EmployerAuditionsScreen(),
        ),
        const AppShellTab(
          label: 'Profil',
          icon: Icons.person_outlined,
          activeIcon: Icons.person,
          screen: ProfileScreen(),
        ),
      ],
    );
  }
}

class _EmployerDashboard extends StatelessWidget {
  const _EmployerDashboard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            DashboardHeader(
              greeting: 'İş Veren Paneli',
              roleIcon: Icons.business,
              stats: [
                DashboardStat(
                  label: 'Proje',
                  value: '${provider.totalProjects}',
                  icon: Icons.movie,
                  color: AppTheme.primary,
                ),
                DashboardStat(
                  label: 'Aktif',
                  value: '${provider.activeProjects}',
                  icon: Icons.play_arrow,
                  color: AppTheme.primarySoft,
                ),
                DashboardStat(
                  label: 'Casting',
                  value: '${provider.castingProjects}',
                  icon: Icons.campaign,
                  color: AppTheme.success,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hızlı aksiyonlar
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProjectCreateScreen(),
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
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add,
                                color: AppTheme.accent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Yeni Proje Oluştur',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Casting sürecini hemen başlat',
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
                    ),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.05),

                  const SizedBox(height: 20),

                  // Son projeler önizleme
                  if (provider.projects.isNotEmpty) ...[
                    Text(
                      'Son Projeler',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ).animate().fadeIn(delay: 600.ms),

                    const SizedBox(height: 12),

                    ...provider.projects.take(3).map((project) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: AppTheme.border, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _projectEmoji(project.projectType),
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    project.title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${project.roles.length} rol · ${project.status.displayName}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 700.ms);
                    }),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.movie_creation_outlined,
                              size: 44,
                              color: AppTheme.textTertiary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 14),
                          Text(
                            'Henüz projeniz yok',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'İlk projenizi oluşturarak casting sürecini başlatın',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _projectEmoji(String? type) {
    return switch (type) {
      'film' => '🎬',
      'dizi' => '📺',
      'reklam' => '📢',
      'klip' => '🎵',
      'tiyatro' => '🎭',
      'kisa_film' => '🎞️',
      _ => '🎬',
    };
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Bu modül yakında eklenecek',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
