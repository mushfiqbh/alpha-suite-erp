import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/hr.dart';
import 'package:erp/providers/hr_providers.dart';
import 'package:erp/screens/hr/attendance_form_page.dart';
import 'package:erp/screens/hr/mark_attendance_page.dart';

class HrView extends ConsumerStatefulWidget {
  const HrView({super.key});

  @override
  ConsumerState<HrView> createState() => _HrViewState();
}

class _HrViewState extends ConsumerState<HrView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF1E3A8A),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF4F46E5),
            indicatorWeight: 3,
            labelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(
                icon: Icon(Icons.badge_outlined, size: 18),
                text: 'Employees',
              ),
              Tab(
                icon: Icon(Icons.table_chart_outlined, size: 18),
                text: 'Attendance Sheet',
              ),
              Tab(
                icon: Icon(Icons.person_add_alt_1_rounded, size: 18),
                text: 'Attend',
              ),
              Tab(
                icon: Icon(Icons.payments_outlined, size: 18),
                text: 'Payroll',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _EmployeesTab(),
              _BulkAttendanceTab(),
              _IndividualAttendanceTab(),
              _PayrollTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Employees tab
// ===========================================================================

class _EmployeesTab extends ConsumerStatefulWidget {
  const _EmployeesTab();

  @override
  ConsumerState<_EmployeesTab> createState() => _EmployeesTabState();
}

class _EmployeesTabState extends ConsumerState<_EmployeesTab> {
  int _page = 0;
  static const int _rowsPerPage = 9;

  List<EmployeeRecord> _filter(EmployeeDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();
    final status = state.statusFilter;
    final dept = state.departmentFilter;
    return state.employees.where((e) {
      if (status != null && e.status.toLowerCase() != status.toLowerCase()) {
        return false;
      }
      if (dept != null &&
          (e.department ?? '').toLowerCase() != dept.toLowerCase()) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return e.fullName.toLowerCase().contains(query) ||
          e.employeeCode.toLowerCase().contains(query) ||
          (e.email ?? '').toLowerCase().contains(query) ||
          (e.phone ?? '').toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeDirectoryProvider);
    final filtered = _filter(state);
    final totalPages = filtered.isEmpty
        ? 0
        : (filtered.length / _rowsPerPage).ceil();
    final safePage = totalPages == 0 ? 0 : math.min(_page, totalPages - 1);
    final pageStart = filtered.isEmpty ? 0 : safePage * _rowsPerPage + 1;
    final pageEnd = filtered.isEmpty
        ? 0
        : math.min(pageStart + _rowsPerPage - 1, filtered.length);
    final visible = filtered.isEmpty
        ? const <EmployeeRecord>[]
        : filtered.sublist(
            pageStart - 1,
            math.min(pageStart - 1 + _rowsPerPage, filtered.length),
          );

    return _TabShell(
      searchQuery: state.searchQuery,
      onSearch: (v) =>
          ref.read(employeeDirectoryProvider.notifier).setSearchQuery(v),
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
      onRefresh: () => ref.read(employeeDirectoryProvider.notifier).refresh(),
      filterContent: const SizedBox.shrink(),
      activeFilterChips: const <Widget>[],
      summary: filtered.isEmpty
          ? (state.isLoading ? 'Loading employees...' : 'No employees found')
          : 'Showing $pageStart-$pageEnd of ${filtered.length} employees',
      isEmpty: filtered.isEmpty,
      emptyTitle: 'No employees yet',
      emptyMessage:
          'Add your first employee to start building your team. They\'ll appear here once saved.',
      onCreate: () => context.push(AppRoutes.hrEmployeeNew),
      gridBuilder: (crossAxisCount) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 80,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final employee = visible[index];
          return _EmployeeCard(
            employee: employee,
            departmentName: employee.department,
            designationTitle: employee.designation,
            onEdit: () =>
                context.push(AppRoutes.hrEmployeeNew, extra: employee),
            onDelete: () => _confirmDelete(
              context,
              title: 'Delete employee?',
              message:
                  'This will permanently delete ${employee.fullName}. This action cannot be undone.',
              onConfirm: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller = ref.read(employeeDirectoryProvider.notifier);
                await controller.deleteEmployee(employee.id!);
                if (!mounted) return;
                final latest = ref.read(employeeDirectoryProvider);
                if (latest.errorMessage == null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${employee.fullName} deleted.'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(latest.errorMessage!),
                      backgroundColor: Colors.red.shade600,
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
      pagination: _PaginationBar(
        currentPage: safePage,
        totalPages: totalPages,
        totalItems: filtered.length,
        onPreviousPage: totalPages == 0 || safePage == 0
            ? null
            : () => setState(() => _page = safePage - 1),
        onNextPage: totalPages == 0 || safePage >= totalPages - 1
            ? null
            : () => setState(() => _page = safePage + 1),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.departmentName,
    required this.designationTitle,
    required this.onEdit,
    required this.onDelete,
  });

  final EmployeeRecord employee;
  final String? departmentName;
  final String? designationTitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = EmployeeStatusOptions.color(employee.status);
    return Container(
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
            child: Icon(Icons.badge_outlined, color: Colors.white, size: 18),
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
                          employee.fullName,
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
                        EmployeeStatusOptions.label(employee.status),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    employee.employeeCode,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (departmentName != null || designationTitle != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (departmentName != null) ...[
                          _Pill(text: departmentName!),
                          const SizedBox(width: 4),
                        ],
                        if (designationTitle != null)
                          _Pill(text: designationTitle!),
                      ],
                    ),
                  ],
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

// ===========================================================================
// Bulk Attendance tab — inline sheet
// ===========================================================================

class _BulkAttendanceTab extends StatelessWidget {
  const _BulkAttendanceTab();

  @override
  Widget build(BuildContext context) {
    return const AttendanceFormPage(embedded: true);
  }
}

// ===========================================================================
// Individual Attendance tab — inline form
// ===========================================================================

class _IndividualAttendanceTab extends StatelessWidget {
  const _IndividualAttendanceTab();

  @override
  Widget build(BuildContext context) {
    return const MarkAttendancePage(embedded: true);
  }
}

// ===========================================================================
// Shared widgets
// ===========================================================================

class SearchBarSection extends StatelessWidget {
  const SearchBarSection({
    super.key,
    required this.searchQuery,
    required this.hintText,
    required this.onSearchChanged,
  });

  final String searchQuery;
  final String hintText;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF94A3B8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.collapsed(
                  offset: searchQuery.length,
                ),
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
              onPressed: () => onSearchChanged(''),
              tooltip: 'Clear',
            ),
        ],
      ),
    );
  }
}

class _TabShell extends StatelessWidget {
  const _TabShell({
    required this.searchQuery,
    required this.onSearch,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
    required this.onRefresh,
    required this.filterContent,
    required this.activeFilterChips,
    required this.summary,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onCreate,
    required this.gridBuilder,
    required this.pagination,
  });

  final String searchQuery;
  final ValueChanged<String> onSearch;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final Widget filterContent;
  final List<Widget> activeFilterChips;
  final String summary;
  final bool isEmpty;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback onCreate;
  final Widget Function(int crossAxisCount) gridBuilder;
  final Widget pagination;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SearchBarSection(
              searchQuery: searchQuery,
              hintText: 'Search by name, code, email, or shift...',
              onSearchChanged: onSearch,
            ),
          ),
          if (filterContent is! SizedBox ||
              (filterContent as SizedBox).child != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: filterContent,
            ),
          if (activeFilterChips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeFilterChips,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFB91C1C),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isEmpty && !isLoading)
            _EmptyState(
              title: emptyTitle,
              message: emptyMessage,
              onCreate: onCreate,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1120
                    ? 3
                    : (width >= 720 ? 2 : 1);
                return gridBuilder(crossAxisCount);
              },
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: pagination,
          ),
          if (isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
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

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4338CA),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.onCreate,
  });

  final String title;
  final String message;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
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
              Icons.inbox_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            totalItems == 0
                ? '0 results'
                : 'Page ${currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous',
              ),
              IconButton(
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Text(message),
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
// Payroll tab — periods list
// ===========================================================================

class _PayrollTab extends ConsumerStatefulWidget {
  const _PayrollTab();

  @override
  ConsumerState<_PayrollTab> createState() => _PayrollTabState();
}

class _PayrollTabState extends ConsumerState<_PayrollTab> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(payrollPeriodListProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollPeriodListProvider);
    final periods = state.periods;

    return RefreshIndicator(
      onRefresh: () => ref.read(payrollPeriodListProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  periods.isEmpty
                      ? 'No payroll periods yet'
                      : '${periods.length} payroll period${periods.length == 1 ? '' : 's'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (state.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.hrPayrollPeriodNew),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Period'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  textStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFB91C1C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (periods.isEmpty && !state.isLoading)
            _EmptyPayrollState(
              onCreate: () => context.push(AppRoutes.hrPayrollPeriodNew),
            )
          else
            ...periods.map(
              (period) => _PayrollPeriodCard(
                period: period,
                onView: () =>
                    context.push(AppRoutes.hrPayrollList, extra: period.id),
                onEdit: () =>
                    context.push(AppRoutes.hrPayrollPeriodNew, extra: period),
                onDelete: () => _confirmDeletePeriod(context, period),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletePeriod(
    BuildContext context,
    PayrollPeriodRecord period,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete period?'),
        content: Text(
          'This will permanently delete the ${period.periodLabel} period '
          'and all associated payroll entries. This cannot be undone.',
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
      final messenger = ScaffoldMessenger.of(context);
      await ref
          .read(payrollPeriodListProvider.notifier)
          .deletePeriod(period.id!);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${period.periodLabel} deleted.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }
}

class _PayrollPeriodCard extends StatelessWidget {
  const _PayrollPeriodCard({
    required this.period,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final PayrollPeriodRecord period;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = PayrollPeriodStatusOptions.color(period.status);
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
      child: InkWell(
        onTap: onView,
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
                Icons.calendar_month_outlined,
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
                            period.periodLabel,
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
                          PayrollPeriodStatusOptions.label(period.status),
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    if (period.startDate != null && period.endDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_fmtDate(period.startDate!)} — ${_fmtDate(period.endDate!)}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompactIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 2),
                  _CompactIconButton(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete',
                    onPressed: onDelete,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _EmptyPayrollState extends StatelessWidget {
  const _EmptyPayrollState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
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
            'No payroll periods',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a payroll period to start managing employee payroll.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create Period'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
            ),
          ),
        ],
      ),
    );
  }
}
