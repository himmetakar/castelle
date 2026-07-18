import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:castelle/core/widgets/dashboard_header.dart';
import 'package:castelle/core/widgets/calendar_screen.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/features/admin/screens/send_notification_screen.dart';
import 'package:castelle/features/admin/screens/assign_moderator_screen.dart';
import 'package:castelle/features/admin/screens/actor_filter_results_screen.dart';
import 'package:castelle/features/admin/screens/new_members_screen.dart';
import 'package:castelle/features/director/screens/audition_list_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/constants/app_constants.dart';
import 'package:castelle/features/admin/screens/stat_actors_list_screen.dart';
import 'package:castelle/features/admin/screens/moderator_approvals_screen.dart';

/// Admin Dashboard - İstatistikler ve hızlı aksiyonlar

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _mottoController = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingMotto = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentMotto();
  }

  Future<void> _loadCurrentMotto() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('motto')
          .get();
      if (doc.exists && doc.data() != null) {
        _mottoController.text = doc.data()?['text'] ?? '';
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingMotto = false;
      });
    }
  }

  Future<void> _saveMotto() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('motto')
          .set({
        'text': _mottoController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Günün mottosu başarıyla güncellendi.'),
            backgroundColor: AppTheme.success,
          ),
        );
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
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _mottoController.dispose();
    super.dispose();
  }

  @override
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.surface,
      drawer: _buildAdminDrawer(context),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            DashboardHeader(
              greeting: 'Yönetim Paneli',
              roleIcon: Icons.admin_panel_settings,
              onMenuPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
              stats: const [
                DashboardStat(
                  label: 'Kullanıcı',
                  value: '0',
                  icon: Icons.people,
                  color: AppTheme.primary,
                ),
                DashboardStat(
                  label: 'Proje',
                  value: '0',
                  icon: Icons.movie,
                  color: AppTheme.primarySoft,
                ),
                DashboardStat(
                  label: 'Audition',
                  value: '0',
                  icon: Icons.videocam,
                  color: AppTheme.success,
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Takvim Bölümü
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Takvim',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
                      boxShadow: AppTheme.shadowSm,
                    ),
                    child: const CalendarWidget(),
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 24),

                  // ─── Audition İstatistikleri ───────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.bar_chart, size: 18, color: AppTheme.accent),
                      const SizedBox(width: 8),
                      Text(
                        'Audition İstatistikleri',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms),
                  const SizedBox(height: 14),
                  _buildAuditionStats(),

                  const SizedBox(height: 24),

                  // Günün Mottosu Bölümü
                  Text(
                    'Günün Mottosu',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ).animate().fadeIn(delay: 950.ms),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: AppTheme.border.withValues(alpha: 0.3),
                      ),
                    ),
                    child: _isLoadingMotto
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(
                                color: AppTheme.accent,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bu mottolu yazı tüm kullanıcı panellerinde kayan yazı olarak gösterilecektir.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _mottoController,
                                maxLines: 2,
                                maxLength: 150,
                                decoration: InputDecoration(
                                  hintText: 'Günün mottosunu girin...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppTheme.textTertiary,
                                  ),
                                  filled: true,
                                  fillColor: AppTheme.surfaceLight,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    borderSide: BorderSide(
                                      color: AppTheme.border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    borderSide: BorderSide(
                                      color: AppTheme.border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    borderSide: const BorderSide(
                                      color: AppTheme.accent,
                                      width: 1.5,
                                    ),
                                  ),
                                  counterText: '',
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isSaving ? null : _saveMotto,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accent,
                                    foregroundColor: AppTheme.textOnAccent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: AppTheme.textOnAccent,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Motto Güncelle',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                  ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.03),

                  const SizedBox(height: 24),

                  // Son Aktiviteler

                  Text(
                    'Son Aktiviteler',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ).animate().fadeIn(delay: 1050.ms),

                  const SizedBox(height: 14),

                  _buildEmptyState(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditionStats() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('auditions').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        final docs = snap.data!.docs;
        final total = docs.length;

        // Durum sayaçları
        int pending = 0, submitted = 0, reviewing = 0, options = 0, approved = 0, rejected = 0, revision = 0, noResponse = 0;

        // Oyuncu başına sayaçlar
        final Map<String, int> actorApproved = {};
        final Map<String, int> actorRejected = {};
        final Map<String, String> actorNames = {};

        for (final doc in docs) {
          final d = doc.data();
          final status = d['status'] as String? ?? '';
          final actorId = d['actorId'] as String? ?? '';
          final actorName = d['actorName'] as String? ?? actorId;
          actorNames[actorId] = actorName;

          switch (status) {
            case 'pending': pending++; break;
            case 'submitted': submitted++; break;
            case 'reviewing': reviewing++; break;
            case 'options': options++; break;
            case 'approved':
              approved++;
              actorApproved[actorId] = (actorApproved[actorId] ?? 0) + 1;
              break;
            case 'rejected':
              rejected++;
              actorRejected[actorId] = (actorRejected[actorId] ?? 0) + 1;
              break;
            case 'revision': revision++; break;
          }
          // Talep gönderilmiş ama hâlâ pending — dönüş yok
          if (status == 'pending') noResponse++;
        }

        // En çok onaylanan/reddedilen oyuncu
        String topApprovedName = '-';
        int topApprovedCount = 0;
        actorApproved.forEach((id, cnt) {
          if (cnt > topApprovedCount) {
            topApprovedCount = cnt;
            topApprovedName = actorNames[id] ?? id;
          }
        });
        String topRejectedName = '-';
        int topRejectedCount = 0;
        actorRejected.forEach((id, cnt) {
          if (cnt > topRejectedCount) {
            topRejectedCount = cnt;
            topRejectedName = actorNames[id] ?? id;
          }
        });

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Özet sayaçlar
              Row(
                children: [
                  _statChip('Toplam', total, AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  _statChip(
                    'Dönüş Yok',
                    noResponse,
                    AppTheme.warning,
                    status: 'pending',
                    statusDisplayName: 'Dönüş Yapmayan Oyuncular',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'İnceleniyor',
                    reviewing,
                    AppTheme.primarySoft,
                    status: 'reviewing',
                    statusDisplayName: 'İnceleniyor Durumundakiler',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Gönderildi',
                    submitted,
                    AppTheme.accent,
                    status: 'submitted',
                    statusDisplayName: 'Gönderildi Durumundakiler',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _statChip(
                    'Opsiyonlu',
                    options,
                    Colors.purple,
                    status: 'options',
                    statusDisplayName: 'Opsiyonlu Olanlar',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Onaylandı',
                    approved,
                    AppTheme.success,
                    status: 'approved',
                    statusDisplayName: 'Onaylanan Oyuncular',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Reddedildi',
                    rejected,
                    AppTheme.error,
                    status: 'rejected',
                    statusDisplayName: 'Reddedilen Oyuncular',
                  ),
                  const SizedBox(width: 8),
                  _statChip(
                    'Revizyon',
                    revision,
                    AppTheme.warning,
                    status: 'revision',
                    statusDisplayName: 'Revizyon Talep Edilenler',
                  ),
                ],
              ),

              if (total > 0) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Bar grafik
                _buildStatusBar(
                  [
                    _BarSegment('Onay', approved, AppTheme.success),
                    _BarSegment('Opsiyon', options, Colors.purple),
                    _BarSegment('Bekl.', submitted + pending, AppTheme.accent),
                    _BarSegment('Red', rejected, AppTheme.error),
                    _BarSegment('Rev.', revision, AppTheme.warning),
                  ],
                  total,
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // En çok onaylanan
                _topActorRow(
                  icon: Icons.emoji_events_outlined,
                  color: AppTheme.success,
                  label: 'En çok onaylanan:',
                  name: topApprovedName,
                  count: topApprovedCount,
                ),
                const SizedBox(height: 8),
                // En çok reddedilen
                _topActorRow(
                  icon: Icons.block_outlined,
                  color: AppTheme.error,
                  label: 'En çok reddedilen:',
                  name: topRejectedName,
                  count: topRejectedCount,
                ),
              ],
            ],
          ),
        ).animate().fadeIn(delay: 1020.ms);
      },
    );
  }

  Widget _statChip(String label, int count, Color color, {String? status, String? statusDisplayName}) {
    final clickable = status != null;
    return Flexible(
      child: GestureDetector(
        onTap: clickable
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatActorsListScreen(
                      status: status,
                      statusDisplayName: statusDisplayName!,
                    ),
                  ),
                );
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: clickable ? Border.all(color: color.withValues(alpha: 0.25), width: 0.5) : null,
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(List<_BarSegment> segments, int total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: segments.map((s) {
              final ratio = total > 0 ? s.count / total : 0.0;
              if (ratio == 0) return const SizedBox.shrink();
              return Flexible(
                flex: s.count,
                child: Container(
                  height: 12,
                  color: s.color,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: segments.map((s) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${s.label} ${s.count}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          )).toList(),
        ),
      ],
    );
  }

  Widget _topActorRow({required IconData icon, required Color color, required String label, required String name, required int count}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text('$count', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ),
      ],
    );
  }

    Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surfaceCard,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 40,
                    width: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Castelle',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Yönetici Paneli',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Drawer Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                children: [
                  _buildDrawerTile(
                    context,
                    icon: Icons.shield_outlined,
                    title: 'Moderatör Atama',
                    subtitle: 'Yeni moderatör atamalarını yönet',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AssignModeratorScreen()),
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('moderator_approvals')
                          .where('status', isEqualTo: 'pending')
                          .snapshots(),
                      builder: (context, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        return _buildDrawerTile(
                          context,
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Moderatör Onayları',
                          subtitle: 'Onay bekleyen moderatör işlemleri',
                          trailing: count > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ModeratorApprovalsScreen()),
                            );
                          },
                        );
                      },
                    ),
                  
                  // Yeni Üyeler with StreamBuilder for pending badge
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(AppConstants.usersCollection)
                        .where('role', isEqualTo: 'actor')
                        .where('approvalStatus', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return _buildDrawerTile(
                        context,
                        icon: Icons.person_add_outlined,
                        title: 'Yeni Üyeler',
                        subtitle: 'Onay bekleyen üye profilleri',
                        trailing: count > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.error,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NewMembersScreen()),
                          );
                        },
                      );
                    },
                  ),
                  
                  _buildDrawerTile(
                    context,
                    icon: Icons.filter_list,
                    title: 'Oyuncu Filtrele',
                    subtitle: 'Yetenek havuzunda arama yap',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ActorFilterResultsScreen()),
                      );
                    },
                  ),
                  
                  _buildDrawerTile(
                    context,
                    icon: Icons.send_outlined,
                    title: 'Toplu Bildirim',
                    subtitle: 'Oyunculara push bildirim gönder',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SendNotificationScreen()),
                      );
                    },
                  ),
                  
                  _buildDrawerTile(
                    context,
                    icon: Icons.video_library_outlined,
                    title: 'Video İncele',
                    subtitle: 'Gelen audition videolarını gör',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AuditionListScreen(isAdmin: true)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: AppTheme.accent),
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: AppTheme.textTertiary,
          ),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right, size: 16, color: AppTheme.textTertiary),
      ),
    );
  }


  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 40,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz aktivite yok',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1150.ms);
  }
}


/// Bar grafik segment yardmc snf
class _BarSegment {
  final String label;
  final int count;
  final Color color;
  const _BarSegment(this.label, this.count, this.color);
}
