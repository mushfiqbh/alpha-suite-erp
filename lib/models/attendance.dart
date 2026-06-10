import 'package:flutter/material.dart';

import 'package:erp/models/hr.dart';

// ---------------------------------------------------------------------------
// Helpers (mirrors the small utility set used by hr.dart / shift.dart).
// ---------------------------------------------------------------------------

String? _emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

DateTime? _parseTimestamp(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? _formatDate(DateTime? value) {
  if (value == null) return null;
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String? _formatTimestamp(DateTime? value) {
  if (value == null) return null;
  return value.toUtc().toIso8601String();
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}



// ---------------------------------------------------------------------------
// Attendance status options
// ---------------------------------------------------------------------------

/// Status options stored in `public.attendance.attendance_status`. The
/// values are persisted lower-cased; `label()` produces the UI string.
class AttendanceStatusOptions {
  static const List<String> values = <String>[
    'Present',
    'Absent',
    'Late',
    'Half Day',
    'Holiday',
    'Weekend',
    'Leave',
  ];

  static const String defaultValue = 'Present';

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'present':
        return 'Present';
      case 'absent':
        return 'Absent';
      case 'late':
        return 'Late';
      case 'half_day':
      case 'half day':
        return 'Half Day';
      case 'holiday':
        return 'Holiday';
      case 'weekend':
        return 'Weekend';
      case 'leave':
        return 'On Leave';
      default:
        return value;
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'present':
        return const Color(0xFF10B981); // green
      case 'absent':
        return const Color(0xFFEF4444); // red
      case 'late':
        return const Color(0xFFF59E0B); // amber
      case 'half_day':
      case 'half day':
        return const Color(0xFF8B5CF6); // violet
      case 'holiday':
        return const Color(0xFF3B82F6); // blue
      case 'weekend':
        return const Color(0xFF6B7280); // gray
      case 'leave':
        return const Color(0xFF14B8A6); // teal
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ---------------------------------------------------------------------------
// Attendance record (one row per employee per day)
// ---------------------------------------------------------------------------

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.attendanceDate,
    required this.checkIn,
    required this.checkOut,
    required this.workHours,
    required this.lateMinutes,
    required this.overtimeHours,
    required this.status,
    required this.remarks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AttendanceRecord.empty() {
    return const AttendanceRecord(
      id: null,
      employeeId: null,
      attendanceDate: null,
      checkIn: null,
      checkOut: null,
      workHours: 0,
      lateMinutes: 0,
      overtimeHours: 0,
      status: AttendanceStatusOptions.defaultValue,
      remarks: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> data) {
    return AttendanceRecord(
      id: data['id']?.toString(),
      employeeId: data['employee_id']?.toString(),
      attendanceDate: _parseDate(data['attendance_date']?.toString()),
      checkIn: _parseTimestamp(data['check_in']?.toString()),
      checkOut: _parseTimestamp(data['check_out']?.toString()),
      workHours: _parseDouble(data['work_hours']),
      lateMinutes: _parseInt(data['late_minutes']),
      overtimeHours: _parseDouble(data['overtime_hours']),
      status: (data['attendance_status'] ?? AttendanceStatusOptions.defaultValue)
          .toString(),
      remarks: data['remarks']?.toString(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String? employeeId;
  final DateTime? attendanceDate;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double workHours;
  final int lateMinutes;
  final double overtimeHours;
  final String status;
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// Convenience: combine an employee + attendance record into a label
  /// used by the directory view when the FK has not been joined.
  String displayEmployee(EmployeeRecord? employee) {
    if (employee == null) {
      return 'Employee ${employeeId ?? 'â€”'}';
    }
    return '${employee.employeeCode} · ${employee.fullName}';
  }

  String get statusLabel => AttendanceStatusOptions.label(status);

  Color get statusColor => AttendanceStatusOptions.color(status);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employee_id': _emptyToNull(employeeId),
      'attendance_date': _formatDate(attendanceDate),
      'check_in': _formatTimestamp(checkIn),
      'check_out': _formatTimestamp(checkOut),
      'work_hours': workHours,
      'late_minutes': lateMinutes,
      'overtime_hours': overtimeHours,
      'attendance_status': status,
      'remarks': _emptyToNull(remarks),
    };
  }

  AttendanceRecord copyWith({
    String? id,
    String? employeeId,
    DateTime? attendanceDate,
    DateTime? checkIn,
    DateTime? checkOut,
    double? workHours,
    int? lateMinutes,
    double? overtimeHours,
    String? status,
    String? remarks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      workHours: workHours ?? this.workHours,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Attendance log (raw punch in/out events)
// ---------------------------------------------------------------------------

class AttendanceLogTypeOptions {
  static const List<String> values = <String>[
    'check_in',
    'check_out',
    'break_start',
    'break_end',
  ];

  static const String defaultValue = 'check_in';

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'check_in':
      case 'checkin':
        return 'Check In';
      case 'check_out':
      case 'checkout':
        return 'Check Out';
      case 'break_start':
        return 'Break Start';
      case 'break_end':
        return 'Break End';
      default:
        return value;
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'check_in':
      case 'checkin':
        return const Color(0xFF10B981);
      case 'check_out':
      case 'checkout':
        return const Color(0xFFEF4444);
      case 'break_start':
        return const Color(0xFFF59E0B);
      case 'break_end':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

class AttendanceLogRecord {
  const AttendanceLogRecord({
    required this.id,
    required this.employeeId,
    required this.logTime,
    required this.logType,
    required this.deviceId,
    required this.location,
    required this.createdAt,
  });

  factory AttendanceLogRecord.empty() {
    return const AttendanceLogRecord(
      id: null,
      employeeId: null,
      logTime: null,
      logType: AttendanceLogTypeOptions.defaultValue,
      deviceId: null,
      location: null,
      createdAt: null,
    );
  }

  factory AttendanceLogRecord.fromMap(Map<String, dynamic> data) {
    return AttendanceLogRecord(
      id: data['id']?.toString(),
      employeeId: data['employee_id']?.toString(),
      logTime: _parseTimestamp(data['log_time']?.toString()),
      logType:
          (data['log_type'] ?? AttendanceLogTypeOptions.defaultValue).toString(),
      deviceId: data['device_id']?.toString(),
      location: data['location']?.toString(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String? employeeId;
  final DateTime? logTime;
  final String logType;
  final String? deviceId;
  final String? location;
  final DateTime? createdAt;

  String get logTypeLabel => AttendanceLogTypeOptions.label(logType);

  Color get logTypeColor => AttendanceLogTypeOptions.color(logType);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employee_id': _emptyToNull(employeeId),
      'log_time': _formatTimestamp(logTime ?? DateTime.now()),
      'log_type': logType,
      'device_id': _emptyToNull(deviceId),
      'location': _emptyToNull(location),
    };
  }

  AttendanceLogRecord copyWith({
    String? id,
    String? employeeId,
    DateTime? logTime,
    String? logType,
    String? deviceId,
    String? location,
    DateTime? createdAt,
  }) {
    return AttendanceLogRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      logTime: logTime ?? this.logTime,
      logType: logType ?? this.logType,
      deviceId: deviceId ?? this.deviceId,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Unused helper retained for parity with other model files (bool writer).
// ---------------------------------------------------------------------------

// ignore: unused_element

