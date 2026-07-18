import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/constants/user_roles.dart';

// Rol bazlı ekranlar
import 'package:castelle/features/admin/screens/admin_home_screen.dart';
import 'package:castelle/features/moderator/screens/moderator_home_screen.dart';
import 'package:castelle/features/actor/screens/actor_home_screen.dart';

/// Castelle - Role Based Shell
/// Giriş yapan kullanıcının rolüne göre doğru ana ekranı yönlendiren kabuk

class RoleBasedShell extends StatelessWidget {
  const RoleBasedShell({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userRole = authProvider.userRole;

    switch (userRole) {
      case UserRole.admin:
        return const AdminHomeScreen();
      case UserRole.moderator:
        return const ModeratorHomeScreen();
      case UserRole.actor:
        return const ActorHomeScreen();
      case null:
        return _buildLoadingScreen();
    }
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
    );
  }
}
