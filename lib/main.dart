import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:castelle/core/services/audition_cleanup_service.dart';
import 'firebase_options.dart';

/// Castelle - Premium Casting Agency SaaS Platform
/// Ana giriş noktası

/// Eski mock oyuncu belgelerini Firestore'dan temizle (tek seferlik)
Future<void> _cleanupMockData() async {
  final firestore = FirebaseFirestore.instance;
  const mockIds = ['mock_actor_1', 'mock_actor_2', 'mock_actor_3',
                   'mock_actor_4', 'mock_actor_5', 'mock_actor_6',
                   'mock_actor_7', 'mock_actor_8'];
  for (final id in mockIds) {
    try {
      final doc = firestore.collection('users').doc(id);
      final snap = await doc.get();
      if (snap.exists) {
        await doc.delete();
        debugPrint('🗑️ [Cleanup] Mock silindi: $id');
      }
    } catch (e) {
      debugPrint('⚠️ [Cleanup] $id silinemedi: $e');
    }
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

  // Eski mock verileri temizle (arka planda)
  _cleanupMockData().catchError(
    (e) => debugPrint('⚠️ Mock cleanup hatası: $e'),
  );

  // Çekim tarihi geçmiş audition videoları temizle (arka planda)
  AuditionCleanupService.runCleanup().catchError(
    (e) => debugPrint('⚠️ Audition cleanup hatası: $e'),
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
    );
  }
}
