import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/attendance.dart';
import 'package:erp/models/holiday.dart';
import 'package:erp/models/hr.dart';
import 'package:erp/models/leave.dart';
import 'package:erp/models/shift.dart';
import 'package:erp/providers/attendance_providers.dart';
import 'package:erp/providers/holiday_providers.dart';
import 'package:erp/providers/hr_providers.dart';
import 'package:erp/providers/leave_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    _tabController = TabController(length: 7, vsync: this);
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
                icon: Icon(Icons.schedule_outlined, size: 18),
                text: 'Shifts',
              ),
              Tab(
                icon: Icon(Icons.assignment_ind_outlined, size: 18),
                text: 'Assignments',
              ),
              Tab(
                icon: Icon(Icons.fact_check_outlined, size: 18),
                text: 'Attendance',
              ),
              Tab(
                icon: Icon(Icons.beach_access_outlined, size: 18),
                text: 'Leave Types',
              ),
              Tab(
                icon: Icon(Icons.event_busy_outlined, size: 18),
                text: 'Leave Requests',
              ),
              Tab(
                icon: Icon(Icons.celebration_outlined, size: 18),
                text: 'Holidays',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _EmployeesTab(),
              _ShiftsTab(),
              _AssignmentsTab(),
              _AttendanceTab(),
              _LeaveTypesTab(),
              _LeaveRequestsTab(),
              _HolidaysTab(),
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
      filterContent: Row(
        children: [
          _FilterDropdown<String?>(
            value: state.statusFilter,
            label: 'Status',
            items: const [
              DropdownMenuItem(value: null, child: Text('All statuses')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
              DropdownMenuItem(value: 'terminated', child: Text('Terminated')),
            ],
            onChanged: (v) =>
                ref.read(employeeDirectoryProvider.notifier).setStatusFilter(v),
          ),
          const SizedBox(width: 8),
          _FilterDropdown<String?>(
            value: state.departmentFilter,
            label: 'Department',
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All departments'),
              ),
              ...state.employees
                  .map((e) => e.department)
                  .where((d) => d != null && d.isNotEmpty)
                  .map((d) => d!)
                  .toSet()
                  .map(
                    (d) => DropdownMenuItem<String?>(
                      value: d,
                      child: Text(d, overflow: TextOverflow.ellipsis),
                    ),
                  ),
            ],
            onChanged: (v) => ref
                .read(employeeDirectoryProvider.notifier)
                .setDepartmentFilter(v),
          ),
        ],
      ),
      activeFilterChips: [
        if (state.statusFilter != null)
          _ActiveFilterChip(
            label:
                'Status: ${EmployeeStatusOptions.label(state.statusFilter!)}',
            onClear: () => ref
                .read(employeeDirectoryProvider.notifier)
                .setStatusFilter(null),
          ),
        if (state.departmentFilter != null)
          _ActiveFilterChip(
            label: 'Dept: ${state.departmentFilter}',
            onClear: () => ref
                .read(employeeDirectoryProvider.notifier)
                .setDepartmentFilter(null),
          ),
      ],
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
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 168,
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
    return _EntityCard(
      gradient: const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      icon: Icons.person_outline,
      identity: _CardIdentity(
        title: employee.fullName,
        subtitle: employee.employeeCode,
        initials: employee.initials,
      ),
      badges: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                EmployeeStatusOptions.label(employee.status),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        if (departmentName != null) _Pill(text: departmentName!),
        if (designationTitle != null) _Pill(text: designationTitle!),
      ],
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

// ===========================================================================
// Shifts tab
// ===========================================================================

class _ShiftsTab extends ConsumerStatefulWidget {
  const _ShiftsTab();

