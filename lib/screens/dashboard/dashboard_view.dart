import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/sales_order.dart';
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
                children: const [
                  _GreetingHeader(),
                  SizedBox(height: 28),
                  _KpiGrid(),
                  SizedBox(height: 24),
                  SalesChartWidget(),
                  SizedBox(height: 24),
                  ActivityFeedWidget(),
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

    return Column(
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
          "Here's what's happening across your enterprise today.",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF464555),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  static String _greetingText(String? firstName) {
    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Good morning'
        : hour < 18
        ? 'Good afternoon'
        : 'Good evening';
    final name = (firstName == null || firstName.trim().isEmpty)
        ? 'there'
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
                  title: 'TOTAL SALES',
                  message: 'Unable to load',
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
                error: (_, __) => const _KpiError(
                  title: 'REVENUE',
                  message: 'Unable to load',
                ),
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
                  title: 'EMPLOYEES',
                  message: 'Unable to load',
                ),
                data: (count) => KpiCardWidget(
                  title: 'EMPLOYEES',
                  value: _formatCount(count),
                  description: 'Active in the system',
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
        ? 'This month'
        : (deltaPct >= 0
              ? '+${deltaPct.toString()}% this month'
              : '${deltaPct.toString()}% this month');
    final descriptionColor = deltaPct == null || deltaPct < 0
        ? const Color(0xFFB23B3B)
        : const Color(0xFF006C49);

    return KpiCardWidget(
      title: 'TOTAL SALES',
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
      title: 'REVENUE',
      value: _formatMoney(summary.thisMonthPaid),
      description: summary.thisMonthOrders == 0
          ? 'No sales yet'
          : 'Collected this month',
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
      return const _KpiError(title: 'LOW STOCK', message: 'Unable to load');
    }
    final outOfStock = state.products.where((p) => p.stock <= 0).length;
    final lowStockCount = state.products
        .where((p) => p.isLowStock && p.stock > 0)
        .length;
    final totalAlerts = lowStockCount + outOfStock;
    final description = StringBuffer();
    if (outOfStock > 0) {
      description.write(
        '$outOfStock out of stock${lowStockCount > 0 ? ', ' : ''}',
      );
    }
    if (lowStockCount > 0) {
      description.write('$lowStockCount low');
    }
    if (description.isEmpty) {
      description.write('No alerts');
    }
    final hasAlerts = totalAlerts > 0;
    return KpiCardWidget(
      title: 'LOW STOCK',
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
