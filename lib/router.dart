import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/auth_state.dart';
import 'screens/dashboard_screen.dart';
import 'screens/eggs_screen.dart';
import 'screens/feed_inventory_screen.dart';
import 'screens/feed_product_detail_screen.dart';
import 'screens/flock_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/signup_screen.dart';
import 'widgets/app_shell.dart';

GoRouter buildRouter(AuthState auth) {
  Page<void> page(Widget w) => NoTransitionPage<void>(child: w);
  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: auth,
    redirect: (context, state) {
      final onBootPage = state.matchedLocation == '/boot';
      final onAuthPage = state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      if (!auth.initialized) return onBootPage ? null : '/boot';
      if (onBootPage) return auth.isLoggedIn ? '/dashboard' : '/login';
      if (!auth.isLoggedIn && !onAuthPage) return '/login';
      if (auth.isLoggedIn && onAuthPage) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/boot',
        builder: (_, __) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/dashboard', pageBuilder: (_, __) => page(const DashboardScreen())),
          GoRoute(path: '/flock', pageBuilder: (_, __) => page(const FlockScreen())),
          GoRoute(path: '/feed', pageBuilder: (_, __) => page(const FeedInventoryScreen())),
          GoRoute(
            path: '/feed/:productId',
            pageBuilder: (_, state) => page(FeedProductDetailScreen(productId: int.parse(state.pathParameters['productId']!))),
          ),
          GoRoute(path: '/eggs', pageBuilder: (_, __) => page(const EggsScreen())),
          GoRoute(path: '/invoices', pageBuilder: (_, __) => page(const InvoicesScreen())),
          GoRoute(path: '/profile', pageBuilder: (_, __) => page(const ProfileScreen())),
        ],
      ),
    ],
  );
}
