import 'package:go_router/go_router.dart';
import 'package:castelle/core/providers/auth_provider.dart';
import 'package:castelle/features/auth/screens/splash_screen.dart';
import 'package:castelle/features/auth/screens/login_screen.dart';
import 'package:castelle/features/auth/screens/register_screen.dart';
import 'package:castelle/features/auth/screens/onboarding_screen.dart';
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
        final isLoading = authProvider.status == AuthStatus.initial ||
            authProvider.status == AuthStatus.loading;
        final isAuthRoute = state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/onboarding';
        final isSplash = state.matchedLocation == '/';

        // 0. Splash ekranında 2 saniye dolana kadar kalmaya zorla
        if (isSplash && !SplashScreen.splashPassed) {
          return null;
        }

        // 1. Eğer henüz yükleniyorsa
        if (isLoading) {
          return isSplash ? null : '/';
        }

        // 2. Yükleme tamamlandı ve kullanıcı giriş yapmamış
        if (!isAuthenticated) {
          if (!isAuthRoute) {
            return '/login';
          }
          return null;
        }

        // 3. Yükleme tamamlandı ve kullanıcı giriş yapmış
        if (isAuthenticated) {
          if (isSplash || isAuthRoute) {
            return '/home';
          }
          return null;
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

        // Main App Shell - Rol bazlı
        GoRoute(
          path: '/home',
          builder: (context, state) => const RoleBasedShell(),
        ),
      ],
    );
  }
}
