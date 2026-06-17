import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/attendance.dart';
import 'package:erp/providers/attendance_providers.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:erp/providers/hr_providers.dart';

/// Self-service punch-in / punch-out page.

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
  static const Duration _standardWorkday = Duration(hours: 8);

  /// Default office start time used to decide whether a check-in is `Late`.
  /// Picked at 09:00 local time — adjust here if your office start differs.
  static const TimeOfDay _shiftStart = TimeOfDay(hour: 9, minute: 0);
  static const int _lateGraceMinutes = 0;

  bool _isLoadingEmployee = true;
  bool _isPunching = false;
  bool _isSavingRemarks = false;
  String? _loadError;

  String? _employeeId;
  String? _employeeName;

  late final TextEditingController _remarksController;
  Timer? _remarksDebounce;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
    _remarksController.addListener(_onRemarksChanged);
    // Resolve employee after the first frame so providers are ready.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _resolveCurrentEmployee(),
    );
  }

  @override
  void dispose() {
    _remarksDebounce?.cancel();
    _remarksController.removeListener(_onRemarksChanged);
    _remarksController.dispose();
    super.dispose();
  }

  /// Finds the employee record linked to the currently authenticated user
  /// and populates [_employeeId] / [_employeeName].  Populates the remarks
  /// field with the existing record's remarks (if any).
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
    setState(() {
      _employeeId = employee.id;
      _employeeName = employee.fullName;
      _isLoadingEmployee = false;
      _loadError = null;
    });
    _hydrateRemarksFromExisting();
  }

  AttendanceRecord? _findTodayRecord() {
    if (_employeeId == null) return null;
    final records = ref.read(attendanceDirectoryProvider).records;
    final now = DateTime.now();
    try {
      return records.firstWhere((r) {
        if (r.employeeId != _employeeId) return false;
        if (r.attendanceDate == null) return false;
        return r.attendanceDate!.year == now.year &&
            r.attendanceDate!.month == now.month &&
            r.attendanceDate!.day == now.day;
      });
    } catch (_) {
      return null;
    }
  }

  void _hydrateRemarksFromExisting() {
    final existing = _findTodayRecord();
    if (existing == null) return;
    final newText = existing.remarks ?? '';
    if (_remarksController.text == newText) return;
    _remarksController.text = newText;
    _remarksController.selection = TextSelection.fromPosition(
      TextPosition(offset: _remarksController.text.length),
    );
  }

  // ---------------------------------------------------------------------------
  // Punch actions
  // ---------------------------------------------------------------------------

  Future<void> _handleCheckIn() async {
    if (_employeeId == null) return;
    setState(() => _isPunching = true);

    final now = DateTime.now();
    final attendanceDate = DateTime(now.year, now.month, now.day);
    final isLate = _calculateLateMinutes(now) > 0;
    final status = isLate
        ? 'Late'
        : AttendanceStatusOptions.defaultValue;

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(attendanceDirectoryProvider.notifier);

    final draft = AttendanceRecord(
      id: null,
      employeeId: _employeeId,
      attendanceDate: attendanceDate,
      checkIn: now,
      checkOut: null,
      workHours: 0,
      lateMinutes: _calculateLateMinutes(now),
      overtimeHours: 0,
      status: status,
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
              isLate
                  ? 'Checked in at ${_formatTime(now)} — marked as Late.'
                  : 'Checked in at ${_formatTime(now)}.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(latestState.errorMessage!),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not check in: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPunching = false);
    }
  }

  Future<void> _handleCheckOut() async {
    if (_employeeId == null) return;
    final existing = _findTodayRecord();
    if (existing == null || existing.checkIn == null) return;

    setState(() => _isPunching = true);

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(attendanceDirectoryProvider.notifier);

    final now = DateTime.now();
    final workHours = _calculateWorkHours(existing.checkIn!, now);
    final lateMinutes = _calculateLateMinutes(existing.checkIn!);
    final overtimeHours = _calculateOvertimeHours(workHours);
    final status = _deriveStatusOnCheckout(
      workHours: workHours,
      lateMinutes: lateMinutes,
      fallbackStatus: existing.status,
    );

    final draft = AttendanceRecord(
      id: existing.id,
      employeeId: _employeeId,
      attendanceDate: existing.attendanceDate,
      checkIn: existing.checkIn,
      checkOut: now,
      workHours: workHours,
      lateMinutes: lateMinutes,
      overtimeHours: overtimeHours,
      status: status,
      remarks: _remarksController.text.trim().isEmpty
          ? null
          : _remarksController.text.trim(),
      createdAt: existing.createdAt,
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
              'Checked out at ${_formatTime(now)} — '
              '${workHours.toStringAsFixed(2)} hrs logged.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(latestState.errorMessage!),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not check out: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isPunching = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Calculations
  // ---------------------------------------------------------------------------

  /// How late the check-in was, in minutes, versus the configured shift start.
  /// Returns 0 if the punch is on time (within grace) or before the shift.
  int _calculateLateMinutes(DateTime checkIn) {
    final shiftStartMinutes = _shiftStart.hour * 60 + _shiftStart.minute;
    final checkInMinutes = checkIn.hour * 60 + checkIn.minute;
    final diff = checkInMinutes - shiftStartMinutes;
    if (diff <= _lateGraceMinutes) return 0;
    return diff;
  }

  /// Worked hours between check-in and check-out (rounded to 2 dp).
  double _calculateWorkHours(DateTime checkIn, DateTime checkOut) {
    final diff = checkOut.difference(checkIn);
    if (diff.isNegative) return 0;
    return double.parse((diff.inSeconds / 3600.0).toStringAsFixed(2));
  }

  /// Overtime is anything beyond a standard 8-hour workday.
  double _calculateOvertimeHours(double workHours) {
    final standardHours = _standardWorkday.inMinutes / 60.0;
    final overtime = workHours - standardHours;
    if (overtime <= 0) return 0;
    return double.parse(overtime.toStringAsFixed(2));
  }

  /// Re-derive a sensible status when the user punches out.  We never
  /// downgrade an explicitly chosen status (e.g. "Leave") automatically.
  String _deriveStatusOnCheckout({
    required double workHours,
    required int lateMinutes,
    required String fallbackStatus,
  }) {
    final lowered = fallbackStatus.toLowerCase();
    if (lowered == 'leave' ||
        lowered == 'holiday' ||
        lowered == 'absent' ||
        lowered == 'weekend' ||
        lowered == 'half_day' ||
        lowered == 'half day') {
      return fallbackStatus;
    }
    if (lateMinutes > 0) return 'Late';
    if (workHours > 0 && workHours < 4) return 'Half Day';
    return AttendanceStatusOptions.defaultValue;
  }

  // ---------------------------------------------------------------------------
  // Remarks auto-save (debounced)
  // ---------------------------------------------------------------------------

  void _onRemarksChanged() {
    _remarksDebounce?.cancel();
    _remarksDebounce = Timer(
      const Duration(milliseconds: 1200),
      _persistRemarks,
    );
  }

  Future<void> _persistRemarks() async {
    final existing = _findTodayRecord();
    if (_employeeId == null || existing == null) {
      // Nothing to save until the employee has punched in.
      return;
    }
    final trimmed = _remarksController.text.trim();
    if ((existing.remarks ?? '') == (trimmed.isEmpty ? null : trimmed)) {
      return;
    }
    if (!mounted) return;
    setState(() => _isSavingRemarks = true);

    final controller = ref.read(attendanceDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final draft = AttendanceRecord(
      id: existing.id,
      employeeId: _employeeId,
      attendanceDate: existing.attendanceDate,
      checkIn: existing.checkIn,
      checkOut: existing.checkOut,
      workHours: existing.workHours,
      lateMinutes: existing.lateMinutes,
      overtimeHours: existing.overtimeHours,
      status: existing.status,
      remarks: trimmed.isEmpty ? null : trimmed,
      createdAt: existing.createdAt,
      updatedAt: null,
    );

    try {
      await controller.saveAttendance(draft);
      if (!mounted) return;
      final err = ref.read(attendanceDirectoryProvider).errorMessage;
      if (err != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not save remarks: $err'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save remarks: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingRemarks = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatLongDate(DateTime value) {
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${weekdays[value.weekday - 1]}, ${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String _formatHoursLabel(double value) {
    return '${value.toStringAsFixed(2)} hrs';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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

    // Re-build when the directory state changes so the punch UI stays in sync.
    final dirState = ref.watch(attendanceDirectoryProvider);
    final today = _findTodayRecord();
    final punchState = _resolvePunchState(today);

    final body = _PunchBody(
      employeeName: _employeeName ?? 'Your Account',
      today: DateTime.now(),
      record: today,
      punchState: punchState,
      isPunching: _isPunching,
      isSavingRemarks: _isSavingRemarks,
      remarksController: _remarksController,
      onCheckIn: _handleCheckIn,
      onCheckOut: _handleCheckOut,
      directoryError: dirState.errorMessage,
      formatTime: _formatTime,
      formatLongDate: _formatLongDate,
      formatHoursLabel: _formatHoursLabel,
    );

    if (widget.embedded) return body;

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
        title: Column(
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
              'Daily attendance',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: body,
    );
  }

  _PunchState _resolvePunchState(AttendanceRecord? record) {
    if (record == null) return _PunchState.beforeCheckIn;
    if (record.checkIn == null) return _PunchState.beforeCheckIn;
    if (record.checkOut == null) return _PunchState.betweenPunches;
    return _PunchState.completed;
  }
}

// ---------------------------------------------------------------------------
// Punch state machine
// ---------------------------------------------------------------------------

enum _PunchState { beforeCheckIn, betweenPunches, completed }

// ---------------------------------------------------------------------------
// Body widget
// ---------------------------------------------------------------------------

class _PunchBody extends StatelessWidget {
  const _PunchBody({
    required this.employeeName,
    required this.today,
    required this.record,
    required this.punchState,
    required this.isPunching,
    required this.isSavingRemarks,
    required this.remarksController,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.directoryError,
    required this.formatTime,
    required this.formatLongDate,
    required this.formatHoursLabel,
  });

  final String employeeName;
  final DateTime today;
  final AttendanceRecord? record;
  final _PunchState punchState;
  final bool isPunching;
  final bool isSavingRemarks;
  final TextEditingController remarksController;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final String? directoryError;
  final String Function(DateTime) formatTime;
  final String Function(DateTime) formatLongDate;
  final String Function(double) formatHoursLabel;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DateHeader(today: today, formatLongDate: formatLongDate),
              const SizedBox(height: 24),
              _PunchCard(
                punchState: punchState,
                isPunching: isPunching,
                record: record,
                onCheckIn: onCheckIn,
                onCheckOut: onCheckOut,
                formatTime: formatTime,
              ),
              if (directoryError != null) ...[
                const SizedBox(height: 12),
                _DirectoryErrorBanner(message: directoryError!),
              ],
              const SizedBox(height: 24),
              _SummaryCard(
                record: record,
                punchState: punchState,
                formatTime: formatTime,
                formatHoursLabel: formatHoursLabel,
              ),
              const SizedBox(height: 24),
              _RemarksField(
                controller: remarksController,
                isSaving: isSavingRemarks,
                punchState: punchState,
              ),
              const SizedBox(height: 16),
              _Legend(employeeName: employeeName),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.today, required this.formatLongDate});

  final DateTime today;
  final String Function(DateTime) formatLongDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: GoogleFonts.inter(
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatLongDate(today),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchCard extends StatelessWidget {
  const _PunchCard({
    required this.punchState,
    required this.isPunching,
    required this.record,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.formatTime,
  });

  final _PunchState punchState;
  final bool isPunching;
  final AttendanceRecord? record;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final String Function(DateTime) formatTime;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, onTap) = switch (punchState) {
      _PunchState.beforeCheckIn => (
        'Punch Check In Now',
        Icons.login_rounded,
        const Color(0xFF10B981),
        onCheckIn,
      ),
      _PunchState.betweenPunches => (
        'Punch Check Out Now',
        Icons.logout_rounded,
        const Color(0xFFEF4444),
        onCheckOut,
      ),
      _PunchState.completed => (
        'Day Completed',
        Icons.check_circle_rounded,
        const Color(0xFF6B7280),
        null,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _PunchTimeline(
            punchState: punchState,
            record: record,
            formatTime: formatTime,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                disabledForegroundColor: const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: (isPunching || onTap == null) ? null : onTap,
              icon: isPunching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Icon(icon, size: 22),
              label: Text(label),
            ),
          ),
        ],
      ),
    );
  }
}

class _PunchTimeline extends StatelessWidget {
  const _PunchTimeline({
    required this.punchState,
    required this.record,
    required this.formatTime,
  });

  final _PunchState punchState;
  final AttendanceRecord? record;
  final String Function(DateTime) formatTime;

  @override
  Widget build(BuildContext context) {
    final checkIn = record?.checkIn;
    final checkOut = record?.checkOut;

    return Row(
      children: [
        Expanded(
          child: _TimelineNode(
            label: 'Check In',
            time: checkIn == null ? null : formatTime(checkIn),
            isDone: checkIn != null,
            isActive: punchState == _PunchState.beforeCheckIn,
          ),
        ),
        Expanded(
          child: _TimelineConnector(
            active: punchState != _PunchState.beforeCheckIn,
          ),
        ),
        Expanded(
          child: _TimelineNode(
            label: 'Check Out',
            time: checkOut == null ? null : formatTime(checkOut),
            isDone: checkOut != null,
            isActive: punchState == _PunchState.betweenPunches,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.label,
    required this.time,
    required this.isDone,
    required this.isActive,
    this.alignEnd = false,
  });

  final String label;
  final String? time;
  final bool isDone;
  final bool isActive;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final accent = isActive
        ? const Color(0xFF4F46E5)
        : (isDone ? const Color(0xFF10B981) : const Color(0xFFCBD5E1));
    final alignment =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: 2),
          ),
          child: Icon(
            isDone ? Icons.check_rounded : Icons.access_time_rounded,
            color: accent,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.inter(
            fontSize: 11,
            letterSpacing: 1.0,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time ?? '— —',
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDone ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _DirectoryErrorBanner extends StatelessWidget {
  const _DirectoryErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.record,
    required this.punchState,
    required this.formatTime,
    required this.formatHoursLabel,
  });

  final AttendanceRecord? record;
  final _PunchState punchState;
  final String Function(DateTime) formatTime;
  final String Function(double) formatHoursLabel;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final entries = <_SummaryEntry>[
      _SummaryEntry(
        icon: Icons.calendar_today_rounded,
        label: 'Date',
        value: r?.attendanceDate == null
            ? '—'
            : '${r!.attendanceDate!.year.toString().padLeft(4, '0')}-${r.attendanceDate!.month.toString().padLeft(2, '0')}-${r.attendanceDate!.day.toString().padLeft(2, '0')}',
        color: const Color(0xFF4F46E5),
      ),
      _SummaryEntry(
        icon: Icons.label_important_rounded,
        label: 'Status',
        value: r == null ? '—' : AttendanceStatusOptions.label(r.status),
        color: r == null
            ? const Color(0xFF94A3B8)
            : AttendanceStatusOptions.color(r.status),
      ),
      _SummaryEntry(
        icon: Icons.login_rounded,
        label: 'Check In',
        value: r?.checkIn == null ? '—' : formatTime(r!.checkIn!),
        color: const Color(0xFF10B981),
      ),
      _SummaryEntry(
        icon: Icons.logout_rounded,
        label: 'Check Out',
        value: r?.checkOut == null ? '—' : formatTime(r!.checkOut!),
        color: const Color(0xFFEF4444),
      ),
      _SummaryEntry(
        icon: Icons.timelapse_rounded,
        label: 'Work Hours',
        value: r == null ? '—' : formatHoursLabel(r.workHours),
        color: const Color(0xFF0EA5E9),
      ),
      _SummaryEntry(
        icon: Icons.hourglass_bottom_rounded,
        label: 'Late',
        value: r == null
            ? '—'
            : '${r.lateMinutes} min${r.lateMinutes == 1 ? '' : 's'}',
        color: r != null && r.lateMinutes > 0
            ? const Color(0xFFF59E0B)
            : const Color(0xFF94A3B8),
      ),
      _SummaryEntry(
        icon: Icons.trending_up_rounded,
        label: 'Overtime',
        value: r == null ? '—' : formatHoursLabel(r.overtimeHours),
        color: r != null && r.overtimeHours > 0
            ? const Color(0xFF8B5CF6)
            : const Color(0xFF94A3B8),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Details",
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth >= 480 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 2.4,
                children: [
                  for (final entry in entries) _SummaryTile(entry: entry),
                ],
              );
            },
          ),
          if (punchState != _PunchState.completed) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDBEAFE)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      punchState == _PunchState.beforeCheckIn
                          ? 'Punch in to begin tracking. Work hours, late and overtime will fill in when you punch out.'
                          : 'Your work hours, late minutes and overtime will be calculated automatically on check out.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryEntry {
  const _SummaryEntry({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.entry});

  final _SummaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(entry.icon, size: 16, color: entry.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  entry.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RemarksField extends StatelessWidget {
  const _RemarksField({
    required this.controller,
    required this.isSaving,
    required this.punchState,
  });

  final TextEditingController controller;
  final bool isSaving;
  final _PunchState punchState;

  @override
  Widget build(BuildContext context) {
    final hint = punchState == _PunchState.beforeCheckIn
        ? 'Optional notes — will be saved with your first punch'
        : 'Optional notes (e.g. sick, worked remote) — saved automatically';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Remarks',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (isSaving)
                Row(
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Saving...',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'Auto-saved',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
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
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.employeeName});

  final String employeeName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Punching as $employeeName. Late is auto-detected for check-ins after 09:00.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
