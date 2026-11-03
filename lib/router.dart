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
import 'screens/monthly_expense_detail_screen.dart';
import 'screens/medicine_detail_screen.dart';
import 'screens/medicines_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/raw_material_detail_screen.dart';
import 'screens/raw_materials_screen.dart';
import 'screens/signup_screen.dart';
import 'widgets/app_shell.dart';

GoRouter buildRouter(AuthState auth) {
  Page<void> page(Widget w) => NoTransitionPage<void>(child: w);
  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: auth,
    redirect: (context, state) {
      final onBootPage = state.matchedLocation == '/boot';
      final onAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';
      if (!auth.initialized) return onBootPage ? null : '/boot';
      if (onBootPage) return auth.isLoggedIn ? '/dashboard' : '/login';
      if (!auth.isLoggedIn && !onAuthPage) return '/login';
      if (auth.isLoggedIn && onAuthPage) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/boot',
        builder: (_, __) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              pageBuilder: (_, __) => page(const DashboardScreen())),
          GoRoute(
            path: '/expenses/monthly',
            pageBuilder: (_, state) => page(MonthlyExpenseDetailScreen(
              month: int.tryParse(state.uri.queryParameters['month'] ?? '') ??
                  DateTime.now().month,
              year: int.tryParse(state.uri.queryParameters['year'] ?? '') ??
                  DateTime.now().year,
            )),
          ),
          GoRoute(
              path: '/flock',
              pageBuilder: (_, __) => page(const FlockScreen())),
          GoRoute(
              path: '/feed',
              pageBuilder: (_, __) => page(const FeedInventoryScreen())),
          GoRoute(
              path: '/raw-materials',
              pageBuilder: (_, __) => page(const RawMaterialsScreen())),
          GoRoute(
            path: '/raw-materials/:materialId',
            pageBuilder: (_, state) => page(RawMaterialDetailScreen(
              materialId: state.pathParameters['materialId']!,
              materialName: (state.extra as Map<String, String>?)?['name'],
              unit: (state.extra as Map<String, String>?)?['unit'],
            )),
          ),
          GoRoute(
              path: '/medicines',
              pageBuilder: (_, __) => page(const MedicinesScreen())),
          GoRoute(
            path: '/medicines/:medicineId',
            pageBuilder: (_, state) => page(MedicineDetailScreen(
              medicineId: state.pathParameters['medicineId']!,
              medicineName: (state.extra as Map<String, String>?)?['name'],
              unit: (state.extra as Map<String, String>?)?['unit'],
            )),
          ),
          GoRoute(
            path: '/feed/:productId',
            pageBuilder: (_, state) => page(FeedProductDetailScreen(
                productId: state.pathParameters['productId']!)),
          ),
          GoRoute(
              path: '/eggs', pageBuilder: (_, __) => page(const EggsScreen())),
          GoRoute(
              path: '/invoices',
              pageBuilder: (_, __) => page(const InvoicesScreen())),
          GoRoute(
              path: '/profile',
              pageBuilder: (_, __) => page(const ProfileScreen())),
        ],
      ),
    ],
  );
}
