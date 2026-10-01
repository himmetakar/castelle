import 'package:flutter/material.dart';
import 'package:castelle/core/widgets/web_frame.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/widgets/project_details_bottom_sheet.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/core/services/project_service.dart';
import 'package:castelle/core/services/audition_service.dart';
import 'package:castelle/features/employer/screens/project_detail_screen.dart';
import 'package:castelle/features/chat/screens/chat_room_screen.dart';
import 'package:castelle/features/chat/screens/chat_list_screen.dart';
import 'package:castelle/core/widgets/calendar_screen.dart';
import 'package:castelle/features/director/screens/audition_review_screen.dart';
import 'package:castelle/features/actor/screens/audition_history_screen.dart';

/// Castelle - Bildirim Listesi Ekranı

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  bool _loadingProject = false;
  final ProjectService _projectService = ProjectService();
  final AuditionService _auditionService = AuditionService();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      final uid = user?.uid;
      final role = user?.role.value;
      if (uid != null) {
        context.read<NotificationProvider>().startListening(uid, role: role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications;
    final uid = context.read<AuthProvider>().user?.uid;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Bildirimler'),
            if (provider.hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '${provider.unreadCount}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textOnAccent,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (provider.hasUnread && uid != null)
            TextButton(
              onPressed: () => provider.markAllAsRead(uid),
              child: Text(
                'Tümünü Oku',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.accent,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          provider.isLoading && notifications.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                )
              : notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationTile(
                          notifications[index],
                          index,
                        );
                      },
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none,
              size: 56,
              color: AppTheme.textTertiary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Bildirim yok',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Yeni bildirimleriniz burada görünecektir',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel notif, int index) {
    final provider = context.read<NotificationProvider>();

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppTheme.error.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline,
            color: AppTheme.error, size: 22),
      ),
      onDismissed: (_) => provider.deleteNotification(notif.id),
      child: GestureDetector(
        onTap: () {
          if (!notif.isRead) {
            provider.markAsRead(notif.id);
          }
          final authProvider = context.read<AuthProvider>();
          final isActor = authProvider.isActor;
          
          final chatId = notif.data?['chatId'] as String?;
          if (chatId != null) {
            String targetId = notif.senderId ?? '';
            String targetName = notif.senderName ?? 'Destek / İrtibat';
            
            if (targetId.isEmpty || targetId == authProvider.user?.uid) {
              final parts = chatId.split('_');
              if (parts.length == 2) {
                targetId = parts.first == authProvider.user?.uid ? parts.last : parts.first;
              }
            }
            
            final outerContext = context;
            Navigator.push(
              outerContext,
              MaterialPageRoute(
                builder: (routeCtx) => ChatRoomScreen(
                  actorId: targetId,
                  actorName: targetName,
                ),
              ),
            );
            return;
          }

          if (notif.type == NotificationType.calendarEvent) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CalendarScreen(),
              ),
            );
            return;
          }

          // systemMessage tipi sadece chat bildirimidir — proje/davet işlemi yapma
          if (notif.type == NotificationType.systemMessage) {
            // chatId yoksa (eski bildirim), mesaj listesini aç
            if (chatId == null) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatListScreen()),
              );
            }
            return;
          }

          final isOption = notif.data?['isOption'] == 'true' ||
              notif.title.contains('Opsiyon') ||
              notif.body.toLowerCase().contains('opsiyon');

          if (isOption) {
            _handleOptionNotificationTap(notif, isActor);
            return;
          }

          if (notif.type == NotificationType.newAudition || notif.type == NotificationType.forwardedAudition) {
            _handleAuditionDetailNavigation(notif);
          } else if (notif.projectId != null) {
            if (isActor) {
              _handleInviteTap(notif);
            } else {
              _handleProjectDetailNavigation(notif);
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: notif.isRead
                ? Colors.transparent
                : AppTheme.accent.withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(
                color: AppTheme.border.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // İkon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _typeColor(notif.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _typeIcon(notif.type),
                  size: 20,
                  color: _typeColor(notif.type),
                ),
              ),
              const SizedBox(width: 14),

              // İçerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notif.title,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notif.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Gövde
                    Text(
                      notif.body,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textTertiary,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Zaman + Tür
                    Row(
                      children: [
                        Text(
                          _timeAgo(notif.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textTertiary
                                .withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppTheme.textTertiary
                                .withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notif.type.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: _typeColor(notif.type)
                                .withValues(alpha: 0.7),
                          ),
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
    ).animate().fadeIn(delay: (30 + index * 20).ms);
  }

  IconData _typeIcon(NotificationType type) {
    return switch (type) {
      NotificationType.castingInvite => Icons.campaign,
      NotificationType.projectUpdate => Icons.movie,
      NotificationType.auditionResult => Icons.how_to_vote,
      NotificationType.systemMessage => Icons.info_outline,
      NotificationType.announcement => Icons.notifications_active,
      NotificationType.roleAssigned => Icons.person_add,
      NotificationType.deadlineReminder => Icons.timer,
      NotificationType.newProject => Icons.movie_creation,
      NotificationType.newAudition => Icons.rate_review,
      NotificationType.forwardedAudition => Icons.forward_to_inbox,
      NotificationType.calendarEvent => Icons.calendar_month,
    };
  }

  Color _typeColor(NotificationType type) {
    return switch (type) {
      NotificationType.castingInvite => AppTheme.accent,
      NotificationType.projectUpdate => AppTheme.info,
      NotificationType.auditionResult => AppTheme.success,
      NotificationType.systemMessage => AppTheme.textSecondary,
      NotificationType.announcement => AppTheme.warning,
      NotificationType.roleAssigned => AppTheme.accent,
      NotificationType.deadlineReminder => AppTheme.error,
      NotificationType.newProject => AppTheme.info,
      NotificationType.newAudition => AppTheme.accent,
      NotificationType.forwardedAudition => AppTheme.success,
      NotificationType.calendarEvent => AppTheme.accent,
    };
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.year}';
  }

  Future<void> _handleProjectDetailNavigation(NotificationModel notif) async {
    setState(() => _loadingProject = true);
    try {
      final project = await _projectService.getProject(notif.projectId!);
      setState(() => _loadingProject = false);

      if (project != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(project: project),
          ),
        );
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

  Future<void> _handleOptionNotificationTap(NotificationModel notif, bool isActor) async {
    String? auditionId = notif.data?['auditionId'] as String?;
    
    setState(() => _loadingProject = true);
    try {
      if (auditionId == null && notif.projectId != null) {
        // Query to find audition
        final actorId = isActor 
            ? (context.read<AuthProvider>().user?.uid ?? '') 
            : (notif.senderId ?? '');
        if (actorId.isNotEmpty) {
          final snap = await FirebaseFirestore.instance
              .collection('auditions')
              .where('actorId', isEqualTo: actorId)
              .where('projectId', isEqualTo: notif.projectId)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            auditionId = snap.docs.first.id;
          }
        }
      }

      setState(() => _loadingProject = false);

      if (auditionId != null) {
        if (isActor) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuditionHistoryScreen(
                  initialTabIndex: 3, // Opsiyon tabı
                  highlightAuditionId: auditionId,
                ),
              ),
            );
          }
        } else {
          // Admin/Director -> Open review screen
          final audition = await _auditionService.getAudition(auditionId);
          if (audition != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AuditionReviewScreen(
                  audition: audition,
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opsiyon detayları bulunamadı.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _loadingProject = false);
    }
  }

  Future<void> _handleAuditionDetailNavigation(NotificationModel notif) async {
    final auditionId = notif.data?['auditionId'] as String?;
    if (auditionId == null) return;

    setState(() => _loadingProject = true);
    try {
      final audition = await _auditionService.getAudition(auditionId);
      setState(() => _loadingProject = false);

      if (audition != null && mounted) {
        final data = notif.data;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AuditionReviewScreen(
              audition: audition,
              adminNote: data?['note'] as String?,
              attachedPhoto: data?['attachedPhoto'] as String?,
              attachedFile: data?['attachedFile'] as String?,
              forwardedBy: data?['forwardedBy'] as String?,
              includeProfile: data?['includeProfile'] as bool? ?? false,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audition detayları yüklenemedi.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (_) {
      setState(() => _loadingProject = false);
    }
  }

  Future<void> _handleInviteTap(NotificationModel invite) async {
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
  Widget build(BuildContext context) =>
      MaxWidthBox(maxWidth: 640, child: _buildPlayer(context));

  Widget _buildPlayer(BuildContext context) {
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
          if (trimmed.startsWith('- ')) {
            cleanLine = trimmed.substring(2);
          } else if (trimmed.startsWith('• ')) {
            cleanLine = trimmed.substring(2);
          } else if (trimmed.startsWith('* ')) {
            cleanLine = trimmed.substring(2);
          }
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
