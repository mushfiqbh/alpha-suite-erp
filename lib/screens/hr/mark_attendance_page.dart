import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/attendance.dart';
import 'package:erp/providers/attendance_providers.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:erp/providers/hr_providers.dart';

/// Mark / edit attendance for your own account.
///
/// Available to non-admin, non-viewer roles. The employee is automatically
/// resolved from the authenticated user's linked employee record.
class MarkAttendancePage extends ConsumerStatefulWidget {
  const MarkAttendancePage({super.key, this.embedded = false});

  /// When [embedded] is `true` the page renders without its own
  /// [Scaffold] / [AppBar] / bottom-navigation so it can be placed
  /// directly inside a tab or another parent widget.
  final bool embedded;

  @override
  ConsumerState<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends ConsumerState<MarkAttendancePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoadingEmployee = true;
  String? _loadError;

  String? _employeeId;
  String? _employeeName;
  DateTime? _attendanceDate;
  TimeOfDay? _checkIn;
  TimeOfDay? _checkOut;
  String _status = AttendanceStatusOptions.defaultValue;
  String? _existingId;
  bool _hasExistingRecord = false;

  late final TextEditingController _workHoursController;
  late final TextEditingController _lateMinutesController;
  late final TextEditingController _overtimeHoursController;
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _attendanceDate = DateTime.now();
    _workHoursController = TextEditingController(text: '0');
    _lateMinutesController = TextEditingController(text: '0');
    _overtimeHoursController = TextEditingController(text: '0');
    _remarksController = TextEditingController();
    // Resolve employee after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _resolveCurrentEmployee(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Employee is resolved in initState — no-op here.
  }

  /// Finds the employee record linked to the currently authenticated user
  /// and populates [_employeeId] / [_employeeName].
  void _resolveCurrentEmployee() {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated || authState.userId.isEmpty) {
      setState(() {
        _isLoadingEmployee = false;
        _employeeId = null;
        _employeeName = null;
        _loadError = 'You must be logged in.';
      });
      return;
    }

    final dirState = ref.read(employeeDirectoryProvider);

    // If the employee directory is still loading, stay in loading state.
    if (dirState.isLoading) {
      setState(() {
        _isLoadingEmployee = true;
        _employeeId = null;
        _employeeName = null;
        _loadError = null;
      });
      return;
    }

    final matched = dirState.employees.where(
      (e) => e.linkedUserId == authState.userId,
    );

    if (matched.isEmpty) {
      setState(() {
        _isLoadingEmployee = false;
        _employeeId = null;
        _employeeName = null;
        _loadError =
            'No employee record linked to your account. '
            'Please contact an administrator.';
      });
      return;
    }

    final employee = matched.first;
    final changed = employee.id != _employeeId;
    setState(() {
      _employeeId = employee.id;
      _employeeName = employee.fullName;
      _isLoadingEmployee = false;
      _loadError = null;
    });
    if (changed) {
      _loadExistingIfAvailable();
    }
  }

  void _loadExistingIfAvailable() {
    if (_employeeId == null || _attendanceDate == null) return;
    final records = ref.read(attendanceDirectoryProvider).records;
    final existing = _findExisting(records);
    if (existing == null) return;
    setState(() {
      _existingId = existing.id;
      _hasExistingRecord = true;
      _status = existing.status;
      _checkIn = _timeFromDateTime(existing.checkIn);
      _checkOut = _timeFromDateTime(existing.checkOut);
      _workHoursController.text = existing.workHours.toStringAsFixed(2);
      _lateMinutesController.text = existing.lateMinutes.toString();
      _overtimeHoursController.text = existing.overtimeHours.toStringAsFixed(2);
      _remarksController.text = existing.remarks ?? '';
    });
  }

  AttendanceRecord? _findExisting(List<AttendanceRecord> records) {
    if (_attendanceDate == null || _employeeId == null) return null;
    final ds =
        '${_attendanceDate!.year.toString().padLeft(4, '0')}-${_attendanceDate!.month.toString().padLeft(2, '0')}-${_attendanceDate!.day.toString().padLeft(2, '0')}';
    try {
      return records.firstWhere((r) {
        if (r.employeeId != _employeeId) return false;
        if (r.attendanceDate == null) return false;
        final rd =
            '${r.attendanceDate!.year.toString().padLeft(4, '0')}-${r.attendanceDate!.month.toString().padLeft(2, '0')}-${r.attendanceDate!.day.toString().padLeft(2, '0')}';
        return rd == ds;
      });
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _workHoursController.dispose();
    _lateMinutesController.dispose();
    _overtimeHoursController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  TimeOfDay? _timeFromDateTime(DateTime? value) {
    if (value == null) return null;
    return TimeOfDay(hour: value.hour, minute: value.minute);
  }

  DateTime? _mergeWithDate(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _attendanceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null) return;
    setState(() => _attendanceDate = picked);
    // Refresh to find existing record for new date
    await ref.read(attendanceDirectoryProvider.notifier).refresh();
    _loadExistingIfAvailable();
  }

  Future<void> _pickTime({required bool isCheckIn}) async {
    final initial = isCheckIn
        ? (_checkIn ?? const TimeOfDay(hour: 9, minute: 0))
        : (_checkOut ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
      } else {
        _checkOut = picked;
      }
    });
    _autoCalculateWorkHours();
  }

  void _autoCalculateWorkHours() {
    if (_checkIn == null || _checkOut == null) return;
    final ci = _checkIn!;
    final co = _checkOut!;
    final ciM = ci.hour * 60 + ci.minute;
    final coM = co.hour * 60 + co.minute;
    var diff = coM - ciM;
    if (diff < 0) diff += 24 * 60;
    final hours = diff / 60.0;
    if (hours > 0) {
      _workHoursController.text = hours.toStringAsFixed(2);
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee profile not found on your account.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_attendanceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an attendance date.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final controller = ref.read(attendanceDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = AttendanceRecord(
      id: _hasExistingRecord ? _existingId : null,
      employeeId: _employeeId!,
      attendanceDate: _attendanceDate,
      checkIn: _mergeWithDate(_attendanceDate, _checkIn),
      checkOut: _mergeWithDate(_attendanceDate, _checkOut),
      workHours: double.tryParse(_workHoursController.text.trim()) ?? 0,
      lateMinutes: int.tryParse(_lateMinutesController.text.trim()) ?? 0,
      overtimeHours: double.tryParse(_overtimeHoursController.text.trim()) ?? 0,
      status: _status,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      createdAt: null,
      updatedAt: null,
    );

    try {
      await controller.saveAttendance(draft);
      if (!mounted) return;
      final latestState = ref.read(attendanceDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _hasExistingRecord
                  ? 'Attendance updated successfully.'
                  : 'Attendance saved successfully.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          navigator.go(AppRoutes.hr);
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(latestState.errorMessage!),
            backgroundColor: Colors.red.shade600,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save attendance: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading / error states when the employee could not be resolved.
    if (_isLoadingEmployee) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading your profile...',
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final formContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              widget.embedded ? 20 : 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Employee & Date section ──
                _SectionTitle(title: 'Employee & Date'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.badge_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _employeeName ?? 'Your Account',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Marking your own attendance',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.person_pin_rounded,
                        size: 20,
                        color: Color(0xFF4F46E5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: _inputDecoration('Attendance Date'),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _attendanceDate == null
                                ? 'Select date'
                                : '${_attendanceDate!.year.toString().padLeft(4, '0')}-${_attendanceDate!.month.toString().padLeft(2, '0')}-${_attendanceDate!.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: _attendanceDate == null
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_hasExistingRecord)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Existing record found — editing.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 22),
                // ── Punch Times ──
                _SectionTitle(title: 'Punch Times'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(isCheckIn: true),
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: _inputDecoration('Check-in'),
                          child: Text(
                            _checkIn == null
                                ? 'Pick time'
                                : '${_checkIn!.hour.toString().padLeft(2, '0')}:${_checkIn!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: _checkIn == null
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(isCheckIn: false),
                        borderRadius: BorderRadius.circular(14),
                        child: InputDecorator(
                          decoration: _inputDecoration('Check-out'),
                          child: Text(
                            _checkOut == null
                                ? 'Pick time'
                                : '${_checkOut!.hour.toString().padLeft(2, '0')}:${_checkOut!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: _checkOut == null
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                // ── Status ──
                _SectionTitle(title: 'Status & Metrics'),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: _inputDecoration('Status'),
                  items: AttendanceStatusOptions.values
                      .map(
                        (v) => DropdownMenuItem<String>(
                          value: v,
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AttendanceStatusOptions.color(v),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(AttendanceStatusOptions.label(v)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _status = v);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _workHoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration('Work Hours'),
                        validator: (value) {
                          final v = double.tryParse((value ?? '').trim()) ?? -1;
                          if (v < 0) return 'Must be zero or more';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lateMinutesController,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration('Late (min)'),
                        validator: (value) {
                          final v = int.tryParse((value ?? '').trim()) ?? -1;
                          if (v < 0) return 'Must be zero or more';
                          return null;
                        },
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _overtimeHoursController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _inputDecoration('Overtime (hrs)'),
                        validator: (value) {
                          final v = double.tryParse((value ?? '').trim()) ?? -1;
                          if (v < 0) return 'Must be zero or more';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Remarks ──
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Remarks',
                    hintText: 'Optional notes (e.g. sick, worked remote)',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF4F46E5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
            const SizedBox(width: 20),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _handleSave,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _isSubmitting
                    ? 'Saving...'
                    : (_hasExistingRecord
                          ? 'Update Attendance'
                          : 'Save Attendance'),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: formContent),
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
          tooltip: 'Back',
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
                Icons.person_add_alt_1_rounded,
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
                    _hasExistingRecord
                        ? 'Update Attendance'
                        : 'Mark Attendance',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    _hasExistingRecord
                        ? 'Update your attendance entry.'
                        : 'Record your own attendance for the day.',
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
      body: formContent,
      bottomNavigationBar: bottomBar,
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}
