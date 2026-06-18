import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/core/route_guards.dart';
import 'package:erp/models/customer.dart';
import 'package:erp/models/hr.dart';
import 'package:erp/models/product.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:erp/screens/customers/customer_form_page.dart';
import 'package:erp/screens/customers/customer_management_view.dart';
import 'package:erp/screens/products/product_form_page.dart';
import 'package:erp/screens/products/product_management_view.dart';
import 'package:erp/screens/products/stock_out_view.dart';
import 'package:erp/screens/auth/login_view.dart';
import 'package:erp/screens/auth/splash_view.dart';
import 'package:erp/screens/account/account_view.dart';
import 'package:erp/screens/account/dashboard_view.dart';
import 'package:erp/screens/hr/attendance_form_page.dart';
import 'package:erp/screens/hr/employee_form_page.dart';
import 'package:erp/screens/hr/hr_view.dart';
import 'package:erp/screens/hr/mark_attendance_page.dart';
import 'package:erp/screens/sales/pos_view.dart';
import 'package:erp/screens/sales/sales_list_view.dart';
import 'package:erp/screens/admin/users_management_view.dart';
import 'package:erp/screens/admin/access_requests_view.dart';
import 'package:erp/services/permission_service.dart';
import 'package:erp/layouts/app_shell.dart';

/// A [ChangeNotifier] that listens to Riverpod's [authProvider] and notifies
/// GoRouter to re-evaluate its redirect whenever auth state changes.
/// This keeps the GoRouter instance stable (never recreated) while still
/// reacting to login / logout events.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  AuthState get _authState => _ref.read(authProvider);
  UserRole? get _role => _ref.read(roleProvider);
  PermissionService get _permissions => _ref.read(permissionServiceProvider);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
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
            path: AppRoutes.sales,
            builder: (context, state) => const SalesListView(),
          ),
          GoRoute(
            path: AppRoutes.pos,
            builder: (context, state) => const PosView(),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomerManagementView(),
          ),
          GoRoute(
            path: AppRoutes.customerNew,
            builder: (context, state) => CustomerFormPage(
              existing: state.extra is CustomerRecord
                  ? state.extra as CustomerRecord
                  : null,
            ),
          ),
          GoRoute(
            path: AppRoutes.products,
            builder: (context, state) => const ProductManagementView(),
          ),
          GoRoute(
            path: AppRoutes.productNew,
            builder: (context, state) => ProductFormPage(
              existing: state.extra is ProductRecord
                  ? state.extra as ProductRecord
                  : null,
            ),
          ),
          GoRoute(
            path: AppRoutes.stockOut,
            builder: (context, state) => const StockOutView(),
          ),
          GoRoute(
            path: AppRoutes.hr,
            builder: (context, state) => const HrView(),
          ),
          GoRoute(
            path: AppRoutes.hrEmployeeNew,
            builder: (context, state) => EmployeeFormPage(
              existing: state.extra is EmployeeRecord
                  ? state.extra as EmployeeRecord
                  : null,
            ),
          ),
          GoRoute(
            path: AppRoutes.hrAttendanceNew,
            builder: (context, state) => const AttendanceFormPage(),
          ),
          GoRoute(
            path: AppRoutes.hrAttendanceMark,
            builder: (context, state) => const MarkAttendancePage(),
          ),
          GoRoute(
            path: AppRoutes.users,
            builder: (context, state) => const UsersManagementView(),
          ),
          GoRoute(
            path: AppRoutes.accessRequests,
            builder: (context, state) => const AccessRequestsView(),
          ),
          GoRoute(
            path: AppRoutes.account,
            builder: (context, state) => const AccountView(),
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

      final authState = notifier._authState;
      final isAuthenticated = AuthGuard.canActivate(authState);

      if (!isAuthenticated && !isLoginRoute) {
        return AppRoutes.login;
      }

      if (isAuthenticated && isLoginRoute) {
        return AppRoutes.dashboard;
      }

      if (isAuthenticated) {
        final canAccess = RoleGuard.canActivate(
          permissionService: notifier._permissions,
          role: notifier._role,
          route: currentRoute,
        );

        if (!canAccess) {
          return AppRoutes.dashboard;
        }
      }

      return null;
    },
  );

  // Dispose the notifier when the provider is disposed.
  ref.onDispose(notifier.dispose);

  return router;
});
