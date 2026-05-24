import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alpha_suite_erp/core/constants/app_routes.dart';
import 'package:alpha_suite_erp/core/router/route_guards.dart';
import 'package:alpha_suite_erp/providers/auth_providers.dart';
import 'package:alpha_suite_erp/screens/auth/login_view.dart';
import 'package:alpha_suite_erp/screens/auth/splash_view.dart';
import 'package:alpha_suite_erp/screens/crm/crm_view.dart';
import 'package:alpha_suite_erp/screens/dashboard/dashboard_view.dart';
import 'package:alpha_suite_erp/screens/hr/hr_view.dart';
import 'package:alpha_suite_erp/screens/inventory/inventory_view.dart';
import 'package:alpha_suite_erp/screens/sales/sales_view.dart';
import 'package:alpha_suite_erp/services/permission_service.dart';
import 'package:alpha_suite_erp/layouts/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final role = ref.watch(roleProvider);
  final permissionService = ref.watch(permissionServiceProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashView(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginView(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.inventory,
            builder: (context, state) => const InventoryView(),
          ),
          GoRoute(
            path: AppRoutes.sales,
            builder: (context, state) => const SalesView(),
          ),
          GoRoute(
            path: AppRoutes.crm,
            builder: (context, state) => const CrmView(),
          ),
          GoRoute(
            path: AppRoutes.hr,
            builder: (context, state) => const HrView(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final currentRoute = state.matchedLocation;
      final isLoginRoute = currentRoute == AppRoutes.login;
      final isSplashRoute = currentRoute == AppRoutes.splash;

      if (isSplashRoute) {
        return null;
      }

      final isAuthenticated = AuthGuard.canActivate(authState);
      if (!isAuthenticated && !isLoginRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isLoginRoute) {
        return AppRoutes.dashboard;
      }

      if (isAuthenticated) {
        final canAccess = RoleGuard.canActivate(
          permissionService: permissionService,
          role: role,
          route: currentRoute,
        );

        if (!canAccess) {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
  );
});
