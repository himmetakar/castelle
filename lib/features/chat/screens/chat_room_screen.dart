import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/providers/auth_provider.dart';

class ChatRoomScreen extends StatefulWidget {
  final String actorId;
  final String actorName;

  const ChatRoomScreen({
    super.key,
    required this.actorId,
    required this.actorName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _chatId;
  bool _isInit = false;
  StreamSubscription<DocumentSnapshot>? _chatSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final authProvider = context.read<AuthProvider>();
      final adminId = authProvider.user!.uid;
      final actorId = widget.actorId;
      // Deterministic sorted chatId
      _chatId = adminId.compareTo(actorId) < 0 ? '${adminId}_$actorId' : '${actorId}_$adminId';
      _markAsRead();
      
      final isAdmin = authProvider.isAdmin || authProvider.isModerator;
      final updateField = isAdmin ? 'unreadByAdmin' : 'unreadByActor';

      _chatSubscription = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data() as Map<String, dynamic>?;
          final unreadCount = data?[updateField] ?? 0;
          if (unreadCount > 0) {
            _markAsRead();
          }
        }
      });

      _isInit = true;
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final authProvider = context.read<AuthProvider>();
    final isAdmin = authProvider.isAdmin || authProvider.isModerator;
    final updateField = isAdmin ? 'unreadByAdmin' : 'unreadByActor';

    await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
      updateField: 0,
    }, SetOptions(merge: true));

    // Also mark all chat notifications for this room as read!
    try {
      final notifQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: authProvider.user!.uid)
          .where('projectId', isEqualTo: _chatId)
          .where('isRead', isEqualTo: false)
          .get();
          
      if (notifQuery.docs.isNotEmpty) {
        final notifBatch = FirebaseFirestore.instance.batch();
        for (final doc in notifQuery.docs) {
          notifBatch.update(doc.reference, {'isRead': true});
        }
        await notifBatch.commit();
      }
    } catch (e) {
      debugPrint('Error marking chat notifications as read: $e');
    }
  }

  Future<void> _sendMessage({String? text, Map<String, dynamic>? calendarEvent}) async {
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && calendarEvent == null) return;

    if (text == null) {
      _messageController.clear();
    }

    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.user!.uid;
    final currentUserName = authProvider.user!.fullName;
    final isAdmin = authProvider.isAdmin || authProvider.isModerator;

    final docRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    final batch = FirebaseFirestore.instance.batch();

    // Create message document
    final messageRef = docRef.collection('messages').doc();
    batch.set(messageRef, {
      'senderId': currentUserId,
      'senderName': currentUserName,
      'text': messageText,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      if (calendarEvent != null) 'calendarEvent': calendarEvent,
    });

    // Update main chat meta
    batch.set(docRef, {
      'id': _chatId,
      'adminId': isAdmin ? currentUserId : widget.actorId,
      'adminName': isAdmin ? currentUserName : widget.actorName,
      'actorId': isAdmin ? widget.actorId : currentUserId,
      'actorName': isAdmin ? widget.actorName : currentUserName,
      'lastMessage': calendarEvent != null ? '📅 ${calendarEvent['title']}' : messageText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadByActor': isAdmin ? FieldValue.increment(1) : 0,
      'unreadByAdmin': isAdmin ? 0 : FieldValue.increment(1),
    }, SetOptions(merge: true));

    // Create notification document for the other participant
    // widget.actorId is always the OTHER party (admin or actor depending on who opened the screen)
    final otherPartyId = widget.actorId;
    final otherPartyName = widget.actorName;
    final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
    batch.set(notifRef, {
      'recipientId': otherPartyId,
      'userId': otherPartyId,
      'title': 'Yeni Mesaj: $currentUserName',
      'body': calendarEvent != null ? '📅 ${calendarEvent['title']}' : messageText,
      'type': 'system_message',
      'isRead': false,
      'senderId': currentUserId,
      'senderName': currentUserName,
      'recipientName': otherPartyName,
      'projectId': _chatId, // chatId stored in projectId for group querying
      'data': {
        'chatId': _chatId,
        'senderRole': isAdmin ? 'admin' : 'actor',
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCalendarAttachmentDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedType = 'interview'; // interview, audition, shoot

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surfaceCard,
              title: Text(
                'Takvim Planı Gönder',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Etkinlik Başlığı'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      dropdownColor: AppTheme.surfaceCard,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: const InputDecoration(labelText: 'Etkinlik Türü'),
                      items: const [
                        DropdownMenuItem(value: 'interview', child: Text('İş Görüşmesi')),
                        DropdownMenuItem(value: 'audition', child: Text('Canlı Audition')),
                        DropdownMenuItem(value: 'shoot', child: Text('Çekim Takvimi')),
                      ],
                      onChanged: (v) => setDialogState(() => selectedType = v ?? 'interview'),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(selectedDate)}',
                        style: GoogleFonts.inter(fontSize: 13.5, color: AppTheme.textPrimary),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month, color: AppTheme.accent),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            if (!context.mounted) return;
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDate),
                            );
                            if (time != null) {
                              setDialogState(() {
                                selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                              });
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal', style: TextStyle(color: AppTheme.textTertiary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Başlık alanı zorunludur.'), backgroundColor: AppTheme.warning),
                      );
                      return;
                    }

                    Navigator.pop(ctx);

                    final authProvider = context.read<AuthProvider>();
                    final adminId = authProvider.user!.uid;
                    final adminName = authProvider.user!.fullName;

                    // 1. Add to calendar_events collection
                    final eventRef = FirebaseFirestore.instance.collection('calendar_events').doc();
                    await eventRef.set({
                      'id': eventRef.id,
                      'title': title,
                      'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                      'eventDate': Timestamp.fromDate(selectedDate),
                      'recipientId': widget.actorId,
                      'senderId': adminId,
                      'eventType': selectedType,
                      'projectName': 'Castelle İrtibat',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // 2. Send Chat Message containing this event
                    final eventMap = {
                      'title': title,
                      'eventDate': Timestamp.fromDate(selectedDate),
                      'eventType': selectedType,
                      'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                    };
                    await _sendMessage(text: '📅 $title', calendarEvent: eventMap);

                    // 3. Send notification to the actor
                    final notifRef = FirebaseFirestore.instance.collection('notifications').doc();
                    final eventTypeName = selectedType == 'interview'
                        ? 'iş görüşmesi'
                        : selectedType == 'audition'
                            ? 'canlı audition'
                            : 'çekim planı';

                    await notifRef.set({
                      'recipientId': widget.actorId,
                      'userId': widget.actorId,
                      'title': 'Yeni Takvim Planı: $title',
                      'body': '$adminName sizin için bir $eventTypeName planladı. Detayları takviminizden inceleyebilirsiniz. 📅',
                      'type': 'calendar_event',
                      'isRead': false,
                      'senderId': adminId,
                      'senderName': adminName,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
                  child: const Text('Gönder'),
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
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin || authProvider.isModerator;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(widget.actorName, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Message stream list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Sohbeti başlatın',
                          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                // Auto scroll to bottom
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final senderId = data['senderId'] ?? '';
                    final text = data['text'] ?? '';
                    final calendarEvent = data['calendarEvent'] as Map<String, dynamic>?;
                    final isMe = senderId == authProvider.user!.uid;

                    final Timestamp? ts = data['createdAt'] as Timestamp?;
                    final timeStr = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

                    return _buildMessageBubble(text, isMe, timeStr, calendarEvent);
                  },
                );
              },
            ),
          ),

          // Message input bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                // Attach calendar option (Admin only)
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.accent, size: 28),
                    onPressed: _showCalendarAttachmentDialog,
                  ),
                const SizedBox(width: 8),

                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Mesajınızı yazın...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                GestureDetector(
                  onTap: () => _sendMessage(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isMe, String time, Map<String, dynamic>? calendarEvent) {
    if (calendarEvent != null) {
      return _buildCalendarEventBubble(calendarEvent, isMe, time);
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.accent : AppTheme.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16),
          ),
          border: isMe ? null : Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: isMe ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: GoogleFonts.inter(
                fontSize: 9,
                color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarEventBubble(Map<String, dynamic> event, bool isMe, String time) {
    final title = event['title'] ?? 'Takvim Planı';
    final desc = event['description'];
    final type = event['eventType'] ?? 'interview';
    final Timestamp? eventDateTs = event['eventDate'] as Timestamp?;

    final eventDateStr = eventDateTs != null
        ? DateFormat('dd MMMM yyyy - HH:mm', 'tr_TR').format(eventDateTs.toDate())
        : '';

    final typeLabel = type == 'interview'
        ? 'İş Görüşmesi'
        : type == 'audition'
            ? 'Canlı Audition'
            : 'Çekim Takvimi';

    final typeIcon = type == 'interview'
        ? Icons.handshake
        : type == 'audition'
            ? Icons.videocam
            : Icons.movie;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  Icon(typeIcon, color: AppTheme.accent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    typeLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),

            // Event Details
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppTheme.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          eventDateStr,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (desc != null && desc.toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      desc.toString(),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Timestamp footer
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Otomatik onaylandı • $time',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      color: AppTheme.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
