import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/features/director/screens/audition_review_screen.dart';

/// Castelle — Oyuncu Geçmişi (Panel)
///
/// Bir oyuncunun sisteme katıldığı tarihten bugüne tüm proje ve oyun
/// geçmişini tek ekranda gösterir:
/// * Sisteme katılım tarihi
/// * Kaç proje için oyun çektiği / toplam kaç video gönderdiği
/// * Hangi markalara (projelere) oyun gönderdiği
/// * Hangi markalardan opsiyon aldığı, hangilerinde onaylandığı,
///   reddedildiği, revizyona girdiği
/// * Her başvurunun tarihli durum geçmişi
///
/// Panelden silinen başvurular da (Silinenler) burada görünmeye devam eder;
/// hiçbir kayıt geçmişten kaybolmaz.
class ActorHistoryScreen extends StatefulWidget {
  final String actorId;
  final String actorName;

  const ActorHistoryScreen({
    super.key,
    required this.actorId,
    required this.actorName,
  });

  @override
  State<ActorHistoryScreen> createState() => _ActorHistoryScreenState();
}

class _ActorHistoryScreenState extends State<ActorHistoryScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  DateTime? _joinedAt;
  List<AuditionModel> _auditions = [];
  int _inviteCount = 0;
  final Map<String, String> _brandByProject = {}; // projectId → marka/proje adı

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime? _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userDoc = await _db.collection('users').doc(widget.actorId).get();
      _joinedAt = _parseDate(userDoc.data()?['createdAt']);

      final audSnap = await _db
          .collection('auditions')
          .where('actorId', isEqualTo: widget.actorId)
          .get();
      final list = audSnap.docs
          .map((d) => AuditionModel.fromMap(d.data(), d.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      try {
        final inviteSnap = await _db
            .collection('notifications')
            .where('recipientId', isEqualTo: widget.actorId)
            .where('type', isEqualTo: 'casting_invite')
            .get();
        _inviteCount = inviteSnap.docs.length;
      } catch (_) {}

      // Marka adları: proje başlığı (+ işveren adı). Silinmiş projelerde
      // başvurudaki proje adı kullanılır.
      final projectIds = list.map((a) => a.projectId).where((id) => id.isNotEmpty).toSet().toList();
      for (var i = 0; i < projectIds.length; i += 10) {
        final chunk = projectIds.sublist(i, i + 10 > projectIds.length ? projectIds.length : i + 10);
        try {
          final pSnap = await _db
              .collection('projects')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final p in pSnap.docs) {
            final title = (p.data()['title'] as String?)?.trim();
            if (title != null && title.isNotEmpty) _brandByProject[p.id] = title;
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _auditions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Geçmiş yüklenemedi: $e';
      });
    }
  }

  String _brand(AuditionModel a) =>
      _brandByProject[a.projectId] ?? (a.projectTitle.isNotEmpty ? a.projectTitle : 'Bilinmeyen Proje');

  /// Başvuru herhangi bir anda bu durumdan geçti mi? (tarihçe + güncel durum)
  bool _everHad(AuditionModel a, AuditionStatus status) {
    if (a.status == status) return true;
    if (status == AuditionStatus.revision && a.revisionCount > 0) return true;
    return a.statusHistory.any((h) => h['status'] == status.value);
  }

  Set<String> _brandsWhere(bool Function(AuditionModel a) test) =>
      _auditions.where(test).map(_brand).toSet();

  String _fmt(DateTime? d, {bool withTime = false}) {
    if (d == null) return '—';
    final date = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    if (!withTime) return date;
    return '$date ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _historyLabel(String status) => switch (status) {
        'deleted' => 'Panelden silindi',
        'restored' => 'Geri yüklendi',
        _ => AuditionStatus.fromString(status).displayName,
      };

  Color _statusColor(AuditionStatus s) => switch (s.displayGroup) {
        AuditionStatus.options => Colors.purple,
        AuditionStatus.approved => AppTheme.success,
        AuditionStatus.rejected => AppTheme.error,
        AuditionStatus.revision => AppTheme.warning,
        _ => AppTheme.info,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          '${widget.actorName} · Geçmiş',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.accent,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildSummary(),
                      const SizedBox(height: 16),
                      _buildBrandSection(
                        'Oyun Gönderdiği Markalar',
                        Icons.send_outlined,
                        AppTheme.info,
                        _brandsWhere((_) => true),
                      ),
                      _buildBrandSection(
                        'Opsiyon Aldığı Markalar',
                        Icons.star_outline,
                        Colors.purple,
                        _brandsWhere((a) => _everHad(a, AuditionStatus.options)),
                      ),
                      _buildBrandSection(
                        'Onaylandığı Projeler',
                        Icons.check_circle_outline,
                        AppTheme.success,
                        _brandsWhere((a) => _everHad(a, AuditionStatus.approved)),
                      ),
                      _buildBrandSection(
                        'Reddedildiği Projeler',
                        Icons.cancel_outlined,
                        AppTheme.error,
                        _brandsWhere((a) => _everHad(a, AuditionStatus.rejected)),
                      ),
                      _buildBrandSection(
                        'Revizyona Girdiği Projeler',
                        Icons.replay,
                        AppTheme.warning,
                        _brandsWhere((a) => _everHad(a, AuditionStatus.revision)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tüm Başvurular (${_auditions.length})',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_auditions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Henüz başvuru yok.',
                              style: GoogleFonts.inter(color: AppTheme.textTertiary),
                            ),
                          ),
                        )
                      else
                        ..._auditions.map(_buildAuditionTile),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSummary() {
    final projects = _auditions.map((a) => a.projectId).toSet().length;
    final totalVideos = _auditions.fold<int>(
        0, (sum, a) => sum + 1 + a.previousVersions.length);
    int count(AuditionStatus s) => _auditions.where((a) => _everHad(a, s)).length;

    Widget stat(String label, String value, Color color) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: color),
              ),
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        );

    return Container(
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
              const Icon(Icons.event_available, size: 18, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                'Sisteme katılım: ${_fmt(_joinedAt)}',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              stat('Proje (oyun çekilen)', '$projects', AppTheme.info),
              stat('Gönderilen video', '$totalVideos', AppTheme.textSecondary),
              stat('Gelen teklif', '$_inviteCount', AppTheme.accent),
              stat('Opsiyon', '${count(AuditionStatus.options)}', Colors.purple),
              stat('Onay', '${count(AuditionStatus.approved)}', AppTheme.success),
              stat('Red', '${count(AuditionStatus.rejected)}', AppTheme.error),
              stat('Revizyon', '${count(AuditionStatus.revision)}', AppTheme.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandSection(String title, IconData icon, Color color, Set<String> brands) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '$title (${brands.length})',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (brands.isEmpty)
            Text('—', style: GoogleFonts.inter(color: AppTheme.textTertiary))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: brands
                  .map((b) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          b,
                          style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w600),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildAuditionTile(AuditionModel a) {
    final color = _statusColor(a.status);
    final history = [...a.statusHistory]
      ..sort((x, y) {
        final dx = _parseDate(x['at']) ?? DateTime(2000);
        final dy = _parseDate(y['at']) ?? DateTime(2000);
        return dx.compareTo(dy);
      });

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            _brand(a),
            style: GoogleFonts.outfit(fontSize: 14.5, fontWeight: FontWeight.w600),
          ),
          subtitle: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${a.roleName} · ${_fmt(a.createdAt)}',
                style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textTertiary),
              ),
              _tag(a.status.displayName, color),
              if (a.isDeleted) _tag('Panelden silindi', AppTheme.textTertiary),
              if (a.projectDeleted) _tag('Proje silindi', AppTheme.textTertiary),
            ],
          ),
          children: [
            if (history.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Gönderildi: ${_fmt(a.createdAt, withTime: true)}'
                  '${a.reviewedAt != null ? '\nSon işlem (${a.status.displayName}): ${_fmt(a.reviewedAt, withTime: true)}' : ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                ),
              )
            else
              ...history.map((h) {
                final at = _parseDate(h['at']);
                final by = h['by'] as String?;
                final note = h['note'] as String?;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 7, color: AppTheme.accent),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_fmt(at, withTime: true)} — ${_historyLabel(h['status']?.toString() ?? '')}'
                          '${by != null ? ' ($by)' : ''}'
                          '${note != null && note.isNotEmpty ? '\n“$note”' : ''}',
                          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            if (a.previousVersions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${a.previousVersions.length} önceki video yedekte saklanıyor.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textTertiary),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AuditionReviewScreen(audition: a)),
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Başvuruyu Aç'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
        ),
      );
}
