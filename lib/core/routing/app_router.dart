import 'package:go_router/go_router.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/auth/screens/splash_screen.dart';
import 'package:castelle/features/auth/screens/login_screen.dart';
import 'package:castelle/features/auth/screens/register_screen.dart';
import 'package:castelle/features/auth/screens/onboarding_screen.dart';
import 'package:castelle/features/auth/screens/verify_email_screen.dart';
import 'package:castelle/core/widgets/role_based_shell.dart';

/// Castelle - App Router
/// GoRouter ile rol tabanlı navigasyon yönetimi

class AppRouter {
  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final isInitialLoading = authProvider.status == AuthStatus.initial;
        final needsEmailVerification = authProvider.needsEmailVerification;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/onboarding';
        final isVerifyEmailRoute = state.matchedLocation == '/verify-email';
        final isSplash = state.matchedLocation == '/';

        // 0. Splash ekranında 2 saniye dolana kadar kalmaya zorla
        if (isSplash && !SplashScreen.splashPassed) {
          return null;
        }

        // 1. İlk uygulama açılışında yükleniyorsa splash ekranında kal
        if (isInitialLoading) {
          return isSplash ? null : '/';
        }

        // 2. Yükleme tamamlandı ve kullanıcı giriş yapmamış
        if (!isAuthenticated) {
          if (!isAuthRoute) {
            return '/login';
          }
          return null;
        }

        // 3. Giriş yapmış ama e-posta aktivasyonu bekleniyor —
        // aktivasyon linkine tıklanana kadar uygulama içeriği gösterilmez.
        if (needsEmailVerification) {
          return isVerifyEmailRoute ? null : '/verify-email';
        }

        // 4. Yükleme tamamlandı, kullanıcı giriş yapmış ve doğrulanmış
        if (isSplash || isAuthRoute || isVerifyEmailRoute) {
          return '/home';
        }
        return null;
      },
      routes: [
        // Splash
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),

        // Auth Routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/verify-email',
          builder: (context, state) => const VerifyEmailScreen(),
        ),

        // Main App Shell - Rol bazlı
        GoRoute(
          path: '/home',
          builder: (context, state) => const RoleBasedShell(),
        ),
      ],
    );
  }
}
