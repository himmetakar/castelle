import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:castelle/core/models/audition_model.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/services/audition_service.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/widgets/app_video_player.dart';

/// Castelle — Silinenler (Çöp Kutusu)
///
/// Panelden silinen oyuncu oyunları (audition videoları) kalıcı olarak
/// silinmez; burada listelenir ve tek dokunuşla geri yüklenebilir.
/// Video dosyaları depolamada korunur.
class AuditionTrashScreen extends StatelessWidget {
  /// Moderatörler için yalnızca atandıkları projeler.
  final List<String>? projectIds;

  const AuditionTrashScreen({super.key, this.projectIds});

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _restore(BuildContext context, AuditionModel a) async {
    final user = context.read<AuthProvider>().user;
    try {
      await AuditionService().restoreAudition(a.id, restoredByName: user?.fullName);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${a.actorName} — "${a.projectTitle}" geri yüklendi.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geri yüklenemedi: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _preview(BuildContext context, AuditionModel a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${a.actorName} · ${a.projectTitle}',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              AppVideoPlayer(videoUrl: a.videoUrl, autoInit: true, maxHeight: 420),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _restore(context, a);
                  },
                  icon: const Icon(Icons.restore),
                  label: const Text('Geri Yükle'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text('Silinenler', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<List<AuditionModel>>(
        stream: AuditionService().streamDeletedAuditions(projectIds: projectIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
          }
          final list = snapshot.data ?? const <AuditionModel>[];
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline,
                        size: 56, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      'Silinen kayıt yok',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Panelden silinen oyuncu oyunları burada saklanır ve geri yüklenebilir.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.info.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'Silinen oyunlar kalıcı olarak kaldırılmaz. Videolar yedekte tutulur; '
                    'geri yüklediğinizde başvuru eski durumuyla listeye döner.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                );
              }
              final a = list[index - 1];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.actorName,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${a.projectTitle} · ${a.roleName}',
                            style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Durum: ${a.status.displayName} · Silinme: ${_fmt(a.deletedAt)}'
                            '${a.deletedByName != null ? ' (${a.deletedByName})' : ''}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textTertiary),
                          ),
                        ],
                      ),
                    ),
                    if (a.videoUrl.isNotEmpty)
                      IconButton(
                        tooltip: 'İzle',
                        icon: const Icon(Icons.play_circle_outline, color: AppTheme.accent),
                        onPressed: () => _preview(context, a),
                      ),
                    IconButton(
                      tooltip: 'Geri Yükle',
                      icon: const Icon(Icons.restore, color: AppTheme.success),
                      onPressed: () => _restore(context, a),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
