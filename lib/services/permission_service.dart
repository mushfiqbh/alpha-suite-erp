import 'package:alpha_suite_erp/core/constants/app_routes.dart';
import 'package:alpha_suite_erp/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central RBAC policy map. Expand this as modules and permissions grow.
class PermissionService {
  static const Map<UserRole, Set<String>> _routeAccess = {
    UserRole.admin: {
      AppRoutes.dashboard,
      AppRoutes.inventory,
      AppRoutes.sales,
      AppRoutes.crm,
      AppRoutes.hr,
    },
    UserRole.operations: {
      AppRoutes.dashboard,
      AppRoutes.inventory,
      AppRoutes.sales,
    },
    UserRole.sales: {AppRoutes.dashboard, AppRoutes.sales, AppRoutes.crm},
    UserRole.hr: {AppRoutes.dashboard, AppRoutes.hr},
    UserRole.viewer: {AppRoutes.dashboard},
  };

  bool canAccess({required UserRole? role, required String route}) {
    if (role == null) {
      return false;
    }

    return _routeAccess[role]?.contains(route) ?? false;
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});
