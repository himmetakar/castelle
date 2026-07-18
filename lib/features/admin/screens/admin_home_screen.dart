import 'package:flutter/material.dart';
import 'package:castelle/core/widgets/app_shell.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/core/widgets/profile_screen.dart';
import 'package:castelle/features/admin/screens/admin_dashboard.dart';
import 'package:castelle/features/admin/screens/admin_users_screen.dart';
import 'package:castelle/features/admin/screens/actor_filter_results_screen.dart';
import 'package:castelle/features/employer/screens/project_list_screen.dart';
import 'package:castelle/features/director/screens/audition_list_screen.dart';

/// Admin Ana Ekranı - Bottom Navigation ile

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      role: UserRole.admin,
      tabs: const [
        AppShellTab(
          label: 'Panel',
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard,
          screen: AdminDashboard(),
        ),
        AppShellTab(
          label: 'Kullanıcılar',
          icon: Icons.people_outlined,
          activeIcon: Icons.people,
          screen: AdminUsersScreen(),
        ),
        AppShellTab(
          label: 'Oyuncular',
          icon: Icons.person_search_outlined,
          activeIcon: Icons.person_search,
          screen: ActorFilterResultsScreen(),
        ),
        AppShellTab(
          label: 'Projeler',
          icon: Icons.movie_outlined,
          activeIcon: Icons.movie,
          screen: ProjectListScreen(isAdmin: true),
        ),
        AppShellTab(
          label: 'Audition',
          icon: Icons.videocam_outlined,
          activeIcon: Icons.videocam,
          screen: AuditionListScreen(isAdmin: true),
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
