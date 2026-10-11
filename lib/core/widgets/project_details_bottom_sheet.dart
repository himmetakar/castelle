import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/widgets/app_video_player.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/features/actor/screens/audition_submit_screen.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

/// Castelle - Proje Detayları Alt Sayfası (Bottom Sheet)
/// Oyuncunun audition talebini veya proje detaylarını incelediği ekran.
class ProjectDetailsBottomSheet extends StatefulWidget {
  final ProjectModel project;
  final NotificationModel? invite;

  const ProjectDetailsBottomSheet({
    super.key,
    required this.project,
    this.invite,
  });

  /// Bottom Sheet'i gösteren static yardımcı metot
  static void show(BuildContext context, ProjectModel project, {NotificationModel? invite}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            // Telefonun yazı boyutu ayarı çok büyükse satırlar farklı
            // cihazlarda alt alta kırılıyordu; ölçek makul aralıkta tutulur.
            return MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.1,
              child: ProjectDetailsBottomSheet(
                project: project,
                invite: invite,
              ),
            );
          },
        );
      },
    );
  }

  @override
  State<ProjectDetailsBottomSheet> createState() => _ProjectDetailsBottomSheetState();
}

class _ProjectDetailsBottomSheetState extends State<ProjectDetailsBottomSheet> {
  /// Açılışta Firestore'dan tazelenen proje — liste/bildirimdeki eski kopya
  /// yerine güncel veriyi (ör. sonradan atanan Proje Sorumlusu) gösterir.
  ProjectModel? _freshProject;
  ProjectModel get project => _freshProject ?? widget.project;

