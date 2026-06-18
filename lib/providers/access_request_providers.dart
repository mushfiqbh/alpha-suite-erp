import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:erp/models/access_request.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:erp/services/access_request_service.dart';

final accessRequestServiceProvider = Provider<AccessRequestService>((ref) {
  return AccessRequestService();
});

/// Provider for the viewer's own access requests.
final myAccessRequestsProvider =
    FutureProvider.autoDispose<List<AccessRequestRecord>>((ref) async {
      final userId = ref.watch(authProvider.select((s) => s.userId));
      if (userId.isEmpty) return [];

      final service = ref.watch(accessRequestServiceProvider);
      return service.listMyRequests(userId);
    });

/// Provider for all pending access requests (admin only).
final pendingAccessRequestsProvider =
    FutureProvider.autoDispose<List<AccessRequestRecord>>((ref) async {
      final role = ref.watch(authProvider.select((s) => s.role));
      if (role != UserRole.admin) return [];

      final service = ref.watch(accessRequestServiceProvider);
      return service.listPendingRequests();
    });

/// Provider for all requests (admin only).
final allAccessRequestsProvider =
    FutureProvider.autoDispose<List<AccessRequestRecord>>((ref) async {
      final role = ref.watch(authProvider.select((s) => s.role));
      if (role != UserRole.admin) return [];

      final service = ref.watch(accessRequestServiceProvider);
      return service.listAllRequests();
    });
