import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/auth_state.dart';
import 'screens/dashboard_screen.dart';
import 'screens/customer_ledger_screen.dart';
import 'screens/eggs_screen.dart';
import 'screens/feed_inventory_screen.dart';
import 'screens/feed_product_detail_screen.dart';
import 'screens/farm_expenses_screen.dart';
import 'screens/flock_screen.dart';
import 'screens/invoices_screen.dart';
import 'screens/login_screen.dart';
import 'screens/monthly_expense_detail_screen.dart';
import 'screens/medicine_detail_screen.dart';
import 'screens/medicines_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/raw_material_detail_screen.dart';
import 'screens/raw_materials_screen.dart';
import 'screens/ready_feed_detail_screen.dart';
import 'screens/signup_screen.dart';
import 'widgets/app_shell.dart';

GoRouter buildRouter(AuthState auth) {
  Page<void> page(GoRouterState state, Widget child) =>
      NoTransitionPage<void>(key: state.pageKey, child: child);
  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: auth.routeRefreshListenable,
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
        pageBuilder: (_, state) => page(
          state,
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => page(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (_, state) => page(state, const SignupScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
              path: '/dashboard',
              pageBuilder: (_, state) => page(state, const DashboardScreen())),
          GoRoute(
            path: '/expenses/monthly',
            pageBuilder: (_, state) => page(
                state,
                MonthlyExpenseDetailScreen(
                  month:
                      int.tryParse(state.uri.queryParameters['month'] ?? '') ??
                          DateTime.now().month,
                  year: int.tryParse(state.uri.queryParameters['year'] ?? '') ??
                      DateTime.now().year,
                )),
          ),
          GoRoute(
              path: '/flock',
              pageBuilder: (_, state) => page(state, const FlockScreen())),
          GoRoute(
              path: '/feed',
              pageBuilder: (_, state) =>
                  page(state, const FeedInventoryScreen())),
          GoRoute(
              path: '/raw-materials',
              pageBuilder: (_, state) =>
                  page(state, const RawMaterialsScreen())),
          GoRoute(
            path: '/raw-materials/:materialId',
            pageBuilder: (_, state) => page(
                state,
                RawMaterialDetailScreen(
                  materialId: state.pathParameters['materialId']!,
                  materialName: (state.extra as Map<String, String>?)?['name'],
                  unit: (state.extra as Map<String, String>?)?['unit'],
                )),
          ),
          GoRoute(
              path: '/medicines',
              pageBuilder: (_, state) => page(state, const MedicinesScreen())),
          GoRoute(
              path: '/farm-expenses',
              pageBuilder: (_, state) =>
                  page(state, const FarmExpensesScreen())),
          GoRoute(
            path: '/medicines/:medicineId',
            pageBuilder: (_, state) => page(
                state,
                MedicineDetailScreen(
                  medicineId: state.pathParameters['medicineId']!,
                  medicineName: (state.extra as Map<String, String>?)?['name'],
                  unit: (state.extra as Map<String, String>?)?['unit'],
                )),
          ),
          GoRoute(
              path: '/feed/ready',
              pageBuilder: (_, state) =>
                  page(state, const ReadyFeedDetailScreen())),
          GoRoute(
            path: '/feed/:productId',
            pageBuilder: (_, state) => page(
                state,
                FeedProductDetailScreen(
                    productId: state.pathParameters['productId']!)),
          ),
          GoRoute(
              path: '/eggs',
              pageBuilder: (_, state) => page(state, const EggsScreen())),
          GoRoute(
              path: '/invoices',
              pageBuilder: (_, state) => page(state, const InvoicesScreen())),
          GoRoute(
            path: '/customers/:customerId',
            pageBuilder: (_, state) => page(
                state,
                CustomerLedgerScreen(
                  customerId: state.pathParameters['customerId']!,
                )),
          ),
          GoRoute(
              path: '/profile',
              pageBuilder: (_, state) => page(state, const ProfileScreen())),
        ],
      ),
    ],
  );
}
