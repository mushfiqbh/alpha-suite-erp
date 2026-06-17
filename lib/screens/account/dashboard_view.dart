import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/access_request.dart';
import 'package:erp/models/sales_order.dart';
import 'package:erp/providers/access_request_providers.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:erp/providers/hr_providers.dart';
import 'package:erp/providers/product_providers.dart';
import 'package:erp/providers/sales_providers.dart';
import 'package:erp/services/permission_service.dart';
import 'package:erp/widgets/activity_feed.dart';
import 'package:erp/widgets/kpi_card.dart';
import 'package:erp/widgets/sales_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final isViewer = role == UserRole.viewer;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GreetingHeader(),
                  const SizedBox(height: 20),
                  const _AccessRequestSection(),
                  if (!isViewer) ...[
                    const SizedBox(height: 20),
                    const _KpiGrid(),
                    const SizedBox(height: 24),
                    const SalesChartWidget(),
                    const SizedBox(height: 24),
                    const ActivityFeedWidget(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final fullName = profileAsync.maybeWhen(
      data: (profile) => profile?.fullName,
      orElse: () => null,
    );
    final firstName = _firstNameFrom(fullName);
    final role = ref.watch(roleProvider);
    final pendingAsync = ref.watch(pendingAccessRequestsProvider);
    final pendingCount = pendingAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingText(firstName),
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                  color: const Color(0xFF151C27),
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "আজ আপনার এন্টারপ্রাইজে কী ঘটছে তা দেখুন।",
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF464555),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        if (role == UserRole.admin) ...[
          const SizedBox(width: 12),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                color: const Color(0xFF464555),
                onPressed: () => context.go(AppRoutes.accessRequests),
              ),
              if (pendingCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB23B3B),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      pendingCount > 9 ? '9+' : '$pendingCount',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _greetingText(String? firstName) {
    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'সুপ্রভাত'
        : hour < 18
        ? 'শুভ অপরাহ্ন'
        : 'শুভ সন্ধ্যা';
    final name = (firstName == null || firstName.trim().isEmpty)
        ? 'আপনি'
        : firstName.trim();
    return '$salutation, $name';
  }

  static String? _firstNameFrom(String? fullName) {
    if (fullName == null) return null;
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return null;
    final firstPart = trimmed.split(RegExp(r'\s+')).first;
    return firstPart.isEmpty ? null : firstPart;
  }
}

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(revenueSummaryProvider);
    final productsState = ref.watch(productDirectoryProvider);
    final employeesAsync = ref.watch(activeHrEmployeeCountProvider);
    final role = ref.watch(roleProvider);
    final permissionService = ref.watch(permissionServiceProvider);
    final canAccessHr = permissionService.canAccess(
      role: role,
      route: AppRoutes.hr,
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: revenueAsync.when(
                loading: () => const _KpiSkeleton(),
                error: (_, __) => const _KpiError(
                  title: 'মোট বিক্রয়',
                  message: 'লোড করা যায়নি',
                ),
                data: (summary) => _buildTotalSalesKpi(
                  summary,
                  onTap: () => context.push(AppRoutes.sales),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: revenueAsync.when(
                loading: () => const _KpiSkeleton(),
                error: (_, __) =>
                    const _KpiError(title: 'রাজস্ব', message: 'লোড করা যায়নি'),
                data: (summary) => _buildRevenueKpi(summary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: employeesAsync.when(
                loading: () => const _KpiSkeleton(),
                error: (_, __) => const _KpiError(
                  title: 'কর্মচারী',
                  message: 'লোড করা যায়নি',
                ),
                data: (count) => KpiCardWidget(
                  title: 'কর্মচারী',
                  value: _formatCount(count),
                  description: 'সিস্টেমে সক্রিয়',
                  descriptionColor: const Color(0xFF464555),
                  icon: _EmployeesIcon(),
                  onTap: canAccessHr ? () => context.push(AppRoutes.hr) : null,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: _buildLowStockKpi(productsState, context)),
          ],
        ),
      ],
    );
  }

  static Widget _buildTotalSalesKpi(
    DashboardRevenueSummary summary, {
    VoidCallback? onTap,
  }) {
    final hasPrev = summary.previousMonthTotal > 0;
    final deltaPct = hasPrev
        ? ((summary.thisMonthTotal - summary.previousMonthTotal) /
                  summary.previousMonthTotal *
                  100)
              .round()
        : null;
    final description = deltaPct == null
        ? 'এই মাসে'
        : (deltaPct >= 0
              ? '+${deltaPct.toString()}% এই মাসে'
              : '${deltaPct.toString()}% এই মাসে');
    final descriptionColor = deltaPct == null || deltaPct < 0
        ? const Color(0xFFB23B3B)
        : const Color(0xFF006C49);

    return KpiCardWidget(
      title: 'মোট বিক্রয়',
      value: _formatMoney(summary.thisMonthTotal),
      description: description,
      descriptionColor: descriptionColor,
      icon: _SalesIcon(),
      onTap: onTap,
      trendWidget: deltaPct != null && deltaPct >= 0
          ? const _TrendArrow(up: true)
          : (deltaPct != null ? const _TrendArrow(up: false) : null),
    );
  }

  static Widget _buildRevenueKpi(DashboardRevenueSummary summary) {
    return KpiCardWidget(
      title: 'রাজস্ব',
      value: _formatMoney(summary.thisMonthPaid),
      description: summary.thisMonthOrders == 0
          ? 'এখনো কোনো বিক্রয় নেই'
          : 'এই মাসে সংগ্রহ',
      descriptionColor: const Color(0xFF464555),
      icon: _RevenueIcon(),
    );
  }

  static Widget _buildLowStockKpi(
    ProductDirectoryState state,
    BuildContext context,
  ) {
    if (state.isLoading) return const _KpiSkeleton();
    if (state.errorMessage != null && state.products.isEmpty) {
      return const _KpiError(title: 'স্টক সীমিত', message: 'লোড করা যায়নি');
    }
    final outOfStock = state.products.where((p) => p.stock <= 0).length;
    final lowStockCount = state.products
        .where((p) => p.isLowStock && p.stock > 0)
        .length;
    final totalAlerts = lowStockCount + outOfStock;
    final description = StringBuffer();
    if (outOfStock > 0) {
      description.write(
        '$outOfStock স্টকে নেই${lowStockCount > 0 ? ', ' : ''}',
      );
    }
    if (lowStockCount > 0) {
      description.write('$lowStockCount সীমিত');
    }
    if (description.isEmpty) {
      description.write('কোনো সতর্কতা নেই');
    }
    final hasAlerts = totalAlerts > 0;
    return KpiCardWidget(
      title: 'স্টক সীমিত',
      value: _formatCount(totalAlerts),
      description: description.toString(),
      descriptionColor: hasAlerts
          ? const Color(0xFFB23B3B)
          : const Color(0xFF464555),
      icon: _LowStockIcon(),
      onTap: () => context.push(AppRoutes.stockOut),
    );
  }
}

