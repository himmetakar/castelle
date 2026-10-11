import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/utils/media_upload.dart';

/// Castelle — Proje / marka logosu kutusu
///
/// Reklam briefindeki logolar çok farklı en-boy oranlarında olabiliyor
/// (kare, yatay uzun, dikey). Eskiden bazı alanlarda `BoxFit.cover`
/// kullanıldığı için uzun logolar kesiliyordu. Bu widget logoyu her zaman
/// beyaz zemin üzerinde, kenarlardan boşluk bırakarak ve **kırpmadan**
/// (`BoxFit.contain`) kutunun ortasına sığdırır.
class ProjectLogo extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final double padding;
  final bool circle;
  final bool showBorder;

  const ProjectLogo({
    super.key,
    required this.imageUrl,
    this.size = 56,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.padding = 6,
    this.circle = false,
    this.showBorder = true,
  });

  Widget _fallback() => Image.asset(
        'assets/images/ana-logo-siyah.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.movie_creation_outlined,
          color: AppTheme.textTertiary,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    Widget image;
    if (url == null || url.isEmpty) {
      image = _fallback();
    } else if (url.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
          ),
        ),
        errorWidget: (_, __, ___) => _fallback(),
      );
    } else {
      image = MediaUpload.image(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    final w = width ?? size;
    final h = height ?? size;
    // Çok küçük kutularda (takvim noktaları gibi) iç boşluk orantılı küçülür.
    final innerPadding = (w < 30 || h < 30) ? 1.5 : padding;

    return Container(
      width: w,
      height: h,
      padding: EdgeInsets.all(innerPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(color: AppTheme.border.withValues(alpha: 0.4), width: 0.5)
            : null,
      ),
      child: circle
          ? ClipOval(child: SizedBox.expand(child: image))
          : ClipRRect(
              borderRadius: BorderRadius.circular(
                (borderRadius - innerPadding).clamp(0.0, borderRadius),
              ),
              child: SizedBox.expand(child: image),
            ),
    );
  }
}
