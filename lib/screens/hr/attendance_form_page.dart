import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/attendance.dart';
import 'package:erp/models/hr.dart';
import 'package:erp/providers/attendance_providers.dart';
import 'package:erp/providers/hr_providers.dart';

/// Bulk attendance sheet — shows all employees in a table with their
/// attendance status, check-in / check-out times, and work hours for a
/// given date.  Saves / updates every row in a single batch.
class AttendanceFormPage extends ConsumerStatefulWidget {
  const AttendanceFormPage({super.key, this.embedded = false});

  /// When [embedded] is `true` the page renders without its own
  /// [Scaffold] / [AppBar] / bottom-navigation so it can be placed
  /// directly inside a tab or another parent widget.
  final bool embedded;

  @override
  ConsumerState<AttendanceFormPage> createState() => _AttendanceFormPageState();
}

class _EmployeeRowState {
  String employeeId;
  String status;
  TimeOfDay? checkIn;
  TimeOfDay? checkOut;
  double workHours;
  int lateMinutes;
  double overtimeHours;
  String? remarks;
  String? existingId;
  bool hasExistingRecord;

  _EmployeeRowState({
    required this.employeeId,
    this.status = AttendanceStatusOptions.defaultValue,
    this.checkIn,
    this.checkOut,
    this.workHours = 0,
    this.lateMinutes = 0,
    this.overtimeHours = 0,
    this.remarks,
    this.existingId,
    this.hasExistingRecord = false,
  });
}

