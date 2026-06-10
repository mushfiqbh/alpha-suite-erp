import 'package:flutter/material.dart';

String? _emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

// ---------------------------------------------------------------------------
// Shift
// ---------------------------------------------------------------------------

/// Holds a "HH:MM" or "HH:MM:SS" time string. The application uses the
/// `TimeOfDay` type for editing and converts to/from this string when
/// talking to Supabase (Postgres `time` columns round-trip as text).
class ShiftTime {
  const ShiftTime._(this.hour, this.minute);

  factory ShiftTime(int hour, int minute) {
    return ShiftTime._(hour.clamp(0, 23), minute.clamp(0, 59));
  }

  static ShiftTime? parse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return ShiftTime(h, m);
  }

  final int hour;
  final int minute;

  TimeOfDay get timeOfDay => TimeOfDay(hour: hour, minute: minute);

  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  String toString() => format();
}

class ShiftRecord {
  const ShiftRecord({
    required this.id,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
    required this.workingHours,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShiftRecord.empty() {
    return const ShiftRecord(
      id: null,
      shiftName: '',
      startTime: null,
      endTime: null,
      graceMinutes: 0,
      workingHours: 0,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory ShiftRecord.fromMap(Map<String, dynamic> data) {
    return ShiftRecord(
      id: data['id']?.toString(),
      shiftName: (data['shift_name'] ?? '').toString(),
      startTime: ShiftTime.parse(data['start_time']?.toString()),
      endTime: ShiftTime.parse(data['end_time']?.toString()),
      graceMinutes: _parseInt(data['grace_minutes']),
      workingHours: _parseDouble(data['working_hours']),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String shiftName;
  final ShiftTime? startTime;
  final ShiftTime? endTime;
  final int graceMinutes;
  final double workingHours;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayWindow {
    if (startTime == null || endTime == null) {
      return '—';
    }
    return '${startTime!.format()} – ${endTime!.format()}';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'shift_name': shiftName.trim(),
      'start_time': startTime?.format(),
      'end_time': endTime?.format(),
      'grace_minutes': graceMinutes,
      'working_hours': workingHours,
    };
  }

  ShiftRecord copyWith({
    String? id,
    String? shiftName,
    ShiftTime? startTime,
    ShiftTime? endTime,
    int? graceMinutes,
    double? workingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShiftRecord(
      id: id ?? this.id,
      shiftName: shiftName ?? this.shiftName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      workingHours: workingHours ?? this.workingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Employee shift assignment
// ---------------------------------------------------------------------------

class EmployeeShiftRecord {
  const EmployeeShiftRecord({
    required this.id,
    required this.employeeId,
    required this.shiftId,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeShiftRecord.empty() {
    return const EmployeeShiftRecord(
      id: null,
      employeeId: null,
      shiftId: null,
      effectiveFrom: null,
      effectiveTo: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory EmployeeShiftRecord.fromMap(Map<String, dynamic> data) {
    return EmployeeShiftRecord(
      id: data['id']?.toString(),
      employeeId: data['employee_id']?.toString(),
      shiftId: data['shift_id']?.toString(),
      effectiveFrom: _parseDate(data['effective_from']?.toString()),
      effectiveTo: _parseDate(data['effective_to']?.toString()),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String? employeeId;
  final String? shiftId;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employee_id': _emptyToNull(employeeId),
      'shift_id': _emptyToNull(shiftId),
      'effective_from': _formatDate(effectiveFrom),
      'effective_to': _formatDate(effectiveTo),
    };
  }

  EmployeeShiftRecord copyWith({
    String? id,
    String? employeeId,
    String? shiftId,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeShiftRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      shiftId: shiftId ?? this.shiftId,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? _parseDate(String? value) {
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
