import 'package:alpha_suite_erp/providers/auth_providers.dart';
import 'package:alpha_suite_erp/services/permission_service.dart';

class AuthGuard {
  static bool canActivate(AuthState authState) {
    return authState.isAuthenticated;
  }
}

class RoleGuard {
  static bool canActivate({
    required PermissionService permissionService,
    required UserRole? role,
    required String route,
  }) {
    return permissionService.canAccess(role: role, route: route);
  }
}