class _AttendanceFormPageState extends ConsumerState<AttendanceFormPage> {
  DateTime? _attendanceDate = DateTime.now();
  bool _isSubmitting = false;
  List<_EmployeeRowState> _rows = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _initRows();
    }
  }

  void _initRows() {
    final employees = ref.read(employeeDirectoryProvider).employees;
    final records = ref.read(attendanceDirectoryProvider).records;
    _rows = employees.where((e) => e.id != null).map((e) {
      final existing = _findExistingRecord(records, e.id!);
      return _EmployeeRowState(
        employeeId: e.id!,
        status: existing?.status ?? AttendanceStatusOptions.defaultValue,
        checkIn: existing?.checkIn != null
            ? TimeOfDay(
                hour: existing!.checkIn!.hour,
                minute: existing.checkIn!.minute,
              )
            : null,
        checkOut: existing?.checkOut != null
            ? TimeOfDay(
                hour: existing!.checkOut!.hour,
                minute: existing.checkOut!.minute,
              )
            : null,
        workHours: existing?.workHours ?? 0,
        lateMinutes: existing?.lateMinutes ?? 0,
        overtimeHours: existing?.overtimeHours ?? 0,
        remarks: existing?.remarks,
        existingId: existing?.id,
        hasExistingRecord: existing != null,
      );
    }).toList();
    setState(() {});
  }

  AttendanceRecord? _findExistingRecord(
    List<AttendanceRecord> records,
    String employeeId,
  ) {
    if (_attendanceDate == null) return null;
    final dateStr =
        '${_attendanceDate!.year.toString().padLeft(4, '0')}-${_attendanceDate!.month.toString().padLeft(2, '0')}-${_attendanceDate!.day.toString().padLeft(2, '0')}';
    try {
      return records.firstWhere((r) {
        if (r.employeeId != employeeId) return false;
        if (r.attendanceDate == null) return false;
        final rd =
            '${r.attendanceDate!.year.toString().padLeft(4, '0')}-${r.attendanceDate!.month.toString().padLeft(2, '0')}-${r.attendanceDate!.day.toString().padLeft(2, '0')}';
        return rd == dateStr;
      });
    } catch (_) {
      return null;
    }
  }

  void _reconcileWithExistingRecords() {
    final records = ref.read(attendanceDirectoryProvider).records;
    for (final row in _rows) {
      final existing = _findExistingRecord(records, row.employeeId);
      row.existingId = existing?.id;
      row.hasExistingRecord = existing != null;
      if (existing != null) {
        row.status = existing.status;
        row.checkIn = existing.checkIn != null
            ? TimeOfDay(
                hour: existing.checkIn!.hour,
                minute: existing.checkIn!.minute,
              )
            : null;
        row.checkOut = existing.checkOut != null
            ? TimeOfDay(
                hour: existing.checkOut!.hour,
                minute: existing.checkOut!.minute,
              )
            : null;
        row.workHours = existing.workHours;
        row.lateMinutes = existing.lateMinutes;
        row.overtimeHours = existing.overtimeHours;
        row.remarks = existing.remarks;
      }
    }
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _attendanceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked == null) return;
    setState(() => _attendanceDate = picked);
    // Refresh attendance records for the new date
    await ref.read(attendanceDirectoryProvider.notifier).refresh();
    _reconcileWithExistingRecords();
  }

  DateTime? _mergeWithDate(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickTimeForEmployee(
    _EmployeeRowState row,
    bool isCheckIn,
  ) async {
    final initial = isCheckIn
        ? (row.checkIn ?? const TimeOfDay(hour: 9, minute: 0))
        : (row.checkOut ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        row.checkIn = picked;
      } else {
        row.checkOut = picked;
      }
      _autoCalcWorkHours(row);
    });
  }

  void _autoCalcWorkHours(_EmployeeRowState row) {
    final ci = row.checkIn;
    final co = row.checkOut;
    if (ci == null || co == null) return;
    final ciM = ci.hour * 60 + ci.minute;
    final coM = co.hour * 60 + co.minute;
    var diff = coM - ciM;
    if (diff < 0) diff += 24 * 60;
    if (diff > 0) {
      row.workHours = diff / 60.0;
    }
  }

  void _markAll(String status) {
    setState(() {
      for (final row in _rows) {
        row.status = status;
        if (status == 'Present') {
          row.checkIn ??= const TimeOfDay(hour: 9, minute: 0);
          row.checkOut ??= const TimeOfDay(hour: 17, minute: 0);
          _autoCalcWorkHours(row);
        }
      }
    });
  }

  Future<void> _handleSaveAll() async {
    if (_attendanceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an attendance date.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final controller = ref.read(attendanceDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final drafts = _rows
        .map(
          (row) => AttendanceRecord(
            id: row.hasExistingRecord ? row.existingId : null,
            employeeId: row.employeeId,
            attendanceDate: _attendanceDate,
            checkIn: _mergeWithDate(_attendanceDate, row.checkIn),
            checkOut: _mergeWithDate(_attendanceDate, row.checkOut),
            workHours: row.workHours,
            lateMinutes: row.lateMinutes,
            overtimeHours: row.overtimeHours,
            status: row.status,
            remarks: row.remarks,
            createdAt: null,
            updatedAt: null,
          ),
        )
        .toList();

    final (:saved, :errors) = await controller.saveAttendanceBatch(drafts);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (errors == 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$saved attendance record(s) saved successfully.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      if (GoRouter.of(context).canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.hr);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$saved saved, $errors failed.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hrState = ref.watch(employeeDirectoryProvider);
    final attState = ref.watch(attendanceDirectoryProvider);

    // Re-init rows when employees or attendance records change
    if (hrState.employees.isNotEmpty && _rows.isEmpty && !attState.isLoading) {
      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) => _initRows());
    }

    final employees = hrState.employees;
    final isDesktopWidth = MediaQuery.of(context).size.width >= 900;

    final bodyContent = Column(
      children: [
        // ── Date selector + quick actions ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            bottom: false,
            child: Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _attendanceDate == null
                              ? 'Select date'
                              : '${_attendanceDate!.year.toString().padLeft(4, '0')}-${_attendanceDate!.month.toString().padLeft(2, '0')}-${_attendanceDate!.day.toString().padLeft(2, '0')}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ActionChip(
                  avatar: const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                  label: const Text('All Present'),
                  onPressed: () => _markAll('Present'),
                ),
                ActionChip(
                  avatar: const Icon(
                    Icons.cancel_outlined,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                  label: const Text('All Absent'),
                  onPressed: () => _markAll('Absent'),
                ),
                if (employees.length != _rows.length &&
                    !attState.isLoading &&
                    !_isSubmitting)
                  TextButton.icon(
                    onPressed: _initRows,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Sync'),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        // ── Horizontally scrollable table ──
        Expanded(
          child: (attState.isLoading && _rows.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 56,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No employees found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add employees first to mark attendance.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    const double minTableWidth = 600;
                    final bool needsScroll =
                        constraints.maxWidth < minTableWidth;
                    final double tableWidth = needsScroll
                        ? minTableWidth
                        : constraints.maxWidth;

                    Widget tableContent = Column(
                      children: [
                        // ── Table header ──
                        Container(
                          color: const Color(0xFFF8FAFC),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              _headerCell('Employee', flex: 3),
                              _headerCell('Status', flex: 2),
                              _headerCell('Check-in', flex: 2),
                              _headerCell('Check-out', flex: 2),
                              _headerCell('Hours', flex: 1),
                            ],
                          ),
                        ),
                        // ── Table rows ──
                        Expanded(
                          child: SizedBox(
                            width: tableWidth,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              itemCount: _rows.length,
                              itemBuilder: (context, index) {
                                final row = _rows[index];
                                final employee = _findEmployee(
                                  employees,
                                  row.employeeId,
                                );
                                return _buildRow(row, employee, isDesktopWidth);
                              },
                            ),
                          ),
                        ),
                      ],
                    );

                    if (needsScroll) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: tableWidth, child: tableContent),
                      );
                    }
                    return tableContent;
                  },
                ),
        ),
      ],
    );

    final bottomBar = SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (GoRouter.of(context).canPop()) {
                        context.pop();
                      } else {
                        context.go(AppRoutes.hr);
                      }
                    },
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _handleSaveAll,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSubmitting
                      ? 'Saving ${_rows.length} record(s)...'
                      : 'Save All (${_rows.length})',
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: bodyContent),
          bottomBar,
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to HR',
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.hr);
            }
          },
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fact_check_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Attendance Sheet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    'Mark attendance for all employees for a single day.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: bodyContent,
      bottomNavigationBar: bottomBar,
    );
  }

  EmployeeRecord? _findEmployee(List<EmployeeRecord> employees, String id) {
    try {
      return employees.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Widget _headerCell(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRow(_EmployeeRowState row, EmployeeRecord? employee, bool wide) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: row.hasExistingRecord ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Employee info
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  employee?.fullName ?? 'Unknown',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  employee?.employeeCode ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: _StatusDropdown(
              value: row.status,
              onChanged: (v) => setState(() => row.status = v),
            ),
          ),
          // Check-in
          Expanded(
            flex: 2,
            child: _TimeCell(
              time: row.checkIn,
              hint: 'In',
              onTap: () => _pickTimeForEmployee(row, true),
            ),
          ),
          // Check-out
          Expanded(
            flex: 2,
            child: _TimeCell(
              time: row.checkOut,
              hint: 'Out',
              onTap: () => _pickTimeForEmployee(row, false),
            ),
          ),
          // Hours
          Expanded(
            flex: 1,
            child: Text(
              row.workHours > 0 ? '${row.workHours.toStringAsFixed(1)}h' : '—',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: row.workHours > 0
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Helper widgets
// ===========================================================================

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = AttendanceStatusOptions.color(value);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.arrow_drop_down, color: color, size: 20),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          items: AttendanceStatusOptions.values
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AttendanceStatusOptions.color(v),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AttendanceStatusOptions.label(v),
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.time,
    required this.hint,
    required this.onTap,
  });

  final TimeOfDay? time;
  final String hint;
  final VoidCallback onTap;

  String _format(TimeOfDay? t) {
    if (t == null) return hint;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: time == null
              ? const Color(0xFFF8FAFC)
              : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Text(
          _format(time),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: time == null ? FontWeight.w400 : FontWeight.w600,
            color: time == null
                ? const Color(0xFF94A3B8)
                : const Color(0xFF4F46E5),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
