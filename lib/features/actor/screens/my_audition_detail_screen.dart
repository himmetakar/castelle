import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/models/project_model.dart';
import 'package:castelle/core/services/project_service.dart';
import 'package:castelle/core/widgets/app_video_player.dart';
import 'package:castelle/features/actor/screens/audition_submit_screen.dart';

/// Castelle - Oyuncunun Kendi Audition Detayı
/// "Başvurularım" listesinden bir audition'a tıklandığında açılır.
/// Salt okunur: video oynatma ve gönderim bilgileri gösterilir,
/// yönetmen/admin onay-ret gibi işlemler burada YOK.
class MyAuditionDetailScreen extends StatefulWidget {
  final AuditionModel audition;

  const MyAuditionDetailScreen({
    super.key,
    required this.audition,
  });

  @override
  State<MyAuditionDetailScreen> createState() =>
      _MyAuditionDetailScreenState();
}

class _MyAuditionDetailScreenState extends State<MyAuditionDetailScreen> {
  ProjectModel? _project;
  bool _loadingProject = true;

  @override
  void initState() {
    super.initState();
    _loadProject();
  }

  Future<void> _loadProject() async {
    try {
      final p = await ProjectService().getProject(widget.audition.projectId);
      if (mounted) setState(() => _project = p);
    } catch (_) {}
    if (mounted) setState(() => _loadingProject = false);
  }

  ProjectRole? get _role {
    final p = _project;
    if (p == null) return null;
    for (final r in p.roles) {
      if (r.roleName.trim() == widget.audition.roleName.trim()) return r;
    }
    return null;
  }

  Future<void> _openRevisionUpload() async {
    final project = _project ?? await ProjectService().getProject(widget.audition.projectId);
    if (!mounted) return;
    if (project == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proje bulunamadı.'), backgroundColor: AppTheme.error),
      );
      return;
    }
    final role = _role ?? ProjectRole(roleName: widget.audition.roleName);

