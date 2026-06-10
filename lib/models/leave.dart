import 'package:flutter/material.dart';

import 'package:erp/models/hr.dart';

// ---------------------------------------------------------------------------
// Helpers (mirror the small utility set used by hr.dart / shift.dart).
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

bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final s = value.toString().toLowerCase().trim();
  return s == 'true' || s == 't' || s == '1' || s == 'yes';
}

// ---------------------------------------------------------------------------
// Leave type
// ---------------------------------------------------------------------------

class LeaveTypeRecord {
  const LeaveTypeRecord({
    required this.id,
    required this.name,
    required this.daysPerYear,
    required this.paidLeave,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveTypeRecord.empty() {
    return const LeaveTypeRecord(
      id: null,
      name: '',
      daysPerYear: 0,
      paidLeave: true,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory LeaveTypeRecord.fromMap(Map<String, dynamic> data) {
    return LeaveTypeRecord(
      id: data['id']?.toString(),
      name: (data['name'] ?? '').toString(),
      daysPerYear: _parseInt(data['days_per_year']),
      paidLeave: _parseBool(data['paid_leave']),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String name;
  final int daysPerYear;
  final bool paidLeave;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get paidLabel => paidLeave ? 'Paid' : 'Unpaid';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name.trim(),
      'days_per_year': daysPerYear,
      'paid_leave': paidLeave,
    };
  }

  LeaveTypeRecord copyWith({
    String? id,
    String? name,
    int? daysPerYear,
    bool? paidLeave,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveTypeRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      daysPerYear: daysPerYear ?? this.daysPerYear,
      paidLeave: paidLeave ?? this.paidLeave,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Leave approval status
// ---------------------------------------------------------------------------

class LeaveApprovalStatusOptions {
  static const List<String> values = <String>[
    'pending',
    'approved',
    'rejected',
  ];

  static const String defaultValue = 'pending';

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return value;
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B); // amber
      case 'approved':
        return const Color(0xFF10B981); // green
      case 'rejected':
        return const Color(0xFFEF4444); // red
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ---------------------------------------------------------------------------
// Leave request
// ---------------------------------------------------------------------------

class LeaveRequestRecord {
  const LeaveRequestRecord({
    required this.id,
    required this.employeeId,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    required this.totalDays,
    required this.reason,
    required this.approvalStatus,
    required this.approvedBy,
    required this.approvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LeaveRequestRecord.empty() {
    return const LeaveRequestRecord(
      id: null,
      employeeId: null,
      leaveTypeId: null,
      fromDate: null,
      toDate: null,
      totalDays: 1,
      reason: null,
      approvalStatus: LeaveApprovalStatusOptions.defaultValue,
      approvedBy: null,
      approvedAt: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory LeaveRequestRecord.fromMap(Map<String, dynamic> data) {
    return LeaveRequestRecord(
      id: data['id']?.toString(),
      employeeId: data['employee_id']?.toString(),
      leaveTypeId: data['leave_type_id']?.toString(),
      fromDate: _parseDate(data['from_date']?.toString()),
      toDate: _parseDate(data['to_date']?.toString()),
      totalDays: _parseDouble(data['total_days']),
      reason: data['reason']?.toString(),
      approvalStatus:
          (data['approval_status'] ?? LeaveApprovalStatusOptions.defaultValue)
              .toString(),
      approvedBy: data['approved_by']?.toString(),
      approvedAt: _parseTimestamp(data['approved_at']?.toString()),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String? employeeId;
  final String? leaveTypeId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double totalDays;
  final String? reason;
  final String approvalStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get statusLabel => LeaveApprovalStatusOptions.label(approvalStatus);

  Color get statusColor => LeaveApprovalStatusOptions.color(approvalStatus);

  /// Compute a "human" label for an employee FK without a join.
  String displayEmployee(EmployeeRecord? employee) {
    if (employee == null) {
      return 'Employee ${employeeId ?? 'â€”'}';
    }
    return '${employee.employeeCode} · ${employee.fullName}';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employee_id': _emptyToNull(employeeId),
      'leave_type_id': _emptyToNull(leaveTypeId),
      'from_date': _formatDate(fromDate),
      'to_date': _formatDate(toDate),
      'total_days': totalDays,
      'reason': _emptyToNull(reason),
      'approval_status': approvalStatus,
    };
  }

  /// Payload used when an approver (admin/hr) sets approved/rejected.
  Map<String, dynamic> toApprovalMap({required String approverId}) {
    return <String, dynamic>{
      'approval_status': approvalStatus,
      'approved_by': approverId,
      'approved_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  LeaveRequestRecord copyWith({
    String? id,
    String? employeeId,
    String? leaveTypeId,
    DateTime? fromDate,
    DateTime? toDate,
    double? totalDays,
    String? reason,
    String? approvalStatus,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequestRecord(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      leaveTypeId: leaveTypeId ?? this.leaveTypeId,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      totalDays: totalDays ?? this.totalDays,
      reason: reason ?? this.reason,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
