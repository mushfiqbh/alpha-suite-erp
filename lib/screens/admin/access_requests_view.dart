import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/access_request.dart';
import 'package:erp/providers/access_request_providers.dart';
import 'package:erp/providers/auth_providers.dart';

class AccessRequestsView extends ConsumerWidget {
  const AccessRequestsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);

    if (role != UserRole.admin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9FF),
        appBar: AppBar(
          title: const Text('Access Requests'),
          backgroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('You do not have permission to view this page.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        title: const Text('Access Requests'),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      body: const _RequestsBody(),
    );
  }
}

class _RequestsBody extends ConsumerWidget {
  const _RequestsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allAsync = ref.watch(allAccessRequestsProvider);

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No access requests yet',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        // Sort: pending first, then approved, then rejected
        final sorted = List<AccessRequestRecord>.from(requests)
          ..sort((a, b) {
            const order = {'pending': 0, 'approved': 1, 'rejected': 2};
            final oa = order[a.status.toLowerCase()] ?? 3;
            final ob = order[b.status.toLowerCase()] ?? 3;
            return oa.compareTo(ob);
          });

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...sorted.map(
                (req) => _RequestCard(
                  request: req,
                  onApprove: req.isPending
                      ? () => _handleApprove(ref, context, req)
                      : null,
                  onReject: req.isPending
                      ? () => _handleReject(ref, context, req)
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleApprove(
    WidgetRef ref,
    BuildContext context,
    AccessRequestRecord request,
  ) async {
    final service = ref.read(accessRequestServiceProvider);
    final userId = ref.read(authProvider.select((s) => s.userId));
    if (userId.isEmpty) return;

    try {
      await service.approveRequest(
        requestId: request.id!,
        reviewerId: userId,
        userId: request.userId,
        role: request.requestedRole,
      );
      ref.invalidate(allAccessRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Approved ${request.requestedRole.toUpperCase()} request',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleReject(
    WidgetRef ref,
    BuildContext context,
    AccessRequestRecord request,
  ) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to reject this request?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final service = ref.read(accessRequestServiceProvider);
    final userId = ref.read(authProvider.select((s) => s.userId));
    if (userId.isEmpty) return;

    try {
      await service.rejectRequest(
        requestId: request.id!,
        reviewerId: userId,
        reason: reasonController.text.trim(),
      );
      ref.invalidate(allAccessRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request rejected')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, this.onApprove, this.onReject});

  final AccessRequestRecord request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = switch (request.status.toLowerCase()) {
      'pending' => const Color(0xFFF5A623),
      'approved' => const Color(0xFF006C49),
      'rejected' => const Color(0xFFB23B3B),
      _ => Colors.grey,
    };
    final statusBgColor = switch (request.status.toLowerCase()) {
      'pending' => const Color(0xFFFFF3E0),
      'approved' => const Color(0xFFE8F5E9),
      'rejected' => const Color(0xFFFFEBEE),
      _ => Colors.grey.shade100,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC7C4D8).withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF0FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.requestedRole.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF151C27),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.userName ?? 'Unknown User',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF151C27),
            ),
          ),
          Text(
            request.userEmail ?? '',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF464555),
            ),
          ),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              request.notes!,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF7C7A93),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            _formatDate(request.createdAt),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF7C7A93),
            ),
          ),
          if (request.isPending && onApprove != null && onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB23B3B),
                    side: const BorderSide(color: Color(0xFFB23B3B)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF006C49),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