/// Access request section shown only for viewer-role users.
class _AccessRequestSection extends ConsumerWidget {
  const _AccessRequestSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    if (role != UserRole.viewer) return const SizedBox.shrink();

    final myRequestsAsync = ref.watch(myAccessRequestsProvider);
    final pendingRequest = myRequestsAsync.maybeWhen(
      data: (list) {
        try {
          return list.firstWhere((r) => r.isPending);
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );
    final hasPendingRequest = pendingRequest != null;
    final previousRequests = myRequestsAsync.maybeWhen(
      data: (list) => list.where((r) => !r.isPending).toList(),
      orElse: () => <AccessRequestRecord>[],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        width: double.infinity,
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
            Text(
              'অ্যাক্সেসের অনুরোধ',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF151C27),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'অতিরিক্ত মডিউল অ্যাক্সেসের অনুরোধ করুন',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF464555),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AccessButton(
                    label: 'অপারেশনস',
                    icon: Icons.inventory_2_outlined,
                    onPressed: hasPendingRequest
                        ? null
                        : () => _submitRequest(ref, context, 'operations'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AccessButton(
                    label: 'ম্যানেজার',
                    icon: Icons.people_outline,
                    onPressed: hasPendingRequest
                        ? null
                        : () => _submitRequest(ref, context, 'hr'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AccessButton(
                    label: 'সেলস',
                    icon: Icons.shopping_cart_outlined,
                    onPressed: hasPendingRequest
                        ? null
                        : () => _submitRequest(ref, context, 'sales'),
                  ),
                ),
              ],
            ),
            if (hasPendingRequest) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '${pendingRequest.requestedRole.toUpperCase()} অ্যাক্সেসের অনুরোধ pending. অ্যাডমিনের অনুমোদনের জন্য অপেক্ষা করুন।',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFF5A623),
                  ),
                ),
              ),
            ],
            if (previousRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'পূর্ববর্তী অনুরোধ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF464555),
                ),
              ),
              const SizedBox(height: 8),
              ...previousRequests.map(
                (req) => _PreviousRequestTile(request: req),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitRequest(
    WidgetRef ref,
    BuildContext context,
    String role,
  ) async {
    final service = ref.read(accessRequestServiceProvider);
    final userId = ref.read(authProvider.select((s) => s.userId));
    if (userId.isEmpty) return;

    try {
      await service.submitRequest(userId: userId, requestedRole: role);
      ref.invalidate(myAccessRequestsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$role অ্যাক্সেসের অনুরোধ জমা দেওয়া হয়েছে')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('ত্রুটি: $e')));
      }
    }
  }
}

