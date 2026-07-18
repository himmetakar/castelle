import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/core/services/audition_service.dart';
import 'package:castelle/features/director/screens/audition_review_screen.dart';

/// Castelle - İşveren Başvurular Ekranı
/// Kendisine yönlendirilen audition incelemelerini gösterir.
class EmployerAuditionsScreen extends StatefulWidget {
  const EmployerAuditionsScreen({super.key});

  @override
  State<EmployerAuditionsScreen> createState() =>
      _EmployerAuditionsScreenState();
}

class _EmployerAuditionsScreenState extends State<EmployerAuditionsScreen> {
  bool _loading = false;
  final List<_ForwardedItem> _items = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final notifProvider = context.read<NotificationProvider>();
    final forwarded = notifProvider.notifications
        .where((n) => n.type == NotificationType.forwardedAudition)
        .toList();

    final items = <_ForwardedItem>[];
    for (final notif in forwarded) {
      final auditionId = (notif.data?['auditionId'] as String?) ?? '';
      if (auditionId.isEmpty) continue;
      try {
        final audition = await AuditionService().getAudition(auditionId);
        if (audition != null) {
          items.add(_ForwardedItem(
            notification: notif,
            audition: audition,
          ));
        }
      } catch (_) {}
    }

    // Ayrıca projeye ait auditionları da getir
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      try {
        final projectSnap = await FirebaseFirestore.instance
            .collection('projects')
            .where('employerId', isEqualTo: uid)
            .get();
        final projectIds = projectSnap.docs.map((d) => d.id).toList();

        for (final pid in projectIds) {
          final auditions = await AuditionService().getProjectAuditions(pid);
          for (final aud in auditions) {
            // Daha önce eklenmemişse ekle
            final alreadyAdded = items.any((i) => i.audition.id == aud.id);
            if (!alreadyAdded) {
              items.add(_ForwardedItem(notification: null, audition: aud));
            }
          }
        }
      } catch (_) {}
    }

    // Tarihe göre sırala
    items.sort((a, b) => b.audition.createdAt.compareTo(a.audition.createdAt));

    if (mounted) {
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Notification değiştiğinde yeniden yükle (badge düşsün)
    context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Başvurular'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            )
          : _items.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.accent,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) =>
                        _buildCard(_items[index], index),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 56,
              color: AppTheme.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Henüz başvuru yok',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Projelerinize yapılan başvurular\nve yönlendirilen auditionlar burada görünür',
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

  Widget _buildCard(_ForwardedItem item, int index) {
    final audition = item.audition;
    final notif = item.notification;
    final isUnread = notif != null && !notif.isRead;

    final statusColor = _statusColor(audition.status);

    return GestureDetector(
      onTap: () async {
        // Okundu işaretle
        if (notif != null && isUnread) {
          context.read<NotificationProvider>().markAsRead(notif.id);
        }

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AuditionReviewScreen(
              audition: audition,
              adminNote: notif?.data?['note'] as String?,
              forwardedBy: notif?.data?['forwardedBy'] as String?,
              includeProfile: notif?.data?['includeProfile'] as bool?,
            ),
          ),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isUnread
                ? AppTheme.accent.withValues(alpha: 0.4)
                : AppTheme.border,
            width: isUnread ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _initials(audition.actorName),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Bilgi
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          audition.actorName,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${audition.projectTitle} › ${audition.roleName}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          audition.status.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (notif != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.info.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            'Yönlendirildi',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.info,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        _timeAgo(audition.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textTertiary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            const Icon(Icons.play_circle_outline,
                size: 26, color: AppTheme.accent),
          ],
        ),
      ).animate().fadeIn(delay: (30 + index * 25).ms),
    );
  }

  Color _statusColor(AuditionStatus status) {
    return switch (status) {
      AuditionStatus.uploading => AppTheme.textTertiary,
      AuditionStatus.submitted => AppTheme.info,
      AuditionStatus.reviewing => AppTheme.warning,
      AuditionStatus.options => Colors.purple,
      AuditionStatus.approved => AppTheme.success,
      AuditionStatus.rejected => AppTheme.error,
      AuditionStatus.revision => AppTheme.accent,
    };
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    return '${diff.inDays} gün önce';
  }
}

class _ForwardedItem {
  final NotificationModel? notification;
  final AuditionModel audition;

  _ForwardedItem({required this.notification, required this.audition});
}
