import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/models/notification_model.dart';
import 'package:castelle/features/actor/screens/audition_submit_screen.dart';
import 'package:video_player/video_player.dart';

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
            return ProjectDetailsBottomSheet(
              project: project,
              invite: invite,
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
  ProjectModel get project => widget.project;
  NotificationModel? get invite => widget.invite;

  // Arka plan sesi önizleme
  AudioPlayer? _previewPlayer;
  bool _isAudioPlaying = false;
  bool _isAudioLoading = false;

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
    if (project.roles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu projede başvurulacak rol bulunmuyor.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    if (project.roles.length == 1) {
      Navigator.pop(context); // Close details sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AuditionSubmitScreen(
            project: project,
            role: project.roles.first,
            customScript: invite?.data?['auditionScript'],
            budgetFlexible: invite?.data?['budgetFlexible'] as bool? ?? false,
          ),
        ),
      );
    } else {
      // Show role picker bottom sheet
      _showRolePicker(context);
    }
  }

  void _showRolePicker(BuildContext context) {
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
                'Başvurmak İstediğiniz Rolü Seçin',
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
                  itemCount: project.roles.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (c, idx) {
                    final role = project.roles[idx];
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
                        Navigator.pop(context); // Close details sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AuditionSubmitScreen(
                              project: project,
                              role: role,
                              customScript: invite?.data?['auditionScript'],
                              budgetFlexible: invite?.data?['budgetFlexible'] as bool? ?? false,
                            ),
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
      },
    );
  }

  Widget _buildPropertyRow(String label, Widget valueWidget) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(child: valueWidget),
        ],
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
                              project.roles.isNotEmpty
                                  ? project.roles.map((r) => r.roleName).join(', ')
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

                  const SizedBox(height: 20),

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
                        _buildPropertyRow(
                          'Bütçe',
                          Row(
                            children: [
                              Text(
                                project.budget != null && project.budget! > 0
                                    ? '${project.budget!.toStringAsFixed(0)} TL'
                                    : 'Belirtilmedi',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (project.budget != null && project.budget! > 0) ...[
                                const SizedBox(width: 8),
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
                            'Rol Durumu',
                            project.roles.isNotEmpty
                                ? project.roles.map((r) => r.roleName).join(', ')
                                : 'Belirtilmedi'),

                        // ── Prompter Metni & Arka Plan Sesi İndikatörleri ──
                        Builder(
                          builder: (context) {
                            final scriptText = project.roles
                                .where((r) => r.auditionScript != null && r.auditionScript!.trim().isNotEmpty)
                                .map((r) => r.auditionScript!)
                                .join('\n\n---\n\n');
                            final audioUrl = project.roles
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
                                  project.coordinatorName ?? 'Belirtilmedi',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
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
                    _ProjectSampleVideoPlayer(videoUrl: project.sampleVideoUrl!),
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

  Widget _buildImageGalleryCarousel(BuildContext context, List<String> urls) {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: urls[index],
              height: 150,
              width: 220,
              fit: BoxFit.cover,
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
          if (trimmed.startsWith('- ')) cleanLine = trimmed.substring(2);
          else if (trimmed.startsWith('• ')) cleanLine = trimmed.substring(2);
          else if (trimmed.startsWith('* ')) cleanLine = trimmed.substring(2);
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

/// Proje Örnek Video Oynatıcısı
class _ProjectSampleVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const _ProjectSampleVideoPlayer({required this.videoUrl});

  @override
  State<_ProjectSampleVideoPlayer> createState() => _ProjectSampleVideoPlayerState();
}

class _ProjectSampleVideoPlayerState extends State<_ProjectSampleVideoPlayer> {
  late VideoPlayerController _videoController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoController.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing sample video player: $e');
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      _videoController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController.value.aspectRatio,
            child: VideoPlayer(_videoController),
          ),
          IconButton(
            iconSize: 48,
            icon: Icon(
              _videoController.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
              color: Colors.white.withValues(alpha: 0.8),
            ),
            onPressed: () {
              setState(() {
                _videoController.value.isPlaying ? _videoController.pause() : _videoController.play();
              });
            },
          ),
        ],
      ),
    );
  }
}
