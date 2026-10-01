import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:castelle/core/theme/app_theme.dart';

/// Castelle - Web için ortalanmış içerik sütunu
///
/// Geniş ekranda (web) tüm uygulama [maxWidth] genişliğinde ortalanmış bir
/// sütunda çizilir; sağda/solda boşluk kalır. `MediaQuery` genişliği de
/// sütun genişliğine çekilir ki ekranlardaki `MediaQuery.sizeOf(context)`
/// tabanlı hesaplar tüm pencereye göre değil sütuna göre yapılsın.
/// Mobilde (ve dar web penceresinde) hiçbir şey değişmez.
class WebFrame extends StatelessWidget {
  const WebFrame({super.key, required this.child});

  static const double maxWidth = 1200;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    final mq = MediaQuery.of(context);
    if (mq.size.width <= maxWidth) return child;

    return ColoredBox(
      color: AppTheme.border,
      child: Center(
        child: Container(
          width: maxWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            boxShadow: AppTheme.shadowMd,
          ),
          child: MediaQuery(
            data: mq.copyWith(size: Size(maxWidth, mq.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}

/// Web'de içeriği yatayda ortalayıp [maxWidth] ile sınırlar (takvim, video
/// vb.). Mobil uygulamada hiçbir etkisi yoktur.
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Mobilde sabit [mobileCount] sütun (mevcut görünüm aynen kalır); web'de
/// sütun sayısı genişliğe göre [maxExtent] ile hesaplanır ki geniş ekranda
/// kartlar devasa olmasın.
SliverGridDelegate adaptiveGridDelegate({
  required int mobileCount,
  required double maxExtent,
  double mainAxisSpacing = 0,
  double crossAxisSpacing = 0,
  double childAspectRatio = 1,
}) {
  if (kIsWeb) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: maxExtent,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
    );
  }
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: mobileCount,
    mainAxisSpacing: mainAxisSpacing,
    crossAxisSpacing: crossAxisSpacing,
    childAspectRatio: childAspectRatio,
  );
}
