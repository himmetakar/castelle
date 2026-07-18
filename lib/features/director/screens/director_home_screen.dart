import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/widgets/app_shell.dart';
import 'package:castelle/core/widgets/dashboard_header.dart';
import 'package:castelle/core/widgets/notification_list_screen.dart';
import 'package:castelle/core/widgets/profile_screen.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';
import 'package:castelle/features/director/screens/audition_list_screen.dart';
import 'package:castelle/features/director/screens/audition_review_screen.dart';

/// Yönetmen Ana Ekranı

class DirectorHomeScreen extends StatefulWidget {
  const DirectorHomeScreen({super.key});

  @override
  State<DirectorHomeScreen> createState() => _DirectorHomeScreenState();
}

class _DirectorHomeScreenState extends State<DirectorHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<AuditionProvider>()
          .loadAllAuditions(status: AuditionStatus.submitted);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      role: UserRole.admin,
      tabs: const [
        AppShellTab(
          label: 'Panel',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          screen: _DirectorDashboard(),
        ),
        AppShellTab(
          label: 'İnceleme',
          icon: Icons.play_circle_outlined,
          activeIcon: Icons.play_circle,
          screen: AuditionListScreen(),
        ),
        AppShellTab(
          label: 'Bildirimler',
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          screen: NotificationListScreen(),
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

class _DirectorDashboard extends StatelessWidget {
  const _DirectorDashboard();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditionProvider>();
    final auditions = provider.auditions;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const DashboardHeader(
              greeting: 'Yönetmen Paneli',
              roleIcon: Icons.movie_creation,
              stats: [
                DashboardStat(
                  label: 'Bekleyen',
                  value: '—',
                  icon: Icons.pending,
                  color: AppTheme.primary,
                ),
                DashboardStat(
                  label: 'Onaylanan',
                  value: '—',
                  icon: Icons.check_circle,
                  color: AppTheme.primarySoft,
                ),
                DashboardStat(
                  label: 'Reddedilen',
                  value: '—',
                  icon: Icons.cancel,
                  color: AppTheme.success,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hızlı İnceleme kartı
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AuditionListScreen(),
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
                            child: const Icon(Icons.play_circle_fill,
                                color: AppTheme.accent, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Audition İncele',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Gelen başvuruları incele ve değerlendir',
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

                  const SizedBox(height: 24),

                  // Son gelen audition'lar
                  Text(
                    'Son Gelen Audition\'lar',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 12),

                  if (provider.isLoading && auditions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                            color: AppTheme.accent),
                      ),
                    )
                  else if (auditions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.border.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.movie_creation,
                              size: 44,
                              color: AppTheme.textTertiary
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 14),
                          Text(
                            'Bekleyen audition yok',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Yeni audition gönderildiğinde burada görünecektir',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 700.ms)
                  else
                    ...auditions.take(5).map((audition) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AuditionReviewScreen(audition: audition),
                            ),
                          );
                        },
                        child: Container(
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
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    _getInitials(audition.actorName),
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      audition.actorName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${audition.projectTitle} · ${audition.roleName}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppTheme.textTertiary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.play_circle_outline,
                                  size: 24, color: AppTheme.accent),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 700.ms);
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
