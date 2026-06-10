import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/attendance.dart';
import 'package:erp/providers/attendance_providers.dart';
import 'package:erp/providers/hr_providers.dart';

class AttendanceFormPage extends ConsumerStatefulWidget {
  const AttendanceFormPage({super.key, this.existing});

  final AttendanceRecord? existing;

  @override
  ConsumerState<AttendanceFormPage> createState() => _AttendanceFormPageState();
}

class _AttendanceFormPageState extends ConsumerState<AttendanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dependenciesResolved = false;
  AttendanceRecord? _initialExisting;

  String? _employeeId;
  DateTime? _attendanceDate;
  TimeOfDay? _checkIn;
  TimeOfDay? _checkOut;
  String _status = AttendanceStatusOptions.defaultValue;

  late final TextEditingController _workHoursController;
  late final TextEditingController _lateMinutesController;
  late final TextEditingController _overtimeHoursController;
  late final TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _employeeId = existing?.employeeId;
    _attendanceDate = existing?.attendanceDate;
    _checkIn = _timeFromDateTime(existing?.checkIn);
    _checkOut = _timeFromDateTime(existing?.checkOut);
    _status = (existing?.status ?? '').isEmpty
        ? AttendanceStatusOptions.defaultValue
        : existing!.status;
    _workHoursController = TextEditingController(
      text: existing == null ? '0' : existing.workHours.toStringAsFixed(2),
    );
    _lateMinutesController = TextEditingController(
      text: existing == null ? '0' : existing.lateMinutes.toString(),
    );
    _overtimeHoursController = TextEditingController(
      text: existing == null ? '0' : existing.overtimeHours.toStringAsFixed(2),
    );
    _remarksController = TextEditingController(text: existing?.remarks ?? '');
  }

  void _initializeFromRoute(AttendanceRecord existing) {
    _employeeId = existing.employeeId;
    _attendanceDate = existing.attendanceDate;
    _checkIn = _timeFromDateTime(existing.checkIn);
    _checkOut = _timeFromDateTime(existing.checkOut);
    _status = existing.status.isEmpty
        ? AttendanceStatusOptions.defaultValue
        : existing.status;
    _workHoursController.text = existing.workHours.toStringAsFixed(2);
    _lateMinutesController.text = existing.lateMinutes.toString();
    _overtimeHoursController.text = existing.overtimeHours.toStringAsFixed(2);
    _remarksController.text = existing.remarks ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesResolved) {
      return;
    }
    _dependenciesResolved = true;
    if (_initialExisting != null) {
      return;
    }
    final extra = GoRouterState.of(context).extra;
    if (extra is! AttendanceRecord) {
      return;
    }
    _initialExisting = extra;
    _initializeFromRoute(extra);
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
    if (value == null) {
      return null;
    }
    return TimeOfDay(hour: value.hour, minute: value.minute);
  }

  DateTime? _mergeWithDate(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) {
      return null;
    }
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _attendanceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null) {
      return;
    }
    setState(() => _attendanceDate = picked);
  }

  Future<void> _pickTime({required bool isCheckIn}) async {
    final initial = isCheckIn
        ? (_checkIn ?? const TimeOfDay(hour: 9, minute: 0))
        : (_checkOut ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) {
      return;
    }
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
    if (_checkIn == null || _checkOut == null) {
      return;
    }
    final ci = _checkIn!;
    final co = _checkOut!;
    final ciMinutes = ci.hour * 60 + ci.minute;
    final coMinutes = co.hour * 60 + co.minute;
    var diff = coMinutes - ciMinutes;
    if (diff < 0) {
      diff += 24 * 60;
    }
    final hours = diff / 60.0;
    if (hours > 0) {
      _workHoursController.text = hours.toStringAsFixed(2);
    }
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee.'),
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
      id: _initialExisting?.id,
      employeeId: _employeeId!,
      attendanceDate: _attendanceDate,
      checkIn: _mergeWithDate(_attendanceDate, _checkIn),
      checkOut: _mergeWithDate(_attendanceDate, _checkOut),
      workHours: double.tryParse(_workHoursController.text.trim()) ?? 0,
      lateMinutes: int.tryParse(_lateMinutesController.text.trim()) ?? 0,
      overtimeHours:
          double.tryParse(_overtimeHoursController.text.trim()) ?? 0,
      status: _status,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
    );

    try {
      await controller.saveAttendance(draft);
      if (!mounted) {
        return;
      }
      final latestState = ref.read(attendanceDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully.'),
            backgroundColor: Color(0xFF10B981),
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
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save attendance: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return 'Pick time';
    }
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final hrState = ref.watch(employeeDirectoryProvider);
    final employees = hrState.employees;
    final existing = _initialExisting;
    final isEdit = existing != null;

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
                    isEdit ? 'Edit Attendance' : 'New Attendance Record',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update the attendance entry for this employee.'
                        : 'Log attendance for an employee on a specific day.',
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: 'Employee & Date'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    isExpanded: true,
                    decoration: _decoration('Employee'),
                    items: employees
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.id,
                            child: Text(
                              '${e.fullName}  •  ${e.employeeCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _employeeId = value),
                    validator: (value) {
                      if (value == null) {
                        return 'Employee is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: _decoration('Attendance Date'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatDate(_attendanceDate),
                              style: TextStyle(
                                color: _attendanceDate == null
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (_attendanceDate != null)
                            InkWell(
                              onTap: () => setState(() => _attendanceDate = null),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: Color(0xFF4F46E5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Punch Times'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(isCheckIn: true),
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: _decoration('Check-in'),
                            child: Text(
                              _formatTime(_checkIn),
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
                            decoration: _decoration('Check-out'),
                            child: Text(
                              _formatTime(_checkOut),
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
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Computed Metrics'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _workHoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration('Work Hours'),
                          validator: (value) {
                            final v =
                                double.tryParse((value ?? '').trim()) ?? -1;
                            if (v < 0) {
                              return 'Must be zero or more';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lateMinutesController,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Late (min)'),
                          validator: (value) {
                            final v =
                                int.tryParse((value ?? '').trim()) ?? -1;
                            if (v < 0) {
                              return 'Must be zero or more';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _overtimeHoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _decoration('Overtime (hrs)'),
                          validator: (value) {
                            final v =
                                double.tryParse((value ?? '').trim()) ?? -1;
                            if (v < 0) {
                              return 'Must be zero or more';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _decoration('Status'),
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
                      if (v == null) {
                        return;
                      }
                      setState(() => _status = v);
                    },
                  ),
                  const SizedBox(height: 14),
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
                        borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0),
                        ),
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
      ),
      bottomNavigationBar: SafeArea(
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _isSubmitting ? 'Saving...' : 'Save Attendance',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
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
