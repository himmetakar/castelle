import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/services/project_service.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';

/// Castelle - Premium App Shell
/// Tüm roller için ortak BottomNavigationBar shell'i

class AppShell extends StatefulWidget {
  final List<AppShellTab> tabs;
  final UserRole role;

  const AppShell({
    super.key,
    required this.tabs,
    required this.role,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  List<ProjectModel> _activeProjects = [];

  @override
  void initState() {
    super.initState();
    // Bildirim dinlemeyi başlat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      final uid = user?.uid;
      final role = user?.role.value;
      if (uid != null) {
        context.read<NotificationProvider>().startListening(uid, role: role);
      }
      _loadActiveProjects();
    });
  }

  Future<void> _loadActiveProjects() async {
    try {
      final list = await ProjectService().getActiveProjects();
      if (mounted) {
        setState(() {
          _activeProjects = list;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: widget.tabs[_currentIndex].screen,
      ),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  int _getBadgeCount(BuildContext context, String tabLabel, UserRole role) {
    final notificationProvider = context.watch<NotificationProvider>();
    final unreadNotifs = notificationProvider.notifications.where((n) => !n.isRead);

    switch (role) {
      case UserRole.actor:
        if (tabLabel == 'Casting') {
          final auditionProvider = context.watch<AuditionProvider>();
          final auditions = auditionProvider.auditions;
          final approvedProjectIds = auditions
              .where((a) => a.status == AuditionStatus.approved)
              .map((a) => a.projectId)
              .toSet();

          return unreadNotifs.where((n) {
            if (n.type != NotificationType.castingInvite) return false;
            if (_activeProjects.isEmpty) return false;
            final projectIndex = _activeProjects.indexWhere((p) => p.id == n.projectId);
            if (projectIndex == -1) return false;

            final project = _activeProjects[projectIndex];
            if (approvedProjectIds.contains(project.id)) return false;
            if (project.deadline != null && DateTime.now().isAfter(project.deadline!)) return false;

            return true;
          }).length;
        }
        if (tabLabel == 'Başvurularım' || tabLabel == 'Videolarım') {
          return unreadNotifs.where((n) => n.type == NotificationType.auditionResult).length;
        }
        if (tabLabel == 'Takvim') {
          return unreadNotifs.where((n) => n.type == NotificationType.calendarEvent).length;
        }
        break;
      case UserRole.admin:
      case UserRole.moderator:
        if (tabLabel == 'Audition') {
          return unreadNotifs.where((n) => 
            n.type == NotificationType.newAudition || 
            n.type == NotificationType.forwardedAudition
          ).length;
        }
        if (tabLabel == 'Projeler') {
          return unreadNotifs.where((n) => n.type == NotificationType.newProject).length;
        }
        if (tabLabel == 'Takvim') {
          return unreadNotifs.where((n) => n.type == NotificationType.calendarEvent).length;
        }
        break;
    }
    return 0;
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        border: Border(
          top: BorderSide(
            color: AppTheme.primaryLight.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(widget.tabs.length, (index) {
              final tab = widget.tabs[index];
              final isSelected = _currentIndex == index;
              final badgeCount = _getBadgeCount(context, tab.label, widget.role);

              return Flexible(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.tabs.length > 5
                          ? (isSelected ? 6 : 4)
                          : (isSelected ? 16 : 12),
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              isSelected ? tab.activeIcon : tab.icon,
                              size: 22,
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                            if (badgeCount > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? Colors.white : AppTheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$badgeCount',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tab.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: widget.tabs.length > 5 ? 8.5 : 10,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Bottom navigation tab modeli
class AppShellTab {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget screen;

  const AppShellTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screen,
  });
}