    // Bu karaktere gönderilmiş davetteki özel senaryo varsa onu kullan
    String? script;
    bool budgetFlexible = false;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('recipientId', isEqualTo: widget.audition.actorId)
          .where('projectId', isEqualTo: widget.audition.projectId)
          .where('type', isEqualTo: 'casting_invite')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data()['data'] as Map<String, dynamic>?;
        if ((data?['roleName'] as String?)?.trim() == widget.audition.roleName.trim()) {
          script = data?['auditionScript'] as String?;
          budgetFlexible = data?['budgetFlexible'] as bool? ?? false;
        }
      }
    } catch (_) {}
    script = (script != null && script.trim().isNotEmpty)
        ? script
        : (widget.audition.scriptUsed ?? role.auditionScript);

    if (!mounted) return;
    final sent = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AuditionSubmitScreen(
          project: project,
          role: role,
          customScript: script,
          budgetFlexible: budgetFlexible,
          revisionOf: widget.audition,
        ),
      ),
    );
    if (sent == true && mounted) Navigator.pop(context);
  }

  Color _statusColor(AuditionStatus status) {
    return switch (status) {
      AuditionStatus.uploading => AppTheme.textTertiary,
      AuditionStatus.submitted => AppTheme.warning,
      AuditionStatus.reviewing => AppTheme.info,
      AuditionStatus.options => AppTheme.accent,
      AuditionStatus.approved => AppTheme.success,
      AuditionStatus.rejected => AppTheme.error,
      AuditionStatus.revision => AppTheme.accent,
    };
  }

  Widget _buildStatusChip(AuditionModel audition) {
    final group = audition.status.displayGroup;
    final label = group.displayName;
    final color = _statusColor(group);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMiniInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    final url = widget.audition.videoUrl;
    if (url.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Text(
          'Bu başvurunun videosu artık saklanmıyor.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
      );
    }
    return AppVideoPlayer(
      key: ValueKey(url),
      videoUrl: url,
      autoInit: true,
      maxHeight: 480,
    );
  }

  Widget _buildRevisionCard(AuditionModel audition) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.replay_circle_filled_outlined, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Revize İstendi · ${audition.projectTitle}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (audition.reviewerNote?.trim().isNotEmpty ?? false)
                ? '“${audition.reviewerNote!.trim()}”'
                : 'Videonuzu tekrar çekmeniz istendi.',
            style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, height: 1.45),
          ),
          if (audition.reviewerName?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              '— ${audition.reviewerName}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _openRevisionUpload,
              icon: const Icon(Icons.videocam_outlined),
              label: Text(
                'Yeni Videoyu Çek / Yükle',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectInfoCard() {
    if (_loadingProject) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }
    final p = _project;
    if (p == null) return const SizedBox.shrink();
    final role = _role;
    final budget = role?.budget != null && role!.budget! > 0
        ? ProjectModel.formatTl(role.budget!)
        : p.budgetLabel;
    final hasCoordinator = p.coordinatorName?.trim().isNotEmpty ?? false;

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: AppTheme.textTertiary),
              const SizedBox(width: 8),
              SizedBox(
                width: 104,
                child: Text(label,
                    style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textTertiary)),
              ),
              Expanded(
                child: Text(value,
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Proje Bilgileri',
            style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          row(Icons.theater_comedy_outlined, 'Karakter', widget.audition.roleName),
          row(Icons.payments_outlined, 'Bütçe', budget ?? 'Belirtilmedi'),
          row(Icons.support_agent, 'Proje Sorumlusu',
              hasCoordinator ? p.coordinatorName! : 'Atanmadı'),
          if (p.coordinatorPhone?.trim().isNotEmpty ?? false)
            row(Icons.phone_outlined, 'Telefon', p.coordinatorPhone!),
          if (p.shootDate?.trim().isNotEmpty ?? false)
            row(Icons.event_outlined, 'Çekim Tarihi', p.shootDate!),
        ],
      ),
    );
  }

  Widget _buildOptionResponseDetails(AuditionModel audition) {
    String formatDateOnly(DateTime date) =>
        '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

    final startStr =
        audition.optionStartDate != null ? formatDateOnly(audition.optionStartDate!) : '';
    final endStr =
        audition.optionEndDate != null ? formatDateOnly(audition.optionEndDate!) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 16, color: AppTheme.accent),
              const SizedBox(width: 6),
              Text(
                'Opsiyon Yanıtı İletildi',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Çekim Tarihleri: $startStr - $endStr',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Müsaitlik: ${audition.optionAvailable == true ? "Evet (Müsaitim)" : "Hayır (Müsait değilim)"}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: audition.optionAvailable == true ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (audition.optionAvailable == false && audition.optionExplanation != null) ...[
            const SizedBox(height: 4),
            Text(
              'Açıklama: ${audition.optionExplanation}',
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
          if (audition.optionQuestions != null && audition.optionQuestions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Text(
              'Sorular ve Cevaplarınız:',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            for (final q in audition.optionQuestions!) ...[
              Text(
                'S: $q',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
              Text(
                'C: ${audition.optionAnswers?[q] ?? "Yanıtlanmadı"}',
                style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
        ' ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final audition = widget.audition;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          audition.projectTitle.isNotEmpty ? audition.projectTitle : 'Audition Detayı',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (audition.status == AuditionStatus.revision) ...[
              _buildRevisionCard(audition),
              const SizedBox(height: 16),
            ],
            _buildVideoPlayer(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceCard,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              audition.projectTitle,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              audition.roleName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusChip(audition),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildMiniInfo(Icons.timer, audition.formattedDuration),
                      _buildMiniInfo(Icons.sd_storage, audition.formattedSize),
                      if (audition.requestedBudget != null)
                        _buildMiniInfo(
                          Icons.attach_money,
                          '${audition.requestedBudget!.toStringAsFixed(0)} ₺',
                        ),
                    ],
                  ),
                  if (audition.note != null && audition.note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'Notunuz',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      audition.note!,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                  if (audition.reviewerNote != null && audition.reviewerNote!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusColor(audition.status).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: _statusColor(audition.status).withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.feedback_outlined, size: 14, color: _statusColor(audition.status)),
                              const SizedBox(width: 6),
                              Text(
                                'Geri Bildirim${audition.reviewerName != null ? " — ${audition.reviewerName}" : ""}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _statusColor(audition.status),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            audition.reviewerNote!,
                            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (audition.status == AuditionStatus.options &&
                      audition.optionAvailable != null)
                    _buildOptionResponseDetails(audition),
                  if (audition.revisionCount > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Bu başvuru ${audition.revisionCount} kez revize edildi.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textTertiary),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Gönderim: ${_formatDate(audition.createdAt)}',
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildProjectInfoCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
