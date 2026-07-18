import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/widgets/notification_badge.dart';
import 'package:castelle/core/constants/user_roles.dart';
import 'package:castelle/features/actor/providers/actor_profile_provider.dart';
import 'package:castelle/features/chat/screens/chat_list_screen.dart';

/// Castelle - Dashboard Header
/// Tüm roller için ortak dashboard başlık widget'ı

class DashboardHeader extends StatelessWidget {
  final String greeting;
  final IconData roleIcon;
  final List<DashboardStat>? stats;
  final VoidCallback? onMenuPressed;

  const DashboardHeader({
    super.key,
    required this.greeting,
    required this.roleIcon,
    this.stats,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    String userName = authProvider.user?.fullName ?? 'Kullanıcı';
    bool isApproved = true;

    // Eğer rol oyuncu ise ismini ve onay durumunu profil modelinden çek
    if (authProvider.user?.role == UserRole.actor) {
      try {
        final profileProvider = context.watch<ActorProfileProvider>();
        final profile = profileProvider.profile;
        if (profile != null) {
          isApproved = profile.approvalStatus == 'approved';
          if (profile.fullName.trim().isNotEmpty) {
            userName = profile.fullName;
          }
        }
      } catch (_) {}
    }

    final parts = userName.trim().split(' ');
    String firstName = parts.first;
    if (firstName.toLowerCase() == 'demo' && parts.length > 1) {
      firstName = parts[1];
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Logo
                Row(
                  children: [
                    if (onMenuPressed != null) ...[
                      IconButton(
                        icon: const Icon(Icons.menu, color: AppTheme.textPrimary),
                        onPressed: onMenuPressed,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Image.asset(
                      'assets/images/ana-logo-siyah.png',
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),


                // Bildirim ikonu ve Profil Butonu
                Row(
                  children: [
                    if (isApproved) ...[
                      const ChatBadgeButton(),
                      const SizedBox(width: 12),
                      const NotificationBadge(),
                      const SizedBox(width: 12),
                    ],
                    GestureDetector(
                      onTap: () => _showLogoutDialog(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _getInitials(userName),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 28),

            // Selamlama
            Text(
              greeting,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textTertiary,
                letterSpacing: 0.5,
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 4),

            Row(
              children: [
                Text(
                  firstName,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(roleIcon, size: 24, color: AppTheme.accent),
              ],
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),

            // İstatistikler
            if (stats != null && stats!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: stats!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stat = entry.value;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: index < stats!.length - 1 ? 8 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.border.withValues(alpha: 0.7),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(stat.icon, size: 16, color: stat.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  stat.value,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  stat.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (400 + index * 100).ms)
                        .slideY(begin: 0.1),
                  );
                }).toList(),
              ),
            ],
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Çıkış Yap'),
          ),
        ],
      ),
    );
  }
}

/// Dashboard istatistik modeli
class DashboardStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.accent,
  });
}

class ChatBadgeButton extends StatelessWidget {
  const ChatBadgeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.uid;
    final isAdmin = authProvider.isAdmin || authProvider.isModerator;

    if (currentUserId == null) return const SizedBox();

    Query query = FirebaseFirestore.instance.collection('chats');
    if (isAdmin) {
      query = query.where('adminId', isEqualTo: currentUserId);
    } else {
      query = query.where('actorId', isEqualTo: currentUserId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final count = (isAdmin ? data['unreadByAdmin'] : data['unreadByActor']) ?? 0;
            unreadCount += count as int;
          }
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatListScreen()),
            );
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
