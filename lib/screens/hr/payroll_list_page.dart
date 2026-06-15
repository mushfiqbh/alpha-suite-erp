import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/hr.dart';
import 'package:erp/providers/hr_providers.dart';

class PayrollListPage extends ConsumerStatefulWidget {
  const PayrollListPage({super.key, this.periodId});

  final String? periodId;

  @override
  ConsumerState<PayrollListPage> createState() => _PayrollListPageState();
}

class _PayrollListPageState extends ConsumerState<PayrollListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.periodId != null) {
        ref.read(payrollListProvider.notifier).setPeriodFilter(widget.periodId);
      } else {
        ref.read(payrollListProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollListProvider);
    final payrolls = state.payrolls;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Payroll Entries',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.periodId != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF1E3A8A)),
              tooltip: 'Generate all',
              onPressed: () => _confirmGenerate(context),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Color(0xFF1E3A8A)),
            tooltip: 'Add payroll entry',
            onPressed: () => context.push(AppRoutes.hrPayrollNew),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(payrollListProvider.notifier).refresh(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.errorMessage != null
            ? _ErrorView(
                message: state.errorMessage!,
                onRetry: () => ref.read(payrollListProvider.notifier).refresh(),
              )
            : payrolls.isEmpty
            ? _EmptyView(
                periodId: widget.periodId,
                onGenerate: widget.periodId != null
                    ? () => _confirmGenerate(context)
                    : null,
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payrolls.length,
                itemBuilder: (context, index) {
                  final payroll = payrolls[index];
                  return _PayrollCard(
                    payroll: payroll,
                    onEdit: () =>
                        context.push(AppRoutes.hrPayrollNew, extra: payroll),
                    onDelete: () => _confirmDelete(
                      context,
                      payroll: payroll,
                      onConfirm: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await ref
                            .read(payrollListProvider.notifier)
                            .deletePayroll(payroll.id!);
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Payroll entry deleted.'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _confirmGenerate(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Generate Payrolls?'),
        content: const Text(
          'This will create payroll entries for all active employees '
          'using their basic salary. Existing entries will not be duplicated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && widget.periodId != null) {
      // Fetch active employees
      try {
        // We need to get employees from state
        final empState = ref.read(employeeDirectoryProvider);
        final activeIds = empState.employees
            .where((e) => e.status == 'active')
            .map((e) => e.id!)
            .toList();

        if (activeIds.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active employees found.'),
                backgroundColor: Color(0xFFF59E0B),
              ),
            );
          }
          return;
        }

        await ref
            .read(payrollListProvider.notifier)
            .bulkGenerate(widget.periodId!, activeIds);
      } catch (_) {
        // Error handled by provider state
      }
    }
  }
}

Future<void> _confirmDelete(
  BuildContext context, {
  required PayrollRecord payroll,
  required Future<void> Function() onConfirm,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delete payroll entry?'),
      content: Text(
        'This will permanently delete the payroll entry for '
        '${payroll.employeeName ?? 'this employee'}. This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (result == true) {
    await onConfirm();
  }
}

// ===========================================================================
// Payroll Card
// ===========================================================================

class _PayrollCard extends StatelessWidget {
  const _PayrollCard({
    required this.payroll,
    required this.onEdit,
    required this.onDelete,
  });

  final PayrollRecord payroll;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = PaymentStatusOptions.color(payroll.paymentStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Container(
            width: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          payroll.employeeName ?? 'Unknown Employee',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        PaymentStatusOptions.label(payroll.paymentStatus),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  if (payroll.employeeCode != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      payroll.employeeCode!,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _Pill(
                        text: payroll.displayNetSalary,
                        color: const Color(0xFF1E3A8A),
                        bgColor: const Color(0xFFEEF2FF),
                      ),
                      const SizedBox(width: 4),
                      _Pill(
                        text:
                            'Gross: ₹${payroll.grossSalary.toStringAsFixed(2)}',
                        color: const Color(0xFF065F46),
                        bgColor: const Color(0xFFD1FAE5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CompactIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                const SizedBox(height: 2),
                _CompactIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    this.color = const Color(0xFF4338CA),
    this.bgColor = const Color(0xFFEEF2FF),
  });

  final String text;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: const Color(0xFF64748B), size: 14),
        ),
      ),
    );
  }
}

// ===========================================================================
// Empty / Error states
// ===========================================================================

class _EmptyView extends StatelessWidget {
  const _EmptyView({this.periodId, this.onGenerate});

  final String? periodId;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.payments_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No payroll entries',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              periodId != null
                  ? 'Generate payroll for all active employees, or add entries manually.'
                  : 'Select a payroll period to view entries.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            if (onGenerate != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onGenerate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate All'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
