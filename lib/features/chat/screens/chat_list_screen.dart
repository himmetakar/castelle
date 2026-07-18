import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/chat/screens/chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user!.uid;
    final isAdmin = authProvider.isAdmin || authProvider.isModerator;

    // Define collection query
    Query query = FirebaseFirestore.instance.collection('chats');
    if (isAdmin) {
      // Admin sees chats where adminId is currentUserId
      query = query.where('adminId', isEqualTo: currentUserId);
    } else {
      // Actor sees chats where actorId is currentUserId
      query = query.where('actorId', isEqualTo: currentUserId);
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Mesajlarım', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.shadowSm,
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Mesajlarda veya kişilerde ara...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  prefixIcon: Icon(Icons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // Chat Stream list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz mesajınız bulunmuyor.',
                          style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                var docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                 
                 // Sort client-side by lastMessageTime descending to bypass missing index error
                 docs.sort((a, b) {
                   final aData = a.data() as Map<String, dynamic>;
                   final bData = b.data() as Map<String, dynamic>;
                   final aTime = aData['lastMessageTime'] as Timestamp?;
                   final bTime = bData['lastMessageTime'] as Timestamp?;
                   if (aTime == null && bTime == null) return 0;
                   if (aTime == null) return 1;
                   if (bTime == null) return -1;
                   return bTime.compareTo(aTime);
                 });

                // Filter local results if search query is active
                if (_searchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final targetName = (isAdmin ? data['actorName'] : data['adminName'])?.toString().toLowerCase() ?? '';
                    final lastMsg = data['lastMessage']?.toString().toLowerCase() ?? '';
                    return targetName.contains(_searchQuery) || lastMsg.contains(_searchQuery);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Sonuç bulunamadı.',
                      style: GoogleFonts.inter(fontSize: 13.5, color: AppTheme.textTertiary),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final targetId = isAdmin ? (data['actorId'] ?? '') : (data['adminId'] ?? '');
                    final targetName = isAdmin ? (data['actorName'] ?? 'Oyuncu') : (data['adminName'] ?? 'Admin');
                    final lastMessage = data['lastMessage'] ?? '';
                    final unreadCount = (isAdmin ? data['unreadByAdmin'] : data['unreadByActor']) ?? 0;

                    final Timestamp? timeTs = data['lastMessageTime'] as Timestamp?;
                    String dateStr = '';
                    if (timeTs != null) {
                      final date = timeTs.toDate();
                      final now = DateTime.now();
                      if (date.day == now.day && date.month == now.month && date.year == now.year) {
                        dateStr = DateFormat('HH:mm').format(date);
                      } else {
                        dateStr = DateFormat('dd.MM.yyyy').format(date);
                      }
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
                          child: Text(
                            targetName.isNotEmpty ? targetName[0].toUpperCase() : '?',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                        title: Text(
                          targetName,
                          style: GoogleFonts.outfit(
                            fontSize: 14.5,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            color: unreadCount > 0 ? AppTheme.textPrimary : AppTheme.textSecondary,
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              dateStr,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: unreadCount > 0 ? AppTheme.accent : AppTheme.textTertiary,
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            if (unreadCount > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: AppTheme.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatRoomScreen(
                                actorId: targetId,
                                actorName: targetName,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