  Future<void> _refreshProject() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .get();
      if (!doc.exists || doc.data() == null || !mounted) return;
      setState(() => _freshProject = ProjectModel.fromMap(doc.data()!, doc.id));
    } catch (e) {
      debugPrint('⚠️ [ProjectDetailsBottomSheet] Proje tazelenemedi: $e');
    }
  }
  NotificationModel? get invite => widget.invite;

  // Arka plan sesi önizleme
  AudioPlayer? _previewPlayer;
  bool _isAudioPlaying = false;
  bool _isAudioLoading = false;

  /// Bu oyuncuya bu projede gönderilmiş audition talepleri (rol adı → davet).
  /// Birden fazla karakterli projelerde oyuncu yalnızca KENDİ karakterini ve
  /// o karaktere ait senaryoyu görür.
  final Map<String, NotificationModel> _invitesByRole = {};
  bool _hasRoleLessInvite = false;

  @override
  void initState() {
    super.initState();
    _refreshProject();
    _collectInvites();
  }

  void _addInvite(NotificationModel n) {
    final roleName = (n.data?['roleName'] as String?)?.trim();
    if (roleName == null || roleName.isEmpty) {
      _hasRoleLessInvite = true;
      return;
    }
    final existing = _invitesByRole[roleName];
    // Aynı rol için birden fazla davet varsa en yenisi geçerli
    if (existing == null || n.createdAt.isAfter(existing.createdAt)) {
      _invitesByRole[roleName] = n;
    }
  }

  Future<void> _collectInvites() async {
    if (invite != null) _addInvite(invite!);

    try {
      final notifs = context.read<NotificationProvider>().notifications;
      for (final n in notifs) {
        if (n.type == NotificationType.castingInvite && n.projectId == project.id) {
          _addInvite(n);
        }
      }
    } catch (_) {}

    // Bildirim listesi sınırlı olabilir; Firestore'dan da kontrol et
    try {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: uid)
            .where('projectId', isEqualTo: project.id)
            .where('type', isEqualTo: NotificationType.castingInvite.value)
            .get();
        for (final doc in snap.docs) {
          try {
            _addInvite(NotificationModel.fromMap(doc.data(), doc.id));
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ProjectDetailsBottomSheet] Davetler okunamadı: $e');
    }
    if (mounted) setState(() {});
  }

  /// Oyuncunun görebileceği roller: davet edildiği karakterler.
  /// Rol bilgisi olmayan eski davetlerde veya davet yoksa tüm roller.
  List<ProjectRole> get _myRoles {
    if (_invitesByRole.isEmpty) return project.roles;
    final mine = project.roles
        .where((r) => _invitesByRole.containsKey(r.roleName.trim()))
        .toList();
    if (mine.isEmpty) return project.roles;
    if (_hasRoleLessInvite) return project.roles;
    return mine;
  }

  /// Rol için gösterilecek/çekilecek senaryo: önce o role ait davetteki
  /// özel metin, yoksa rolün kendi audition metni.
  String? _scriptForRole(ProjectRole role) {
    final inviteScript =
        (_invitesByRole[role.roleName.trim()]?.data?['auditionScript'] as String?)?.trim();
    if (inviteScript != null && inviteScript.isNotEmpty) return inviteScript;
    final roleScript = role.auditionScript?.trim();
    return (roleScript == null || roleScript.isEmpty) ? null : roleScript;
  }

  bool _budgetFlexibleForRole(ProjectRole role) =>
      _invitesByRole[role.roleName.trim()]?.data?['budgetFlexible'] as bool? ??
      (invite?.data?['budgetFlexible'] as bool? ?? false);

  String? get _budgetText {
    final roles = _myRoles;
    if (roles.length == 1 && roles.first.budget != null && roles.first.budget! > 0) {
      return ProjectModel.formatTl(roles.first.budget!);
    }
    return project.budgetLabel;
  }

  @override
  void dispose() {
    _previewPlayer?.stop();
    _previewPlayer?.dispose();
    super.dispose();
  }

  /// Prompter metnini dialog olarak göster
  void _showPrompterDialog(BuildContext context, String script) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx2, scrollCtrl) {
            return Column(
              children: [
                // Tutamaç
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.article_rounded, color: AppTheme.accent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Prompter Metni',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      script,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        color: Colors.white,
                        height: 1.9,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Arka plan sesini önizle / durdur
  Future<void> _toggleAudioPreview(String audioUrl) async {
    if (_isAudioLoading) return;

    if (_isAudioPlaying) {
      await _previewPlayer?.pause();
      setState(() => _isAudioPlaying = false);
      return;
    }

    setState(() => _isAudioLoading = true);
    try {
      _previewPlayer ??= AudioPlayer();
      await _previewPlayer!.setUrl(audioUrl);
      await _previewPlayer!.play();
      _previewPlayer!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _isAudioPlaying = false);
        }
      });
      if (mounted) setState(() => _isAudioPlaying = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ses yüklenemedi: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAudioLoading = false);
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String phone, String projectTitle) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '90${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 10) {
      cleanPhone = '90$cleanPhone';
    }
    final message = Uri.encodeComponent("Merhaba, $projectTitle projesi için görüşmek istiyorum.");
    final url = Uri.parse("https://wa.me/$cleanPhone?text=$message");
    try {
      bool launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched) {
        launched = await launchUrl(url, mode: LaunchMode.platformDefault);
      }
      if (!launched) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp başlatılamadı. Uygulamanın yüklü olduğundan emin olun.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      try {
        final launched = await launchUrl(url, mode: LaunchMode.platformDefault);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('WhatsApp başlatılamadı.'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      } catch (err) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bağlantı açılamadı: $err'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    }
  }

  String _getRemainingDaysText() {
    if (project.deadline == null) return 'Başvuru tarihi belirtilmedi';
    final now = DateTime.now();
    final diff = project.deadline!.difference(now).inDays + 1;
    if (diff > 0) {
      return 'Sende Castelle için son $diff gün';
    } else if (diff == 0) {
      return 'Sende Castelle için son gün!';
    } else {
      return 'Başvuru süresi doldu';
    }
  }

  void _onSendeCastellePressed(BuildContext context) {
    final roles = _myRoles;
    if (roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu projede başvurulacak rol bulunmuyor.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (roles.length == 1) {
      final navigator = Navigator.of(context);
      final role = roles.first;
      navigator.pop(); // Close details sheet
      _openSubmitForRoleWith(navigator, role);
    } else {
      // Birden fazla karaktere davet edilmişse hangisi için çekileceğini seç
      _showRolePicker(context, roles);
    }
  }

  void _openSubmitForRoleWith(NavigatorState navigator, ProjectRole role) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => AuditionSubmitScreen(
          project: project,
          role: role,
          customScript: _scriptForRole(role),
          budgetFlexible: _budgetFlexibleForRole(role),
        ),
      ),
    );
  }

  void _showRolePicker(BuildContext context, List<ProjectRole> roles) {
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hangi karakter için çekim yapacaksınız?',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: roles.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (c, idx) {
                    final role = roles[idx];
                    return ListTile(
                      title: Text(
                        role.roleName,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: role.description != null ? Text(role.description!) : null,
                      trailing: const Icon(Icons.chevron_right, color: AppTheme.accent),
                      onTap: () {
                        Navigator.pop(ctx); // Close picker
                        navigator.pop(); // Close details sheet
                        _openSubmitForRoleWith(navigator, role);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyRow(String label, Widget valueWidget) {
    // Etiket sütunu sabit 140px idi; dar ekranlı telefonlarda değer sütunu
    // daralıp yazılar alt alta kırılıyordu. Artık genişliğe oranlı.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final labelWidth = (constraints.maxWidth * 0.34).clamp(96.0, 128.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextPropertyRow(String label, String value, {Color? valueColor, bool isBold = true}) {
    return _buildPropertyRow(
      label,
      Text(
        value,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          color: valueColor ?? AppTheme.textPrimary,
        ),
      ),
    );
  }

  /// Prompter Metni / Arka Plan Sesi için yeşil-gri gösterge chip'i (tıklanabilir)
  Widget _buildMediaChip({
    required String label,
    required IconData icon,
    required bool active,
    VoidCallback? onTap,
  }) {
    final color = active ? const Color(0xFF2E7D32) : AppTheme.textTertiary;
    final bgColor = active
        ? const Color(0xFF2E7D32).withValues(alpha: 0.1)
        : AppTheme.surfaceElevated;
    final borderColor = active
        ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
        : AppTheme.border.withValues(alpha: 0.5);

    return Expanded(
      child: GestureDetector(
        onTap: active ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                active ? Icons.touch_app_rounded : Icons.cancel_rounded,
                size: 12,
                color: color.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCoordinatorPhone = project.coordinatorPhone != null && project.coordinatorPhone!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      child: Column(
        children: [
          // 1. ÜST BAR (PROJE DETAYI başlığı ve WhatsApp / Kapat butonları)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'PROJE DETAYI',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                hasCoordinatorPhone
                    ? IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        tooltip: 'Casting Sorumlusu ile Görüş',
                        onPressed: () => _launchWhatsApp(context, project.coordinatorPhone!, project.title),
                      )
                    : const SizedBox(width: 48),
              ],
            ),
          ),

          // 2. KAYDIRILABİLİR İÇERİK
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // A. PROJE ÖNİZLEME GRUBU (Logo + Metinler)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sol: Birincil Fotoğraf
                      Container(
                        width: 85,
                        height: 85,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.border.withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: project.primaryImageUrl != null && project.primaryImageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: project.primaryImageUrl!,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Image.asset(
                                    'assets/images/ana-logo-siyah.png',
                                    fit: BoxFit.contain,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/ana-logo-siyah.png',
                                  fit: BoxFit.contain,
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Sağ: Başlık, Tür, Rol Önizleme, Süre, Tarih
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              project.projectTypeLabel,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _myRoles.isNotEmpty
                                  ? _myRoles.map((r) => r.roleName).join(', ')
                                  : 'Belirtilmedi',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textTertiary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined, size: 13, color: AppTheme.accent),
                                const SizedBox(width: 4),
                                Text(
                                  _getRemainingDaysText(),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textTertiary),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd.MM.yyyy').format(project.createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // B. PORTAKAL AKSİYON BUTONU (Sende Castelle)
                  Builder(
                    builder: (context) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      bool isDeadlinePassed = false;
                      if (project.deadline != null) {
                        final deadlineDate = DateTime(project.deadline!.year, project.deadline!.month, project.deadline!.day);
                        isDeadlinePassed = deadlineDate.isBefore(today);
                      }

                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isDeadlinePassed ? null : () => _onSendeCastellePressed(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDeadlinePassed ? AppTheme.surfaceElevated : AppTheme.accent,
                            foregroundColor: isDeadlinePassed ? AppTheme.textTertiary : AppTheme.textOnAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            isDeadlinePassed ? 'Başvuru Süresi Doldu' : 'Sende Castelle',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // B2. PROJE SORUMLUSU (belirgin kart)
                  if (project.coordinatorName?.trim().isNotEmpty ?? false) ...[
                    _buildCoordinatorCard(context),
                    const SizedBox(height: 16),
                  ],

                  // B3. KARAKTER KARTLARI (sadece oyuncunun kendi karakterleri)
                  ..._myRoles.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildMyRoleCard(context, r),
                      )),

                  const SizedBox(height: 8),

                  // C. DETAYLAR GRUBU (Tablo)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Detaylar dropdown başlığı
                        Row(
                          children: [
                            Text(
                              'Detaylar',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                          ],
                        ),
                        const Divider(height: 12),
                        _buildTextPropertyRow('Çekim Tarihi', project.shootDate ?? 'Belirtilmedi'),
                        _buildTextPropertyRow(
                            'Çekim Yeri / Süre',
                            '${project.location ?? 'Belirtilmedi'} / ${project.shootDuration ?? 'Belirtilmedi'}'),
                        _buildTextPropertyRow('Mecra', project.media ?? 'Belirtilmedi'),
                        
                        // Bütçe Satırı
                        // Tutar hiçbir cihazda ortadan bölünmez (softWrap:
                        // false). "Yüksek Bütçe Bildir" yanına sığmazsa
                        // bütün hâlinde alt satıra geçer.
                        _buildPropertyRow(
                          'Bütçe',
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _budgetText ?? 'Belirtilmedi',
                                  softWrap: false,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _budgetText != null
                                        ? AppTheme.success
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (_budgetText != null) ...[
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Yüksek bütçeli proje bildirildi.'),
                                        backgroundColor: AppTheme.success,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Yüksek Bütçe Bildir',
                                    softWrap: false,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Peşin Ödeme Satırı
                        _buildPropertyRow(
                          'Peşin Ödeme',
                          Row(
                            children: [
                              Text(
                                project.cashPayment ? 'Aktif' : 'Pasif',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: project.cashPayment ? AppTheme.success : AppTheme.textSecondary,
                                ),
                              ),
                              if (project.cashPayment) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.monetization_on, size: 14, color: AppTheme.success),
                              ],
                            ],
                          ),
                        ),

                        _buildTextPropertyRow(
                            _myRoles.length < project.roles.length ? 'Karakteriniz' : 'Roller',
                            _myRoles.isNotEmpty
                                ? _myRoles.map((r) => r.roleName).join(', ')
                                : 'Belirtilmedi'),

                        // ── Prompter Metni & Arka Plan Sesi İndikatörleri ──
                        Builder(
                          builder: (context) {
                            // Yalnızca oyuncunun kendi karakter(ler)ine ait senaryo
                            final myRoles = _myRoles;
                            final scriptText = myRoles.length == 1
                                ? (_scriptForRole(myRoles.first) ?? '')
                                : myRoles
                                    .where((r) => _scriptForRole(r) != null)
                                    .map((r) => '【${r.roleName}】\n${_scriptForRole(r)}')
                                    .join('\n\n---\n\n');
                            final audioUrl = myRoles
                                .where((r) => r.backgroundAudioUrl != null && r.backgroundAudioUrl!.trim().isNotEmpty)
                                .map((r) => r.backgroundAudioUrl!)
                                .firstOrNull;

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  _buildMediaChip(
                                    label: 'Prompter Metni',
                                    icon: Icons.article_outlined,
                                    active: scriptText.isNotEmpty,
                                    onTap: scriptText.isNotEmpty
                                        ? () => _showPrompterDialog(context, scriptText)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildMediaChip(
                                    label: _isAudioLoading
                                        ? 'Yükleniyor...'
                                        : _isAudioPlaying
                                            ? 'Sesi Durdur ■'
                                            : 'Arka Plan Sesi',
                                    icon: _isAudioLoading
                                        ? Icons.hourglass_top_rounded
                                        : _isAudioPlaying
                                            ? Icons.stop_circle_outlined
                                            : Icons.music_note_outlined,
                                    active: audioUrl != null,
                                    onTap: audioUrl != null
                                        ? () => _toggleAudioPreview(audioUrl)
                                        : null,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        _buildPropertyRow(
                          'Proje Sorumlusu',
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (project.coordinatorName?.trim().isNotEmpty ?? false)
                                      ? project.coordinatorName!
                                      : 'Atanmadı',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: (project.coordinatorName?.trim().isNotEmpty ?? false)
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontStyle: (project.coordinatorName?.trim().isNotEmpty ?? false)
                                        ? FontStyle.normal
                                        : FontStyle.italic,
                                    color: (project.coordinatorName?.trim().isNotEmpty ?? false)
                                        ? AppTheme.textPrimary
                                        : AppTheme.textTertiary,
                                  ),
                                ),
                              ),
                              if (hasCoordinatorPhone) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _launchWhatsApp(context, project.coordinatorPhone!, project.title),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                      border: Border.all(
                                        color: Colors.green.withValues(alpha: 0.3),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.chat,
                                          size: 12,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'İletişime Geç',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // D. PROJE AÇIKLAMASI
                  Text(
                    'Proje Açıklaması',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description ?? 'Açıklama bulunmuyor.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),

                  // E. SENARYO / METİN
                  if (project.scenario != null && project.scenario!.trim().isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Senaryo / Metin',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: AppTheme.border.withValues(alpha: 0.15)),
                      ),
                      child: RichTextRenderer(
                        text: project.scenario!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],

                  // F. GALERİ (CAROUSEL)
                  if (project.galleryImageUrls.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Proje Galerisi',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImageGalleryCarousel(context, project.galleryImageUrls),
                  ],

                  // G. ÖRNEK VİDEO (VIDEO PLAYER)
                  if (project.sampleVideoUrl != null && project.sampleVideoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Örnek / Tanıtım Videosu',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    AppVideoPlayer(videoUrl: project.sampleVideoUrl!, title: 'Örnek Video'),
                  ],

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorCard(BuildContext context) {
    final hasPhone = project.coordinatorPhone?.trim().isNotEmpty ?? false;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Proje Sorumlusu',
                  style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                ),
                const SizedBox(height: 2),
                Text(
                  project.coordinatorName!,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (hasPhone)
                  Text(
                    project.coordinatorPhone!,
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          if (hasPhone)
            IconButton(
              tooltip: 'WhatsApp ile yaz',
              onPressed: () => _launchWhatsApp(context, project.coordinatorPhone!, project.title),
              icon: const Icon(Icons.chat, color: Colors.green),
            ),
        ],
      ),
    );
  }

  Widget _buildMyRoleCard(BuildContext context, ProjectRole role) {
    final script = _scriptForRole(role);
    final isInvited = _invitesByRole.containsKey(role.roleName.trim());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isInvited
              ? AppTheme.accent.withValues(alpha: 0.35)
              : AppTheme.border.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.theater_comedy_outlined, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  role.roleName,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isInvited)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    'Sizin karakteriniz',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                ),
            ],
          ),
          if (role.description?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              role.description!,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (role.criteriaSummary.isNotEmpty)
                _roleChip(Icons.person_outline, role.criteriaSummary),
              if (role.budget != null && role.budget! > 0)
                _roleChip(
                  Icons.payments_outlined,
                  'Bütçe: ${ProjectModel.formatTl(role.budget!)}',
                  color: AppTheme.success,
                ),
            ],
          ),
          if (role.auditionNotes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              '🎬 ${role.auditionNotes!}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
          ],
          if (script != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _showPrompterDialog(context, script),
              icon: const Icon(Icons.article_outlined, size: 16),
              label: const Text('Bu Karakterin Senaryosu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _roleChip(IconData icon, String text, {Color? color}) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: c),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGalleryCarousel(BuildContext context, List<String> urls) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: urls[index],
              height: 150,
              width: 220,
              // Logo / yatay görseller kırpılmasın (ör. "VakıfBank" →
              // yalnızca "Vakıf" görünüyordu).
              fit: BoxFit.contain,
              imageBuilder: (context, provider) => Container(
                width: 220,
                height: 150,
                color: Colors.white,
                padding: const EdgeInsets.all(6),
                child: Image(image: provider, fit: BoxFit.contain),
              ),
              placeholder: (context, url) => Container(
                width: 220,
                color: AppTheme.surfaceLight,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
              ),
              errorWidget: (context, url, error) => Container(
                width: 220,
                color: AppTheme.surfaceLight,
                child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.textTertiary),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Basit Markdown RichText Renderer
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
            style: style.copyWith(color: AppTheme.textSecondary),
            children: spans,
          ),
        );

        if (isBullet) {
          lineWidget = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: style.copyWith(fontWeight: FontWeight.bold)),
              Expanded(child: lineWidget),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: lineWidget,
        );
      }).toList(),
    );
  }
}

