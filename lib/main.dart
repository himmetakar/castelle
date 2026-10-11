import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:castelle/core/widgets/web_frame.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:castelle/core/theme/app_theme.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/core/routing/app_router.dart';
import 'package:castelle/features/actor/providers/actor_profile_provider.dart';
import 'package:castelle/features/admin/providers/actor_filter_provider.dart';
import 'package:castelle/features/employer/providers/project_provider.dart';
import 'package:castelle/core/providers/notification_provider.dart';
import 'package:castelle/features/actor/providers/audition_provider.dart';
// import 'package:castelle/core/services/audition_cleanup_service.dart'; // otomatik video temizliği kapalı
import 'package:castelle/core/services/push_notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:castelle/core/widgets/update_gate.dart';
import 'firebase_options.dart';

/// Castelle - Premium Casting Agency SaaS Platform
/// Ana giriş noktası

/// Web paneli için reCAPTCHA v3 site anahtarı (Firebase Console → App Check →
/// Web uygulaması → reCAPTCHA v3). Boşsa web'de App Check başlatılmaz.
const String _recaptchaV3SiteKey = '';

Future<void> _activateAppCheck() async {
  try {
    if (kIsWeb) {
      if (_recaptchaV3SiteKey.isEmpty) return;
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(_recaptchaV3SiteKey),
      );
      return;
    }
    await FirebaseAppCheck.instance.activate(
      // Debug derlemelerde konsola yazılan debug token'ını Firebase Console'a
      // eklemeniz gerekir; mağaza sürümünde Play Integrity / DeviceCheck kullanılır.
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
    );
  } catch (e) {
    debugPrint('⚠️ [AppCheck] Başlatılamadı: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  // Sistem bar rengini ayarla
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Yatay modu kapat (sadece dikey)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Firebase başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firebase App Check: Firestore / Storage / Functions isteklerinin yalnızca
  // mağazadan yüklenmiş gerçek Castelle uygulamasından gelmesini sağlar.
  // (API anahtarı uygulamanın içinde herkese açık olduğundan, App Check
  // olmadan bu anahtarla yazılan bir betik doğrudan veritabanına istek
  // atabilir.) Zorunlu kılma Firebase Console → App Check'ten açılır.
  await _activateAppCheck();

  // Crashlytics: sahadaki çökme ve yakalanmamış hataları otomatik toplar
  // (hangi sürüm, hangi cihaz, hangi ekran). Müşteriye "hatayı tarif edin"
  // demek yerine Firebase Console → Crashlytics'ten görülür. Web'de yok.
  if (!kIsWeb) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    FirebaseAuth.instance.authStateChanges().listen((user) {
      FirebaseCrashlytics.instance.setUserIdentifier(user?.uid ?? '');
    });
  }

  // Push bildirimleri: arka plan/kapalı durum mesaj işleyicisi (top-level fonksiyon olmalı)
  // ve yerel bildirim kanalı — telefona WhatsApp benzeri sesli/banner bildirim düşmesi için.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await PushNotificationService().initLocalNotifications();

  // Sadece giriş yapmış kullanıcı varsa arka plan temizleme işlemlerini çalıştır
  if (FirebaseAuth.instance.currentUser != null) {
    // Eski mock veri temizliği kaldırıldı: istemciden başka kullanıcıların
    // belgelerini silmeye çalışıyordu (güvenlik kuralları artık izin vermez).
    // NOT: Çekim tarihinden 10 gün sonra audition videolarını Storage'dan
    // silen otomatik temizlik devre dışı bırakıldı. Müşteri talebi: yüklenen
    // tüm oyuncu oyunlarının yedeği tutulmalı ve geri getirilebilmeli.
    // AuditionCleanupService.runCleanup().catchError((_) {});
  }

  // Release'de bir widget hata verirse Flutter tüm alanı gri kutuyla
  // kaplıyor ve sebep görünmüyordu. Bunun yerine kısa, okunur bir uyarı göster.
  ErrorWidget.builder = (details) => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Bu bölüm görüntülenemedi.\n${details.exceptionAsString()}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
      );

  runApp(const CastelleApp());
}

class CastelleApp extends StatelessWidget {
  const CastelleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ActorProfileProvider()),
        ChangeNotifierProvider(create: (_) => ActorFilterProvider()),
        ChangeNotifierProvider(create: (_) => ProjectProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AuditionProvider()),
      ],
      child: const CastelleAppContent(),
    );
  }
}

class CastelleAppContent extends StatefulWidget {
  const CastelleAppContent({super.key});

  @override
  State<CastelleAppContent> createState() => _CastelleAppContentState();
}

class _CastelleAppContentState extends State<CastelleAppContent> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _router = AppRouter.router(authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Castelle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
      // Web'de geniş ekranlarda uygulama tüm genişliğe yayılmasın:
      // içerik ortada, okunaklı bir genişlikte gösterilir.
      // UpdateGate: config/app.minBuildNumber altındaki sürümleri
      // "Güncelleme gerekli" ekranında durdurur; sürüm damgasını yazar.
      builder: (context, child) => WebFrame(
        child: UpdateGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
