import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/models/actor_profile_model.dart';

/// Castelle — Paylaşımlı Oyuncu Kartı
/// Admin, Moderatör ve Oyuncu havuzu ekranlarında kullanılır.

class ActorCard extends StatelessWidget {
  final ActorProfileModel actor;
  final int index;
  final bool showAdminInfo;   // boy/cinsiyet satırı
  final int matchedSkillCount; // skill badge sayısı (0 = badge yok)
  final VoidCallback? onTap;

  const ActorCard({
    super.key,
    required this.actor,
    required this.index,
    this.showAdminInfo = false,
    this.matchedSkillCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSkillMatch = matchedSkillCount > 0;

    final card = GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── KART GÖVDESİ ──────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceCard,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: hasSkillMatch
                    ? AppTheme.error.withValues(alpha: 0.55)
                    : AppTheme.border.withValues(alpha: 0.6),
                width: hasSkillMatch ? 1.8 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── FOTO ALANI ──────────────────────────
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.radiusMd),
                      topRight: Radius.circular(AppTheme.radiusMd),
                    ),
                    child: _buildPhoto(),
                  ),
                ),

                // ── BİLGİ ALANI ─────────────────────────
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // İsim
                        Text(
                          actor.fullName,
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Yaş · Şehir
                        if (actor.age != null || actor.city != null)
                          _infoRow(
                            [
                              if (actor.age != null) '${actor.age} yaş',
                              if (actor.city != null) actor.city!,
                            ],
                            color: AppTheme.textSecondary,
                          ),
                        // Boy · Cinsiyet (admin/mod)
                        if (showAdminInfo &&
                            (actor.heightCm != null || actor.gender != null)) ...[
                          const SizedBox(height: 2),
                          _infoRow(
                            [
                              if (actor.heightCm != null)
                                '${actor.heightCm} cm',
                              if (actor.gender != null)
                                actor.gender!.displayName,
                            ],
                            color: AppTheme.textTertiary,
                            fontSize: 10.5,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── SKILL BADGE ──────────────────────────────
          if (hasSkillMatch)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.error.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '⚡ $matchedSkillCount',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    return card
        .animate()
        .fadeIn(delay: (40 + index * 35).ms, duration: 250.ms)
        .scaleXY(begin: 0.94, end: 1.0, duration: 220.ms);
  }

  // ── FOTOĞRAF ──────────────────────────────────────────
  Widget _buildPhoto() {
    if (actor.profilePhotoUrl != null && actor.profilePhotoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: actor.profilePhotoUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => _avatarFallback(),
        errorWidget: (context, url, error) => _avatarFallback(),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Center(
        child: Text(
          _initials(),
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.accent,
          ),
        ),
      ),
    );
  }

  Widget _infoRow(List<String> parts,
      {Color? color, double fontSize = 11.5}) {
    return Text(
      parts.join(' · '),
      style: GoogleFonts.inter(
        fontSize: fontSize,
        color: color ?? AppTheme.textSecondary,
        fontWeight: FontWeight.w400,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _initials() {
    if (actor.fullName.isEmpty) return '?';
    final parts = actor.fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
