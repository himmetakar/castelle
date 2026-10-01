import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Web İçerik Çerçevesi
///
/// Uygulama mobil için tasarlandı; web'de geniş ekranda her şey (takvim,
/// kartlar, video) tüm genişliğe yayılıp devasa görünüyordu. Web'de tüm
/// rotaları [maxWidth] genişliğinde ortalanmış tek bir sütuna alır.
/// Mobilde hiçbir şey değişmez.
class WebContentFrame extends StatelessWidget {
  static const double maxWidth = 1200;

  final Widget child;

  const WebContentFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;

    // MediaQuery genişliğini de daraltıyoruz ki `MediaQuery.size.width`
    // ile boyut hesaplayan ekranlar (dialoglar, oranlı kutular) sütuna uysun.
    return ColoredBox(
      color: AppTheme.surface,
      child: Center(
        child: DecoratedBox(
          // Sütunun kenarlarını belli eden ince çizgi.
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.symmetric(
              vertical: BorderSide(color: AppTheme.border.withValues(alpha: 0.6), width: 0.5),
            ),
          ),
          child: SizedBox(
            width: maxWidth,
            child: MediaQuery(
              data: media.copyWith(size: Size(maxWidth, media.size.height)),
              child: ClipRect(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
