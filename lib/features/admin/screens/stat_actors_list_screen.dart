import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/services/notification_service.dart';

class StatActorsListScreen extends StatefulWidget {
  final String status;
  final String statusDisplayName;

  const StatActorsListScreen({
    super.key,
    required this.status,
    required this.statusDisplayName,
  });

  @override
  State<StatActorsListScreen> createState() => _StatActorsListScreenState();
}

class _StatActorsListScreenState extends State<StatActorsListScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isSending = false;

  // Benzersiz aktörleri ve onlara ait audition detaylarını çekeceğiz
  Stream<QuerySnapshot<Map<String, dynamic>>> _getAuditionsStream() {
    return FirebaseFirestore.instance
        .collection('auditions')
        .where('status', isEqualTo: widget.status)
        .snapshots();
  }

  // Toplu bildirim dialogu aç
  void _showBulkNotificationDialog(List<Map<String, String>> targetActors) {
    if (targetActors.isEmpty) return;

    final titleController = TextEditingController(
      text: widget.status == 'pending'
          ? 'Audition Hatırlatması'
          : '${widget.statusDisplayName} Hakkında',
    );
    final bodyController = TextEditingController(
      text: widget.status == 'pending'
          ? 'Talep süresi dolmadan audition videolarınızı yükleyip göndermeyi unutmayın.'
          : '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              title: Text(
                'Toplu Bildirim Gönder (${targetActors.length} Kişi)',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Bildirim Başlığı',
                        prefixIcon: Icon(Icons.title, size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Başlık boş bırakılamaz'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bildirim Mesajı',
                        prefixIcon: Icon(Icons.message_outlined, size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Mesaj boş bırakılamaz'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSending ? null : () => Navigator.pop(context),
                  child: Text(
                    'İptal',
                    style: GoogleFonts.inter(color: AppTheme.textTertiary),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSending
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => _isSending = true);
                          setState(() => _isSending = true);

                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          try {
                            final auth = context.read<AuthProvider>();
                            int sentCount = 0;

                            // Firestore batch ile her birine özel bildirim yaz
                            final batch = FirebaseFirestore.instance.batch();
                            for (final actor in targetActors) {
                              final actorId = actor['id']!;
                              final docRef = FirebaseFirestore.instance
                                  .collection('notifications')
                                  .doc();
                              batch.set(docRef, {
                                'recipientId': actorId,
                                'userId': actorId,
                                'title': titleController.text.trim(),
                                'body': bodyController.text.trim(),
                                'type': NotificationType.systemMessage.value,
                                'isRead': false,
                                'senderId': auth.user?.uid,
                                'senderName': auth.user?.fullName ?? 'Yönetici',
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              sentCount++;
                            }

                            await batch.commit();

                            if (mounted) {
                              navigator.pop();
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$sentCount kişiye toplu bildirim başarıyla gönderildi.',
                                  ),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Hata oluştu: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => _isSending = false);
                            if (mounted) setState(() => _isSending = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textOnAccent,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.textOnAccent,
                          ),
                        )
                      : const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Tekil bildirim dialogu aç
  void _showSingleNotificationDialog(String actorId, String actorName) {
    final titleController = TextEditingController(
      text: widget.status == 'pending'
          ? 'Audition Hatırlatması'
          : '${widget.statusDisplayName} Güncellemesi',
    );
    final bodyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              title: Text(
                '$actorName kullanıcısına Bildirim Gönder',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Bildirim Başlığı',
                        prefixIcon: Icon(Icons.title, size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Başlık boş bırakılamaz'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: bodyController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Bildirim Mesajı',
                        prefixIcon: Icon(Icons.message_outlined, size: 20),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Mesaj boş bırakılamaz'
                          : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSending ? null : () => Navigator.pop(context),
                  child: Text(
                    'İptal',
                    style: GoogleFonts.inter(color: AppTheme.textTertiary),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSending
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => _isSending = true);
                          setState(() => _isSending = true);

                          final navigator = Navigator.of(context);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          try {
                            final auth = context.read<AuthProvider>();
                            final notif = NotificationModel(
                              id: '',
                              recipientId: actorId,
                              title: titleController.text.trim(),
                              body: bodyController.text.trim(),
                              type: NotificationType.systemMessage,
                              senderId: auth.user?.uid,
                              senderName: auth.user?.fullName ?? 'Yönetici',
                              createdAt: DateTime.now(),
                            );

                            await _notificationService.sendNotification(notif);

                            if (mounted) {
                              navigator.pop();
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '$actorName kullanıcısına bildirim başarıyla gönderildi.',
                                  ),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Hata oluştu: $e'),
                                  backgroundColor: AppTheme.error,
                                ),
                              );
                            }
                          } finally {
                            setDialogState(() => _isSending = false);
                            if (mounted) setState(() => _isSending = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.textOnAccent,
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.textOnAccent,
                          ),
                        )
                      : const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          widget.statusDisplayName,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _getAuditionsStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            );
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people_outline,
                      size: 48, color: AppTheme.textTertiary),
                  const SizedBox(height: 16),
                  Text(
                    'Kullanıcı Bulunmuyor',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          // Benzersiz kullanıcıları çıkar
          final uniqueActors = <String, Map<String, String>>{};
          for (final doc in snap.data!.docs) {
            final data = doc.data();
            final actorId = data['actorId'] as String?;
            final actorName = data['actorName'] as String?;
            if (actorId != null && actorId.isNotEmpty) {
              uniqueActors[actorId] = {
                'id': actorId,
                'name': actorName ?? 'Bilinmeyen Oyuncu',
                'roleName': data['roleName'] as String? ?? 'Rol Belirtilmemiş',
                'projectName': data['projectName'] as String? ?? 'Proje Belirtilmemiş',
              };
            }
          }

          final actorList = uniqueActors.values.toList();

          return Column(
            children: [
              // Toplu Bildirim Gönderme Paneli
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign, size: 24, color: AppTheme.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Toplu Bildirim Gönder',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bu listedeki ${actorList.length} oyuncunun hepsine aynı anda bildirim gönder.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _showBulkNotificationDialog(actorList),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: AppTheme.textOnAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        'Bildirim Gönder',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Oyuncu Listesi
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: actorList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final actor = actorList[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppTheme.border.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                actor['name']!.isNotEmpty
                                    ? actor['name']![0].toUpperCase()
                                    : '?',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  actor['name']!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${actor['projectName']} · ${actor['roleName']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppTheme.textTertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () => _showSingleNotificationDialog(
                              actor['id']!,
                              actor['name']!,
                            ),
                            icon: const Icon(
                              Icons.send,
                              size: 18,
                              color: AppTheme.accent,
                            ),
                            tooltip: 'Bildirim Gönder',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
