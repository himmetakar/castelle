import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/services/audition_service.dart';
import 'package:castelle/core/services/notification_service.dart';
import 'package:castelle/core/models/notification_model.dart';

class ModeratorApprovalsScreen extends StatefulWidget {
  const ModeratorApprovalsScreen({super.key});

  @override
  State<ModeratorApprovalsScreen> createState() => _ModeratorApprovalsScreenState();
}

class _ModeratorApprovalsScreenState extends State<ModeratorApprovalsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;

  Future<void> _handleApproval(Map<String, dynamic> req, bool isApproved) async {
    setState(() {
      _isProcessing = true;
    });

    final reqId = req['id'];
    final auditionId = req['auditionId'];
    final actionType = req['actionType'];
    final reviewerNote = req['reviewerNote'];
    final moderatorId = req['moderatorId'];
    final moderatorName = req['moderatorName'];
    final projectTitle = req['projectTitle'] ?? '';
    final roleName = req['roleName'] ?? '';

    try {
      if (isApproved) {
        // Fetch original audition details to get actorId / projectId
        final audSnap = await _firestore.collection('auditions').doc(auditionId).get();
        String? actorId;
        String? projectId;
        if (audSnap.exists) {
          final audData = audSnap.data();
          actorId = audData?['actorId'];
          projectId = audData?['projectId'];
        }

        // Apply action to database
        if (actionType == 'approve') {
          await AuditionService().reviewAudition(
            auditionId: auditionId,
            status: AuditionStatus.approved,
            reviewerNote: reviewerNote,
            reviewerId: moderatorId,
            reviewerName: moderatorName,
          );
        } else if (actionType == 'reject') {
          await AuditionService().reviewAudition(
            auditionId: auditionId,
            status: AuditionStatus.rejected,
            reviewerNote: reviewerNote,
            reviewerId: moderatorId,
            reviewerName: moderatorName,
          );
        } else if (actionType == 'revision') {
          await AuditionService().reviewAudition(
            auditionId: auditionId,
            status: AuditionStatus.revision,
            reviewerNote: reviewerNote,
            reviewerId: moderatorId,
            reviewerName: moderatorName,
          );
        } else if (actionType == 'delete') {
          // Fetch video URL if available
          String videoUrl = '';
          if (audSnap.exists) {
            videoUrl = audSnap.data()?['videoUrl'] ?? '';
          }
          await AuditionService().deleteAudition(auditionId, videoUrl);
        } else if (actionType == 'message') {
          if (actorId != null) {
            final notif = NotificationModel(
              id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
              recipientId: actorId,
              title: 'Castelle Mesajı 📩',
              body: reviewerNote ?? '',
              type: NotificationType.systemMessage,
              isRead: false,
              senderId: moderatorId,
              senderName: moderatorName,
              projectId: projectId,
              createdAt: DateTime.now(),
            );
            await NotificationService().sendNotification(notif);
          }
        }

        // Update approval request status
        await _firestore.collection('moderator_approvals').doc(reqId).update({
          'status': 'approved',
          'processedAt': FieldValue.serverTimestamp(),
        });

        // Notify Moderator
        final notifToMod = NotificationModel(
          id: 'mod_notif_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: moderatorId,
          title: 'İşleminiz Onaylandı ✅',
          body: '"$projectTitle" - "$roleName" için yaptığınız audition işlemi (${_getActionDisplayName(actionType)}) Admin tarafından onaylandı.',
          type: NotificationType.systemMessage,
          createdAt: DateTime.now(),
        );
        await NotificationService().sendNotification(notifToMod);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Talep onaylandı ve işlem uygulandı.'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      } else {
        // Update approval request status to rejected
        await _firestore.collection('moderator_approvals').doc(reqId).update({
          'status': 'rejected',
          'processedAt': FieldValue.serverTimestamp(),
        });

        // Notify Moderator
        final notifToMod = NotificationModel(
          id: 'mod_notif_${DateTime.now().millisecondsSinceEpoch}',
          recipientId: moderatorId,
          title: 'İşleminiz Reddedildi ❌',
          body: '"$projectTitle" - "$roleName" için yaptığınız audition işlemi (${_getActionDisplayName(actionType)}) Admin tarafından reddedildi.',
          type: NotificationType.systemMessage,
          createdAt: DateTime.now(),
        );
        await NotificationService().sendNotification(notifToMod);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Talep reddedildi.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _getActionDisplayName(String actionType) {
    switch (actionType) {
      case 'approve':
        return 'Audition Onaylama';
      case 'reject':
        return 'Audition Reddetme';
      case 'revision':
        return 'Revize İsteme';
      case 'delete':
        return 'Audition Silme';
      case 'message':
        return 'Oyuncuya Mesaj';
      default:
        return actionType;
    }
  }

  Color _getActionColor(String actionType) {
    switch (actionType) {
      case 'approve':
        return AppTheme.success;
      case 'reject':
        return AppTheme.error;
      case 'revision':
        return AppTheme.accent;
      case 'delete':
        return Colors.red;
      case 'message':
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          'Moderatör Onayları',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('moderator_approvals')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Bir hata oluştu: ${snapshot.error}',
                    style: const TextStyle(color: AppTheme.error),
                  ),
                );
              }

              // Client-side sort: en yeni önce
              final docs = (snapshot.data?.docs ?? [])
                ..sort((a, b) {
                  final aTs = a.data()['createdAt'];
                  final bTs = b.data()['createdAt'];
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return (bTs as dynamic).compareTo(aTs as dynamic);
                });

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 64,
                        color: AppTheme.success,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bekleyen onay talebi bulunmuyor.',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data();
                  final actionType = data['actionType'] ?? '';
                  final reviewerNote = data['reviewerNote'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: AppTheme.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      side: const BorderSide(color: AppTheme.border, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getActionColor(actionType).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getActionDisplayName(actionType).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: _getActionColor(actionType),
                                  ),
                                ),
                              ),
                              Text(
                                data['moderatorName'] ?? 'Bilinmeyen Moderatör',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            data['actorName'] ?? 'Oyuncu Adı Yok',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${data['projectTitle'] ?? ''} - ${data['roleName'] ?? ''}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (reviewerNote != null && reviewerNote.toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              ),
                              child: Text(
                                reviewerNote,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isProcessing ? null : () => _handleApproval(data, false),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  label: const Text('Reddet'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error.withOpacity(0.1),
                                    foregroundColor: AppTheme.error,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isProcessing ? null : () => _handleApproval(data, true),
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: const Text('Onayla'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
                },
              );
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
