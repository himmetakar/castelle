import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/core/models/notification_model.dart';

/// Takvim içeriğini gösteren gömülebilir widget
class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late DateTime _selectedMonth;
  late DateTime _selectedDay;
  List<Map<String, dynamic>> _events = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _loadEvents();
    _clearCalendarNotifications();
  }

  Future<void> _clearCalendarNotifications() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final authProvider = context.read<AuthProvider>();
        final notifProvider = context.read<NotificationProvider>();
        final currentUserId = authProvider.user?.uid;
        if (currentUserId != null) {
          final calendarNotifs = notifProvider.notifications
              .where((n) =>
                  n.recipientId == currentUserId &&
                  n.type == NotificationType.calendarEvent &&
                  !n.isRead)
              .toList();
          for (final n in calendarNotifs) {
            notifProvider.markAsRead(n.id);
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.user!.uid;
      final isAdmin = authProvider.isAdmin || authProvider.isModerator;

      Query query = FirebaseFirestore.instance.collection('calendar_events');
      if (!isAdmin) {
        query = query.where('recipientId', isEqualTo: currentUserId);
      }

      final snapshot = await query.get();
      final loaded = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (isAdmin && data['recipientId'] != null) {
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['recipientId'])
              .get();
          if (userSnap.exists) {
            data['recipientName'] = userSnap.data()?['fullName'] ?? 'Oyuncu';
          }
        }
        loaded.add(data);
      }

      setState(() {
        _events = loaded;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading calendar events: $e');
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    return _events.where((event) {
      final Timestamp? ts = event['eventDate'] as Timestamp?;
      if (ts == null) return false;
      final d = ts.toDate();
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  Color _getEventColor(String type) {
    return switch (type) {
      'option' => AppTheme.warning,
      'interview' => AppTheme.info,
      'audition' => AppTheme.success,
      'shoot' => AppTheme.primarySoft,
      _ => AppTheme.accent,
    };
  }

  String _getEventLabel(String type) {
    return switch (type) {
      'option' => 'Opsiyon',
      'interview' => 'İş Görüşmesi',
      'audition' => 'Canlı Audition',
      'shoot' => 'Çekim Takvimi',
      _ => 'Etkinlik',
    };
  }

  IconData _getEventIcon(String type) {
    return switch (type) {
      'option' => Icons.bookmark_border,
      'interview' => Icons.handshake_outlined,
      'audition' => Icons.videocam_outlined,
      'shoot' => Icons.movie_creation_outlined,
      _ => Icons.event_note,
    };
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isAdmin = authProvider.isAdmin || authProvider.isModerator;

    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final startWeekday = _selectedMonth.weekday;
    final blankCells = startWeekday - 1;
    final totalCells = blankCells + daysInMonth;

    final monthName =
        DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);
    final selectedDayEvents = _getEventsForDate(_selectedDay);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppTheme.textPrimary),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month - 1, 1);
                  });
                },
              ),
              Text(
                monthName,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: AppTheme.textPrimary),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(
                            _selectedMonth.year, _selectedMonth.month + 1, 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh,
                        color: AppTheme.textTertiary, size: 20),
                    onPressed: _loadEvents,
                    tooltip: 'Yenile',
                  ),
                ],
              ),
            ],
          ),
        ),

        // Weekday names
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((day) {
              return SizedBox(
                width: 36,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textTertiary,
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Calendar Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 1.0,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < blankCells) return const SizedBox();

            final dayNum = index - blankCells + 1;
            final date =
                DateTime(_selectedMonth.year, _selectedMonth.month, dayNum);
            final isSelected = _selectedDay.year == date.year &&
                _selectedDay.month == date.month &&
                _selectedDay.day == date.day;

            final isToday = DateTime.now().year == date.year &&
                DateTime.now().month == date.month &&
                DateTime.now().day == date.day;

            final dayEvents = _getEventsForDate(date);

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = date),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accent
                      : isToday
                          ? AppTheme.accent.withValues(alpha: 0.1)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : isToday
                            ? AppTheme.accent.withValues(alpha: 0.4)
                            : AppTheme.border.withValues(alpha: 0.2),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight:
                            isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.white
                            : isToday
                                ? AppTheme.accent
                                : AppTheme.textPrimary,
                      ),
                    ),
                    if (dayEvents.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: dayEvents.take(3).map((event) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : _getEventColor(event['eventType'] ?? ''),
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Selected Day Details Header
        Row(
          children: [
            Text(
              DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(_selectedDay),
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${selectedDayEvents.length} Etkinlik',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Events for selected day
        if (selectedDayEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined,
                      size: 36,
                      color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(
                    'Bu gün için planlanmış etkinlik yok.',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: AppTheme.textTertiary),
                  ),
                ],
              ),
            ),
          )
        else
          ...selectedDayEvents.map((event) {
            final title = event['title'] ?? 'Takvim Etkinliği';
            final desc = event['description'];
            final type = event['eventType'] ?? 'interview';
            final recipientName = event['recipientName'];
            final Timestamp? eventDateTs = event['eventDate'] as Timestamp?;
            final timeStr = eventDateTs != null
                ? DateFormat('HH:mm').format(eventDateTs.toDate())
                : '';
            final eventColor = _getEventColor(type);
            final eventIcon = _getEventIcon(type);
            final eventLabel = _getEventLabel(type);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.border.withValues(alpha: 0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: eventColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(eventIcon, color: eventColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              eventLabel,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: eventColor,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (desc != null && desc.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            desc.toString(),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                        if (isAdmin && recipientName != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person,
                                  size: 12, color: AppTheme.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                'Oyuncu: $recipientName',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

/// Standalone takvim ekranı (bildirimden açıldığında kullanılır)
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Takvim',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: CalendarWidget(),
      ),
    );
  }
}