  @override
  ConsumerState<_ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends ConsumerState<_ShiftsTab> {
  int _page = 0;
  static const int _rowsPerPage = 9;

  List<ShiftRecord> _filter(ShiftDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();
    return state.shifts.where((s) {
      if (query.isEmpty) return true;
      return s.shiftName.toLowerCase().contains(query) ||
          s.displayWindow.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shiftDirectoryProvider);
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
        ? const <ShiftRecord>[]
        : filtered.sublist(
            pageStart - 1,
            math.min(pageStart - 1 + _rowsPerPage, filtered.length),
          );

    return _TabShell(
      searchQuery: state.searchQuery,
      onSearch: (v) =>
          ref.read(shiftDirectoryProvider.notifier).setSearchQuery(v),
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
      onRefresh: () => ref.read(shiftDirectoryProvider.notifier).refresh(),
      filterContent: const SizedBox.shrink(),
      activeFilterChips: const [],
      summary: filtered.isEmpty
          ? (state.isLoading ? 'Loading shifts...' : 'No shifts found')
          : 'Showing $pageStart-$pageEnd of ${filtered.length} shifts',
      isEmpty: filtered.isEmpty,
      emptyTitle: 'No shifts yet',
      emptyMessage:
          'Shifts define working hours and grace periods. Add one to schedule your team.',
      onCreate: () => context.push(AppRoutes.hrShiftNew),
      gridBuilder: (crossAxisCount) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 150,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final s = visible[index];
          return _EntityCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF312E81), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.schedule_outlined,
            identity: _CardIdentity(
              title: s.shiftName,
              subtitle: s.displayWindow,
              initials: s.shiftName.isNotEmpty
                  ? s.shiftName.substring(0, 1).toUpperCase()
                  : 'S',
            ),
            badges: [
              _Pill(text: '${s.workingHours.toStringAsFixed(1)}h'),
              _Pill(text: 'Grace ${s.graceMinutes}m'),
            ],
            onEdit: () => context.push(AppRoutes.hrShiftNew, extra: s),
            onDelete: () => _confirmDelete(
              context,
              title: 'Delete shift?',
              message:
                  'This will permanently delete ${s.shiftName}. This action cannot be undone.',
              onConfirm: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller = ref.read(shiftDirectoryProvider.notifier);
                await controller.deleteShift(s.id!);
                if (!mounted) return;
                final latest = ref.read(shiftDirectoryProvider);
                if (latest.errorMessage == null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${s.shiftName} deleted.'),
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

// ===========================================================================
// Assignments tab
// ===========================================================================

class _AssignmentsTab extends ConsumerStatefulWidget {
  const _AssignmentsTab();

  @override
  ConsumerState<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends ConsumerState<_AssignmentsTab> {
  int _page = 0;
  static const int _rowsPerPage = 9;

  List<EmployeeShiftRecord> _filter(ShiftDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();
    return state.assignments.where((a) {
      if (query.isEmpty) return true;
      final empName = _employeeName(state, a.employeeId).toLowerCase();
      final shiftName = _shiftName(state, a.shiftId).toLowerCase();
      return empName.contains(query) || shiftName.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shiftDirectoryProvider);
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
        ? const <EmployeeShiftRecord>[]
        : filtered.sublist(
            pageStart - 1,
            math.min(pageStart - 1 + _rowsPerPage, filtered.length),
          );

    return _TabShell(
      searchQuery: state.searchQuery,
      onSearch: (v) =>
          ref.read(shiftDirectoryProvider.notifier).setSearchQuery(v),
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
      onRefresh: () => ref.read(shiftDirectoryProvider.notifier).refresh(),
      filterContent: const SizedBox.shrink(),
      activeFilterChips: const [],
      summary: filtered.isEmpty
          ? (state.isLoading
                ? 'Loading assignments...'
                : 'No assignments found')
          : 'Showing $pageStart-$pageEnd of ${filtered.length} assignments',
      isEmpty: filtered.isEmpty,
      emptyTitle: 'No shift assignments yet',
      emptyMessage:
          'Assign a shift to an employee to schedule them on that shift.',
      onCreate: () => context.push(AppRoutes.hrEmployeeShiftNew),
      gridBuilder: (crossAxisCount) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 150,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final a = visible[index];
          final empName = _employeeName(state, a.employeeId);
          final shiftName = _shiftName(state, a.shiftId);
          final fromText = _formatDate(a.effectiveFrom);
          final toText = a.effectiveTo == null
              ? 'ongoing'
              : _formatDate(a.effectiveTo);
          return _EntityCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF065F46), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.assignment_ind_outlined,
            identity: _CardIdentity(
              title: empName,
              subtitle: '$shiftName  •  $fromText → $toText',
              initials: empName.isNotEmpty
                  ? empName.substring(0, 1).toUpperCase()
                  : 'A',
            ),
            badges: [if (a.effectiveTo == null) _Pill(text: 'Ongoing')],
            onEdit: () => context.push(AppRoutes.hrEmployeeShiftNew, extra: a),
            onDelete: () => _confirmDelete(
              context,
              title: 'Delete assignment?',
              message:
                  'This will permanently remove this shift assignment. This action cannot be undone.',
              onConfirm: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller = ref.read(shiftDirectoryProvider.notifier);
                await controller.deleteAssignment(a.id!);
                if (!mounted) return;
                final latest = ref.read(shiftDirectoryProvider);
                if (latest.errorMessage == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Assignment deleted.'),
                      backgroundColor: Color(0xFF10B981),
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

String _employeeName(ShiftDirectoryState state, String? id) {
  if (id == null) return 'Unknown employee';
  return state.employees
      .where((e) => e.id == id)
      .map((e) => e.fullName)
      .cast<String>()
      .firstWhere((_) => true, orElse: () => 'Unknown employee');
}

String _shiftName(ShiftDirectoryState state, String? id) {
  if (id == null) return 'Unknown shift';
  return state.shifts
      .where((s) => s.id == id)
      .map((s) => s.shiftName)
      .cast<String>()
      .firstWhere((_) => true, orElse: () => 'Unknown shift');
}

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

// ===========================================================================
// Attendance tab
// ===========================================================================

class _AttendanceTab extends ConsumerStatefulWidget {
  const _AttendanceTab();

  @override
  ConsumerState<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends ConsumerState<_AttendanceTab> {
  int _page = 0;
  static const int _rowsPerPage = 9;

  List<AttendanceRecord> _filter(AttendanceDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();
    final status = state.statusFilter;
    return state.records.where((r) {
      if (status != null && r.status.toLowerCase() != status.toLowerCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      final empName = _attendanceEmployeeName(r.employeeId).toLowerCase();
      return empName.contains(query) ||
          (r.remarks ?? '').toLowerCase().contains(query);
    }).toList();
  }

  String _attendanceEmployeeName(String? id) {
    if (id == null) return 'Unknown employee';
    final employees = ref.read(employeeDirectoryProvider).employees;
    return employees
        .where((e) => e.id == id)
        .map((e) => e.fullName)
        .cast<String>()
        .firstWhere((_) => true, orElse: () => 'Unknown employee');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendanceDirectoryProvider);
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
        ? const <AttendanceRecord>[]
        : filtered.sublist(
            pageStart - 1,
            math.min(pageStart - 1 + _rowsPerPage, filtered.length),
          );

    return _TabShell(
      searchQuery: state.searchQuery,
      onSearch: (v) =>
          ref.read(attendanceDirectoryProvider.notifier).setSearchQuery(v),
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
      onRefresh: () => ref.read(attendanceDirectoryProvider.notifier).refresh(),
      filterContent: _FilterDropdown<String?>(
        value: state.statusFilter,
        label: 'Status',
        items: [
          const DropdownMenuItem(value: null, child: Text('All statuses')),
          ...AttendanceStatusOptions.values.map(
            (s) => DropdownMenuItem<String?>(
              value: s,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AttendanceStatusOptions.color(s),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(AttendanceStatusOptions.label(s)),
                ],
              ),
            ),
          ),
        ],
        onChanged: (v) =>
            ref.read(attendanceDirectoryProvider.notifier).setStatusFilter(v),
      ),
      activeFilterChips: [
        if (state.statusFilter != null)
          _ActiveFilterChip(
            label:
                'Status: ${AttendanceStatusOptions.label(state.statusFilter!)}',
            onClear: () => ref
                .read(attendanceDirectoryProvider.notifier)
                .setStatusFilter(null),
          ),
      ],
      summary: filtered.isEmpty
          ? (state.isLoading
                ? 'Loading attendance...'
                : 'No attendance records')
          : 'Showing $pageStart-$pageEnd of ${filtered.length} records',
      isEmpty: filtered.isEmpty,
      emptyTitle: 'No attendance records yet',
      emptyMessage:
          'Log an employee\'s check-in to start tracking attendance and work hours.',
      onCreate: () => context.push(AppRoutes.hrAttendanceNew),
      gridBuilder: (crossAxisCount) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 168,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final r = visible[index];
          final statusColor = AttendanceStatusOptions.color(r.status);
          final empName = _attendanceEmployeeName(r.employeeId);
          return _EntityCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF134E4A), Color(0xFF14B8A6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.fact_check_outlined,
            identity: _CardIdentity(
              title: empName,
              subtitle: _formatDate(r.attendanceDate),
              initials: empName.isNotEmpty
                  ? empName.substring(0, 1).toUpperCase()
                  : 'A',
            ),
            badges: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AttendanceStatusOptions.label(r.status),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill(text: '${r.workHours.toStringAsFixed(1)}h'),
            ],
            onEdit: () => context.push(AppRoutes.hrAttendanceNew, extra: r),
            onDelete: () => _confirmDelete(
              context,
              title: 'Delete attendance record?',
              message:
                  'This will permanently remove this attendance entry. This action cannot be undone.',
              onConfirm: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller = ref.read(
                  attendanceDirectoryProvider.notifier,
                );
                await controller.deleteAttendance(r.id!);
                if (!mounted) return;
                final latest = ref.read(attendanceDirectoryProvider);
                if (latest.errorMessage == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Attendance record deleted.'),
                      backgroundColor: Color(0xFF10B981),
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

// ===========================================================================
// Leave Types tab
// ===========================================================================

class _LeaveTypesTab extends ConsumerStatefulWidget {
  const _LeaveTypesTab();

  @override
  ConsumerState<_LeaveTypesTab> createState() => _LeaveTypesTabState();
}

class _LeaveTypesTabState extends ConsumerState<_LeaveTypesTab> {
  int _page = 0;
  static const int _rowsPerPage = 9;

  List<LeaveTypeRecord> _filter(LeaveTypeDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();
    return state.types.where((t) {
      if (query.isEmpty) return true;
      return t.name.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaveTypeDirectoryProvider);
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
        ? const <LeaveTypeRecord>[]
        : filtered.sublist(
            pageStart - 1,
            math.min(pageStart - 1 + _rowsPerPage, filtered.length),
          );

    return _TabShell(
      searchQuery: state.searchQuery,
      onSearch: (v) =>
          ref.read(leaveTypeDirectoryProvider.notifier).setSearchQuery(v),
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
      onRefresh: () => ref.read(leaveTypeDirectoryProvider.notifier).refresh(),
      filterContent: const SizedBox.shrink(),
      activeFilterChips: const [],
      summary: filtered.isEmpty
          ? (state.isLoading ? 'Loading leave types...' : 'No leave types')
          : 'Showing $pageStart-$pageEnd of ${filtered.length} leave types',
      isEmpty: filtered.isEmpty,
      emptyTitle: 'No leave types yet',
      emptyMessage:
          'Define your leave policies — paid time off, sick leave, unpaid leave, and more.',
      onCreate: () => context.push(AppRoutes.hrLeaveTypeNew),
      gridBuilder: (crossAxisCount) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 150,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final t = visible[index];
          return _EntityCard(
            gradient: LinearGradient(
              colors: t.paidLeave
                  ? const [Color(0xFF065F46), Color(0xFF10B981)]
                  : const [Color(0xFF7F1D1D), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.beach_access_outlined,
            identity: _CardIdentity(
              title: t.name,
              subtitle: '${t.daysPerYear} days / year',
              initials: t.name.isNotEmpty
                  ? t.name.substring(0, 1).toUpperCase()
                  : 'L',
            ),
            badges: [
              _Pill(text: t.paidLabel),
              _Pill(text: '${t.daysPerYear}d'),
            ],
            onEdit: () => context.push(AppRoutes.hrLeaveTypeNew, extra: t),
            onDelete: () => _confirmDelete(
              context,
              title: 'Delete leave type?',
              message:
                  'This will permanently delete ${t.name}. This action cannot be undone.',
              onConfirm: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller = ref.read(
                  leaveTypeDirectoryProvider.notifier,
                );
                await controller.deleteLeaveType(t.id!);
                if (!mounted) return;
                final latest = ref.read(leaveTypeDirectoryProvider);
                if (latest.errorMessage == null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${t.name} deleted.'),
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

// ===========================================================================
// Leave Requests tab
// ===========================================================================

class _LeaveRequestsTab extends ConsumerStatefulWidget {
  const _LeaveRequestsTab();

  @override
  ConsumerState<_LeaveRequestsTab> createState() => _LeaveRequestsTabState();
}

class _LeaveRequestsTabState extends ConsumerState<_LeaveRequestsTab> {
  int _page = 0;
  static const int _rowsPerPage = 9;

  String _employeeName(String? id) {
    if (id == null) return 'Unknown employee';
    final employees = ref.read(employeeDirectoryProvider).employees;
    return employees
        .where((e) => e.id == id)
        .map((e) => e.fullName)
        .cast<String>()
        .firstWhere((_) => true, orElse: () => 'Unknown employee');
  }

  String _leaveTypeName(String? id, List<LeaveTypeRecord> types) {
    if (id == null) return 'Unknown type';
    return types
        .where((t) => t.id == id)
        .map((t) => t.name)
        .cast<String>()
        .firstWhere((_) => true, orElse: () => 'Unknown type');
  }

  String? _approverId() {
    // Best-effort: the current Supabase user id, if available.
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  List<LeaveRequestRecord> _filter(LeaveRequestDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();
    final status = state.approvalStatusFilter;
    return state.requests.where((r) {
      if (status != null &&
          r.approvalStatus.toLowerCase() != status.toLowerCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      final empName = _employeeName(r.employeeId).toLowerCase();
      return empName.contains(query) ||
          (r.reason ?? '').toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _handleApprove(LeaveRequestRecord record) async {
    final approverId = _approverId();
    if (approverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot approve: no signed-in user detected.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(leaveRequestDirectoryProvider.notifier);
    await controller.approve(record, approverId);
    if (!mounted) return;
    final latest = ref.read(leaveRequestDirectoryProvider);
    if (latest.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Leave request approved.'),
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
  }

  Future<void> _handleReject(LeaveRequestRecord record) async {
    final approverId = _approverId();
    if (approverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot reject: no signed-in user detected.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(leaveRequestDirectoryProvider.notifier);
    await controller.reject(record, approverId);
    if (!mounted) return;
    final latest = ref.read(leaveRequestDirectoryProvider);
    if (latest.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Leave request rejected.'),
          backgroundColor: const Color(0xFFF59E0B),
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
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leaveRequestDirectoryProvider);
    final types = ref.watch(leaveTypeDirectoryProvider).types;
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
        ? const <LeaveRequestRecord>[]
        : filtered.sublist(
            pageStart - 1,
            math.min(pageStart - 1 + _rowsPerPage, filtered.length),
          );

    return _TabShell(
      searchQuery: state.searchQuery,
      onSearch: (v) =>
          ref.read(leaveRequestDirectoryProvider.notifier).setSearchQuery(v),
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
      onRefresh: () =>
          ref.read(leaveRequestDirectoryProvider.notifier).refresh(),
      filterContent: _FilterDropdown<String?>(
        value: state.approvalStatusFilter,
        label: 'Status',
        items: [
          const DropdownMenuItem(value: null, child: Text('All statuses')),
          ...LeaveApprovalStatusOptions.values.map(
            (s) => DropdownMenuItem<String?>(
              value: s,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: LeaveApprovalStatusOptions.color(s),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(LeaveApprovalStatusOptions.label(s)),
                ],
              ),
            ),
          ),
        ],
        onChanged: (v) => ref
            .read(leaveRequestDirectoryProvider.notifier)
            .setApprovalStatusFilter(v),
      ),
      activeFilterChips: [
        if (state.approvalStatusFilter != null)
          _ActiveFilterChip(
            label:
                'Status: ${LeaveApprovalStatusOptions.label(state.approvalStatusFilter!)}',
            onClear: () => ref
                .read(leaveRequestDirectoryProvider.notifier)
                .setApprovalStatusFilter(null),
          ),
      ],
      summary: filtered.isEmpty
          ? (state.isLoading
                ? 'Loading leave requests...'
                : 'No leave requests')
          : 'Showing $pageStart-$pageEnd of ${filtered.length} requests',
      isEmpty: filtered.isEmpty,
      emptyTitle: 'No leave requests yet',
      emptyMessage:
          'Submit a leave request on behalf of an employee or have them file one from the portal.',
      onCreate: () => context.push(AppRoutes.hrLeaveRequestNew),
      gridBuilder: (crossAxisCount) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 198,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final r = visible[index];
          final statusColor = LeaveApprovalStatusOptions.color(
            r.approvalStatus,
          );
          final empName = _employeeName(r.employeeId);
          final typeName = _leaveTypeName(r.leaveTypeId, types);
          final fromText = _formatDate(r.fromDate);
          final toText = _formatDate(r.toDate);
          final canApprove = r.approvalStatus == 'pending';
          return _EntityCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF581C87), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.event_busy_outlined,
            identity: _CardIdentity(
              title: empName,
              subtitle: '$typeName  •  $fromText → $toText',
              initials: empName.isNotEmpty
                  ? empName.substring(0, 1).toUpperCase()
                  : 'L',
            ),
            badges: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      r.statusLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              _Pill(text: '${r.totalDays.toStringAsFixed(1)}d'),
            ],
            onEdit: () => context.push(AppRoutes.hrLeaveRequestNew, extra: r),
            onDelete: () => _confirmDelete(
              context,
              title: 'Delete leave request?',
              message:
                  'This will permanently remove this leave request. This action cannot be undone.',
              onConfirm: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller = ref.read(
                  leaveRequestDirectoryProvider.notifier,
                );
                await controller.deleteLeaveRequest(r.id!);
                if (!mounted) return;
                final latest = ref.read(leaveRequestDirectoryProvider);
                if (latest.errorMessage == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Leave request deleted.'),
                      backgroundColor: Color(0xFF10B981),
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
            extraActions: canApprove
                ? [
                    InkWell(
                      onTap: () => _handleReject(r),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _handleApprove(r),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ]
                : null,
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

// ===========================================================================
// Holidays tab
// ===========================================================================

class _HolidaysTab extends ConsumerStatefulWidget {
  const _HolidaysTab();

  @override
  ConsumerState<_HolidaysTab> createState() => _HolidaysTabState();
}

class _HolidaysTabState extends ConsumerState<_HolidaysTab> {
  int _page = 0;
  static const int _rowsPerPage = 9;

  List<HolidayRecord> _filter(HolidayDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();
    final type = state.typeFilter;
    return state.holidays.where((h) {
      if (type != null && h.type.toLowerCase() != type.toLowerCase()) {
        return false;
      }
      if (query.isEmpty) return true;
      return h.name.toLowerCase().contains(query) ||
          h.type.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(holidayDirectoryProvider);
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
        ? const <HolidayRecord>[]
        : filtered.sublist(
            pageStart - 1,
            math.min(pageStart - 1 + _rowsPerPage, filtered.length),
          );

    return _TabShell(
      searchQuery: state.searchQuery,
      onSearch: (v) =>
          ref.read(holidayDirectoryProvider.notifier).setSearchQuery(v),
      isLoading: state.isLoading,
      isSaving: state.isSaving,
      errorMessage: state.errorMessage,
      onRefresh: () => ref.read(holidayDirectoryProvider.notifier).refresh(),
      filterContent: _FilterDropdown<String?>(
        value: state.typeFilter,
        label: 'Type',
        items: [
          const DropdownMenuItem(value: null, child: Text('All types')),
          ...HolidayTypeOptions.values.map(
            (t) => DropdownMenuItem<String?>(
              value: t,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: HolidayTypeOptions.color(t),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(HolidayTypeOptions.label(t)),
                ],
              ),
            ),
          ),
        ],
        onChanged: (v) =>
            ref.read(holidayDirectoryProvider.notifier).setTypeFilter(v),
      ),
      activeFilterChips: [
        if (state.typeFilter != null)
          _ActiveFilterChip(
            label: 'Type: ${HolidayTypeOptions.label(state.typeFilter!)}',
            onClear: () =>
                ref.read(holidayDirectoryProvider.notifier).setTypeFilter(null),
          ),
      ],
      summary: filtered.isEmpty
          ? (state.isLoading ? 'Loading holidays...' : 'No holidays')
          : 'Showing $pageStart-$pageEnd of ${filtered.length} holidays',
      isEmpty: filtered.isEmpty,
      emptyTitle: 'No holidays yet',
      emptyMessage:
          'Add the holidays your company observes so your team can plan time off.',
      onCreate: () => context.push(AppRoutes.hrHolidayNew),
      gridBuilder: (crossAxisCount) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 150,
        ),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final h = visible[index];
          return _EntityCard(
            gradient: const LinearGradient(
              colors: [Color(0xFF9A3412), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            icon: Icons.celebration_outlined,
            identity: _CardIdentity(
              title: h.name,
              subtitle: _formatDate(h.date),
              initials: h.name.isNotEmpty
                  ? h.name.substring(0, 1).toUpperCase()
                  : 'H',
            ),
            badges: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: h.typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: h.typeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      h.typeLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: h.typeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            onEdit: () => context.push(AppRoutes.hrHolidayNew, extra: h),
            onDelete: () => _confirmDelete(
              context,
              title: 'Delete holiday?',
              message:
                  'This will permanently delete ${h.name}. This action cannot be undone.',
              onConfirm: () async {
                final messenger = ScaffoldMessenger.of(context);
                final controller = ref.read(holidayDirectoryProvider.notifier);
                await controller.deleteHoliday(h.id!);
                if (!mounted) return;
                final latest = ref.read(holidayDirectoryProvider);
                if (latest.errorMessage == null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${h.name} deleted.'),
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

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.gradient,
    required this.icon,
    required this.identity,
    required this.badges,
    required this.onEdit,
    required this.onDelete,
    this.extraActions,
  });

  final LinearGradient gradient;
  final IconData icon;
  final _CardIdentity identity;
  final List<Widget> badges;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<Widget>? extraActions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(child: identity.header(context)),
                if (extraActions != null) ...extraActions!,
                _CardIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 4),
                _CardIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (badges.isNotEmpty)
                    Wrap(spacing: 6, runSpacing: 6, children: badges)
                  else
                    Text(
                      identity.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (badges.isNotEmpty)
                    Text(
                      identity.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardIdentity {
  const _CardIdentity({
    required this.title,
    required this.subtitle,
    required this.initials,
  });

  final String title;
  final String subtitle;
  final String initials;

  Widget header(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            initials,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4338CA),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onClear,
      deleteIconColor: const Color(0xFF64748B),
      backgroundColor: const Color(0xFFEEF2FF),
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        color: const Color(0xFF4338CA),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: false,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          onChanged: onChanged,
          items: items,
        ),
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