class _PreviousRequestTile extends StatelessWidget {
  const _PreviousRequestTile({required this.request});

  final AccessRequestRecord request;

  @override
  Widget build(BuildContext context) {
    final statusColor = request.isApproved
        ? const Color(0xFF006C49)
        : const Color(0xFFB23B3B);
    final icon = request.isApproved ? Icons.check_circle : Icons.cancel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: statusColor),
          const SizedBox(width: 8),
          Text(
            request.requestedRole.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF151C27),
            ),
          ),
          const Spacer(),
          Text(
            request.isApproved ? 'অনুমোদিত' : 'প্রত্যাখ্যাত',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessButton extends StatelessWidget {
  const _AccessButton({
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC7C4D8).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _KpiError extends StatelessWidget {
  final String title;
  final String message;
  const _KpiError({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return KpiCardWidget(
      title: title,
      value: '—',
      description: message,
      descriptionColor: const Color(0xFFB23B3B),
      icon: const _LowStockIcon(),
    );
  }
}

String _formatMoney(double value) {
  if (value >= 1000000) {
    return '৳${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    final k = value / 1000;
    return '৳${k.toStringAsFixed(k >= 100 ? 0 : 1)}k';
  }
  return '৳${value.toStringAsFixed(0)}';
}

String _formatCount(int value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}k';
  }
  return value.toString();
}

class _SalesIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.trending_up_rounded,
        size: 16,
        color: Color(0xFF2E7D32),
      ),
    );
  }
}

class _RevenueIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.account_balance_wallet_outlined,
        size: 16,
        color: Color(0xFF6A1B9A),
      ),
    );
  }
}

class _EmployeesIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.people_outline_rounded,
        size: 16,
        color: Color(0xFF1565C0),
      ),
    );
  }
}

class _LowStockIcon extends StatelessWidget {
  const _LowStockIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(
        Icons.warning_amber_rounded,
        size: 16,
        color: Color(0xFFF57F17),
      ),
    );
  }
}

class _TrendArrow extends StatelessWidget {
  final bool up;
  const _TrendArrow({this.up = true});

  @override
  Widget build(BuildContext context) {
    return Icon(
      up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
      size: 14,
      color: up ? const Color(0xFF006C49) : const Color(0xFFB23B3B),
    );
  }
}
