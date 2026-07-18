import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/actor_profile_model.dart';
import 'package:castelle/core/services/actor_profile_service.dart';

/// Admin — Onay Bekleyen Yeni Üyeler Ekranı
class NewMembersScreen extends StatefulWidget {
  const NewMembersScreen({super.key});

  @override
  State<NewMembersScreen> createState() => _NewMembersScreenState();
}

class _NewMembersScreenState extends State<NewMembersScreen> {
  final _service = ActorProfileService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: Text(
          'Yeni Üyeler',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<List<ActorProfileModel>>(
        stream: _service.streamPendingActors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            );
          }

          final actors = snapshot.data ?? [];

          if (actors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: AppTheme.textTertiary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Onay bekleyen üye yok',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Yeni kayıt olan oyuncular burada görünür',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: actors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) =>
                _ActorApprovalCard(actor: actors[i], service: _service)
                    .animate()
                    .fadeIn(delay: (i * 40).ms),
          );
        },
      ),
    );
  }
}

class _ActorApprovalCard extends StatefulWidget {
  final ActorProfileModel actor;
  final ActorProfileService service;

  const _ActorApprovalCard({required this.actor, required this.service});

  @override
  State<_ActorApprovalCard> createState() => _ActorApprovalCardState();
}

class _ActorApprovalCardState extends State<_ActorApprovalCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProfileDetail(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: AppTheme.warning.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: AppTheme.shadowSm,
        ),
        child: Row(
          children: [
            // Profil fotoğrafı
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.actor.profilePhotoUrl != null &&
                      widget.actor.profilePhotoUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.actor.profilePhotoUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _avatar(),
                      errorWidget: (context, url, err) => _avatar(),
                    )
                  : _avatar(),
            ),
            const SizedBox(width: 14),
            // İsim & bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.actor.fullName,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.actor.email,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (widget.actor.adminNote != null &&
                          widget.actor.adminNote!.isNotEmpty)
                        _chip(
                          Icons.edit_note,
                          'Düzenleme İstendi',
                          AppTheme.info,
                        )
                      else
                        _chip(
                          Icons.hourglass_top,
                          'Onay Bekliyor',
                          AppTheme.warning,
                        ),
                      if (widget.actor.city != null) ...[
                        const SizedBox(width: 6),
                        _chip(Icons.location_on_outlined,
                            widget.actor.city!, AppTheme.info),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    final initials = widget.actor.fullName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.accent,
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProfileDetailSheet(
        actor: widget.actor,
        service: widget.service,
        isLoading: _isLoading,
        onApprove: _approve,
        onReject: _reject,
        onRequestEdit: _requestEdit,
      ),
    );
  }

  Future<void> _approve() async {
    setState(() => _isLoading = true);
    try {
      await widget.service.approveActor(widget.actor.uid);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/new_members');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.actor.fullName} onaylandı ✅'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text('Başvuruyu Reddet',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.actor.fullName} adlı üyenin başvurusunu reddetmek istediğinize emin misiniz? Reddetme nedenini yazabilirsiniz:',
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              maxLength: 200,
              autofocus: true,
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Örn: Fotoğraflarınız ve biyografiniz Castelle standartlarına uygun değildir.',
                hintStyle: GoogleFonts.inter(fontSize: 12, color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.5)),
                ),
                counterStyle: GoogleFonts.inter(fontSize: 10, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: GoogleFonts.inter(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reddet', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final reason = ctrl.text.trim().isEmpty ? null : ctrl.text.trim();
      await widget.service.rejectActor(widget.actor.uid, reason: reason);
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst || route.settings.name == '/new_members');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.actor.fullName} başvurusu reddedildi ❌'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestEdit(String message) async {
    setState(() => _isLoading = true);
    try {
      await widget.service.requestEdit(widget.actor.uid, message);
      if (mounted) {
        Navigator.pop(context); // Sheet kapat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Düzenleme talebi gönderildi 📝'),
            backgroundColor: AppTheme.info,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

/// Profil Detay Sheet
class _ProfileDetailSheet extends StatelessWidget {
  final ActorProfileModel actor;
  final ActorProfileService service;
  final bool isLoading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final Function(String) onRequestEdit;

  const _ProfileDetailSheet({
    required this.actor,
    required this.service,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
    required this.onRequestEdit,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),

          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Profil İnceleme',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Onay Bekliyor',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // İçerik
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil kartı
                  _buildProfileHeader(context),
                  const SizedBox(height: 20),

                  // Admin notu varsa göster
                  if (actor.adminNote != null &&
                      actor.adminNote!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.info.withValues(alpha: 0.06),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: AppTheme.info.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.feedback_outlined,
                                  size: 14, color: AppTheme.info),
                              const SizedBox(width: 6),
                              Text(
                                'Önceki Düzenleme Talebi',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.info,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            actor.adminNote!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bilgi satırları
                  _buildInfoSection(),

                  const SizedBox(height: 12),

                  // Yetenekler
                  if (actor.skills.isNotEmpty) ...[
                    _sectionTitle('Yetenekler'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actor.skills
                          .map((s) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      AppTheme.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                  border: Border.all(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.25)),
                                ),
                                child: Text(
                                  s,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bio
                  if (actor.bio != null && actor.bio!.isNotEmpty) ...[
                    _sectionTitle('Biyografi'),
                    const SizedBox(height: 8),
                    Text(
                      actor.bio!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),

          // Alt Aksiyon Butonları
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Row(
      children: [
        // Foto
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: actor.profilePhotoUrl != null &&
                  actor.profilePhotoUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: actor.profilePhotoUrl!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildAvatar(72),
                  errorWidget: (context, url, err) => _buildAvatar(72),
                )
              : _buildAvatar(72),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                actor.fullName,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                actor.email,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textTertiary,
                ),
              ),
              if (actor.phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  actor.phone,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    final rows = <MapEntry<String, String>>[];
    if (actor.age != null) rows.add(MapEntry('Yaş', '${actor.age}'));
    if (actor.gender != null) rows.add(MapEntry('Cinsiyet', actor.gender!.displayName));
    if (actor.heightCm != null) rows.add(MapEntry('Boy', '${actor.heightCm} cm'));
    if (actor.weightKg != null) rows.add(MapEntry('Kilo', '${actor.weightKg} kg'));
    if (actor.city != null) rows.add(MapEntry('Şehir', actor.city!));
    if (actor.experienceLevel != null) {
      rows.add(MapEntry('Deneyim', _expLabel(actor.experienceLevel!)));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Kişisel Bilgiler'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: rows.mapIndexed((i, e) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.key,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        Text(
                          e.value,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < rows.length - 1)
                    Divider(
                        height: 1,
                        color: AppTheme.border.withValues(alpha: 0.3)),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  String _expLabel(String v) => switch (v) {
        'beginner' => 'Başlangıç',
        'intermediate' => 'Orta',
        'advanced' => 'İleri',
        'professional' => 'Profesyonel',
        _ => v,
      };

  Widget _buildAvatar(double size) {
    final initials = actor.fullName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.outfit(
            fontSize: size * 0.3,
            fontWeight: FontWeight.w700,
            color: AppTheme.accent,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textTertiary,
          letterSpacing: 0.5,
        ),
      );

  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(
          top: BorderSide(color: AppTheme.border.withValues(alpha: 0.3)),
        ),
      ),
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : Row(
              children: [
                // Reddet
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.block, size: 16),
                    label: Text('Reddet', style: GoogleFonts.outfit(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: BorderSide(
                          color: AppTheme.error.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Düzenleme Talep Et
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showEditRequestDialog(context),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: Text('Düzenleme İste',
                        style: GoogleFonts.outfit(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.info,
                      side: BorderSide(
                          color: AppTheme.info.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Onayla
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label:
                        Text('Onayla', style: GoogleFonts.outfit(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _showEditRequestDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceCard,
        title: Text(
          'Düzenleme Talebi',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Oyuncudan hangi düzenlemeyi yapmasını istiyorsunuz?',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 4,
              maxLength: 300,
              autofocus: true,
              style: GoogleFonts.inter(
                  fontSize: 14, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Örn: Profil fotoğrafınız yetersiz, lütfen net bir fotoğraf ekleyin.',
                hintStyle:
                    GoogleFonts.inter(fontSize: 13, color: AppTheme.textTertiary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  borderSide: BorderSide(
                      color: AppTheme.border.withValues(alpha: 0.5)),
                ),
                counterStyle:
                    GoogleFonts.inter(fontSize: 10, color: AppTheme.textTertiary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal',
                style: GoogleFonts.inter(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              final msg = ctrl.text.trim();
              if (msg.isEmpty) return;
              Navigator.pop(ctx);
              onRequestEdit(msg);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: AppTheme.textOnAccent,
              elevation: 0,
            ),
            child: Text('Gönder', style: GoogleFonts.outfit()),
          ),
        ],
      ),
    );
  }
}

// Extension for mapIndexed
extension _ListExt<T> on List<T> {
  List<R> mapIndexed<R>(R Function(int i, T e) fn) {
    return List.generate(length, (i) => fn(i, this[i]));
  }
}
