import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:castelle/core/theme/app_theme.dart';

/// Castelle — Oyuncu profil onay durumu etiketi
///
/// Veri tabanındaki `approvalStatus` alanını birebir yansıtır; böylece panelde
/// daha önce onaylanmış bir profil tekrar karşınıza çıktığında durumu tek
/// bakışta görünür (Onaylı / Onay Bekliyor / Veli Onayı Bekliyor / Reddedildi).
class ApprovalStatusBadge extends StatelessWidget {
  final String? status;
  final DateTime? approvedAt;
  final bool compact;

  const ApprovalStatusBadge({
    super.key,
    required this.status,
    this.approvedAt,
    this.compact = false,
  });

  static ({String label, Color color, IconData icon}) describe(String? status) {
    switch (status) {
      case 'approved':
        return (label: 'Onaylı', color: AppTheme.success, icon: Icons.verified);
      case 'rejected':
        return (label: 'Reddedildi', color: AppTheme.error, icon: Icons.cancel);
      case 'pending_guardian':
        return (
          label: 'Veli Onayı Bekliyor',
          color: AppTheme.warning,
          icon: Icons.family_restroom,
        );
      default:
        return (
          label: 'Onay Bekliyor',
          color: AppTheme.warning,
          icon: Icons.hourglass_top_rounded,
        );
    }
  }

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final info = describe(status);
    final showDate = !compact && status == 'approved' && approvedAt != null;
    final text = showDate ? '${info.label} · ${_fmt(approvedAt!)}' : info.label;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: info.color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: compact ? 11 : 13, color: info.color),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}
