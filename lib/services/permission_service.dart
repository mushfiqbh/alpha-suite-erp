import 'package:erp/core/app_routes.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Central RBAC policy map. Expand this as modules and permissions grow.
class PermissionService {
  static const Map<UserRole, Set<String>> _routeAccess = {
    UserRole.admin: {
      AppRoutes.dashboard,
      AppRoutes.inventory,
      AppRoutes.sales,
      AppRoutes.pos,
      AppRoutes.crm,
      AppRoutes.customers,
      AppRoutes.customerNew,
      AppRoutes.products,
      AppRoutes.productNew,
      AppRoutes.hr,
      AppRoutes.hrEmployeeNew,
      AppRoutes.hrDepartmentNew,
      AppRoutes.hrDesignationNew,
      AppRoutes.hrShiftNew,
      AppRoutes.hrEmployeeShiftNew,
      AppRoutes.hrAttendanceNew,
      AppRoutes.hrLeaveTypeNew,
      AppRoutes.hrLeaveRequestNew,
      AppRoutes.hrHolidayNew,
      AppRoutes.users,
    },
    UserRole.operations: {
      AppRoutes.dashboard,
      AppRoutes.inventory,
      AppRoutes.sales,
      AppRoutes.pos,
      AppRoutes.crm,
      AppRoutes.customers,
      AppRoutes.customerNew,
      AppRoutes.products,
      AppRoutes.productNew,
    },
    UserRole.sales: {
      AppRoutes.dashboard,
      AppRoutes.sales,
      AppRoutes.pos,
      AppRoutes.crm,
      AppRoutes.customers,
      AppRoutes.customerNew,
      AppRoutes.products,
      AppRoutes.productNew,
    },
    UserRole.hr: {
      AppRoutes.dashboard,
      AppRoutes.hr,
      AppRoutes.hrEmployeeNew,
      AppRoutes.hrDepartmentNew,
      AppRoutes.hrDesignationNew,
      AppRoutes.hrShiftNew,
      AppRoutes.hrEmployeeShiftNew,
      AppRoutes.hrAttendanceNew,
      AppRoutes.hrLeaveTypeNew,
      AppRoutes.hrLeaveRequestNew,
      AppRoutes.hrHolidayNew,
    },
    UserRole.viewer: {AppRoutes.dashboard},
  };

  bool canAccess({required UserRole? role, required String route}) {
    if (role == null) {
      return false;
    }

    if (route == AppRoutes.account) {
      return true;
    }

    return _routeAccess[role]?.contains(route) ?? false;
  }

  /// True when the role can author HR records (employees, departments,
  /// designations, shifts, assignments). Admin and HR have full access;
  /// everyone else is read-only.
  bool canManageHr({required UserRole? role}) {
    return role == UserRole.admin || role == UserRole.hr;
  }
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});
