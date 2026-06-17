import 'package:flutter/material.dart';

String? _emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _titleCase(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase());

  return words.join(' ');
}

// ---------------------------------------------------------------------------
// Employee
// ---------------------------------------------------------------------------

class EmployeeStatusOptions {
  static const List<String> values = <String>[
    'active',
    'inactive',
    'on_leave',
    'terminated',
  ];

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'on_leave':
        return 'On Leave';
      case 'terminated':
        return 'Terminated';
      default:
        return _titleCase(value);
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981);
      case 'inactive':
        return const Color(0xFF64748B);
      case 'on_leave':
        return const Color(0xFFF59E0B);
      case 'terminated':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF334155);
    }
  }
}

class EmploymentTypeOptions {
  static const List<String> values = <String>[
    'permanent',
    'contract',
    'intern',
    'probation',
    'part_time',
  ];

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'permanent':
        return 'Permanent';
      case 'contract':
        return 'Contract';
      case 'intern':
        return 'Intern';
      case 'probation':
        return 'Probation';
      case 'part_time':
        return 'Part Time';
      default:
        return _titleCase(value);
    }
  }
}

class GenderOptions {
  static const List<String?> values = <String?>[
    null,
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  ];

  static String label(String? value) {
    switch (value?.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      case 'other':
        return 'Other';
      case 'prefer_not_to_say':
        return 'Prefer not to say';
      default:
        return 'Unspecified';
    }
  }
}

class EmployeeRecord {
  const EmployeeRecord({
    required this.id,
    required this.employeeCode,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.gender,
    required this.dob,
    required this.joiningDate,
    required this.department,
    required this.designation,
    required this.managerId,
    required this.employmentType,
    required this.basicSalary,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeRecord.empty({String? employeeCode}) {
    return EmployeeRecord(
      id: null,
      employeeCode: employeeCode ?? '',
      firstName: '',
      lastName: null,
      email: null,
      phone: null,
      gender: null,
      dob: null,
      joiningDate: null,
      department: null,
      designation: null,
      managerId: null,
      employmentType: 'permanent',
      basicSalary: 0,
      status: 'active',
      createdAt: null,
      updatedAt: null,
    );
  }

  factory EmployeeRecord.fromMap(Map<String, dynamic> data) {
    return EmployeeRecord(
      id: data['id']?.toString(),
      employeeCode: (data['employee_code'] ?? '').toString(),
      firstName: (data['first_name'] ?? '').toString(),
      lastName: _emptyToNull(data['last_name']?.toString()),
      email: _emptyToNull(data['email']?.toString()),
      phone: _emptyToNull(data['phone']?.toString()),
      gender: _emptyToNull(data['gender']?.toString()),
      dob: _parseDate(data['dob']?.toString()),
      joiningDate: _parseDate(data['joining_date']?.toString()),
      department: _emptyToNull(data['department']?.toString()),
      designation: _emptyToNull(data['designation']?.toString()),
      managerId: data['manager_id']?.toString(),
      employmentType: (data['employment_type'] ?? 'permanent').toString(),
      basicSalary: _parseDouble(data['basic_salary']),
      status: (data['status'] ?? 'active').toString().toLowerCase(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String employeeCode;
  final String firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? gender;
  final DateTime? dob;
  final DateTime? joiningDate;
  final String? department;
  final String? designation;
  final String? managerId;
  final String employmentType;
  final double basicSalary;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get fullName {
    final first = firstName.trim();
    final last = (lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) {
      return employeeCode.isNotEmpty ? employeeCode : 'Unnamed Employee';
    }
    return [first, last].where((part) => part.isNotEmpty).join(' ');
  }

  String get initials {
    final first = firstName.trim();
    final last = (lastName ?? '').trim();
    if (first.isEmpty && last.isEmpty) {
      return employeeCode.isNotEmpty
          ? employeeCode.substring(0, 1).toUpperCase()
          : 'E';
    }
    final firstLetter = first.isNotEmpty ? first[0] : '';
    final lastLetter = last.isNotEmpty ? last[0] : '';
    return (firstLetter + lastLetter).toUpperCase();
  }

  String get displaySalary {
    return '₹${basicSalary.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'employee_code': employeeCode.trim(),
      'first_name': firstName.trim(),
      'last_name': _emptyToNull(lastName),
      'email': _emptyToNull(email),
      'phone': _emptyToNull(phone),
      'gender': _emptyToNull(gender),
      'dob': _formatDate(dob),
      'joining_date': _formatDate(joiningDate),
      'department': _emptyToNull(department),
      'designation': _emptyToNull(designation),
      'manager_id': _emptyToNull(managerId),
      'employment_type': employmentType.trim().isEmpty
          ? 'permanent'
          : employmentType.trim().toLowerCase(),
      'basic_salary': basicSalary,
      'status': status.trim().isEmpty ? 'active' : status.trim().toLowerCase(),
    };
  }

  EmployeeRecord copyWith({
    String? id,
    String? employeeCode,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? gender,
    DateTime? dob,
    DateTime? joiningDate,
    String? department,
    String? designation,
    String? managerId,
    String? employmentType,
    double? basicSalary,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeRecord(
      id: id ?? this.id,
      employeeCode: employeeCode ?? this.employeeCode,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      joiningDate: joiningDate ?? this.joiningDate,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      managerId: managerId ?? this.managerId,
      employmentType: employmentType ?? this.employmentType,
      basicSalary: basicSalary ?? this.basicSalary,
      status: status ?? this.status,
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

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

// ===========================================================================
// Payroll Period
// ===========================================================================

class PayrollPeriodStatusOptions {
  static const List<String> values = <String>['open', 'processing', 'closed'];

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'open':
        return 'Open';
      case 'processing':
        return 'Processing';
      case 'closed':
        return 'Closed';
      default:
        return _titleCase(value);
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'open':
        return const Color(0xFF10B981);
      case 'processing':
        return const Color(0xFFF59E0B);
      case 'closed':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF334155);
    }
  }
}

class PayrollPeriodRecord {
  const PayrollPeriodRecord({
    required this.id,
    required this.month,
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PayrollPeriodRecord.empty() {
    final now = DateTime.now();
    return PayrollPeriodRecord(
      id: null,
      month: now.month,
      year: now.year,
      startDate: null,
      endDate: null,
      status: 'open',
      createdAt: null,
      updatedAt: null,
    );
  }

  factory PayrollPeriodRecord.fromMap(Map<String, dynamic> data) {
    return PayrollPeriodRecord(
      id: data['id']?.toString(),
      month: _parseInt(data['month']),
      year: _parseInt(data['year']),
      startDate: _parseDate(data['start_date']?.toString()),
      endDate: _parseDate(data['end_date']?.toString()),
      status: (data['status'] ?? 'open').toString().toLowerCase(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final int month;
  final int year;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get periodLabel {
    return '${_monthName(month)} $year';
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'month': month,
      'year': year,
      'start_date': _formatDate(startDate),
      'end_date': _formatDate(endDate),
      'status': status.trim().isEmpty ? 'open' : status.trim().toLowerCase(),
    };
  }

  PayrollPeriodRecord copyWith({
    String? id,
    int? month,
    int? year,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayrollPeriodRecord(
      id: id ?? this.id,
      month: month ?? this.month,
      year: year ?? this.year,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ===========================================================================
// Payroll
// ===========================================================================

class PaymentStatusOptions {
  static const List<String> values = <String>['pending', 'paid', 'cancelled'];

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'paid':
        return 'Paid';
      case 'cancelled':
        return 'Cancelled';
      default:
        return _titleCase(value);
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'paid':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF334155);
    }
  }
}

class PayrollRecord {
  const PayrollRecord({
    required this.id,
    required this.payrollPeriodId,
    required this.employeeId,
    required this.basicSalary,
    required this.allowance,
    required this.overtime,
    required this.deduction,
    required this.tax,
    required this.netSalary,
    required this.paymentDate,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    // joined fields
    this.employeeName,
    this.employeeCode,
  });

  factory PayrollRecord.empty({
    String? payrollPeriodId,
    String? employeeId,
    double? basicSalary,
  }) {
    return PayrollRecord(
      id: null,
      payrollPeriodId: payrollPeriodId ?? '',
      employeeId: employeeId ?? '',
      basicSalary: basicSalary ?? 0,
      allowance: 0,
      overtime: 0,
      deduction: 0,
      tax: 0,
      netSalary: basicSalary ?? 0,
      paymentDate: null,
      paymentStatus: 'pending',
      createdAt: null,
      updatedAt: null,
    );
  }

  factory PayrollRecord.fromMap(Map<String, dynamic> data) {
    return PayrollRecord(
      id: data['id']?.toString(),
      payrollPeriodId: data['payroll_period_id']?.toString() ?? '',
      employeeId: data['employee_id']?.toString() ?? '',
      basicSalary: _parseDouble(data['basic_salary']),
      allowance: _parseDouble(data['allowance']),
      overtime: _parseDouble(data['overtime']),
      deduction: _parseDouble(data['deduction']),
      tax: _parseDouble(data['tax']),
      netSalary: _parseDouble(data['net_salary']),
      paymentDate: _parseDate(data['payment_date']?.toString()),
      paymentStatus: (data['payment_status'] ?? 'pending')
          .toString()
          .toLowerCase(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      employeeName: data['employee_name']?.toString(),
      employeeCode: data['employee_code']?.toString(),
    );
  }

  final String? id;
  final String payrollPeriodId;
  final String employeeId;
  final double basicSalary;
  final double allowance;
  final double overtime;
  final double deduction;
  final double tax;
  final double netSalary;
  final DateTime? paymentDate;
  final String paymentStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? employeeName;
  final String? employeeCode;

  double get grossSalary => basicSalary + allowance + overtime;
  double get totalDeductions => deduction + tax;

  String get displayNetSalary => '₹${netSalary.toStringAsFixed(2)}';

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'payroll_period_id': payrollPeriodId,
      'employee_id': employeeId,
      'basic_salary': basicSalary,
      'allowance': allowance,
      'overtime': overtime,
      'deduction': deduction,
      'tax': tax,
      'net_salary': netSalary,
      'payment_date': _formatDate(paymentDate),
      'payment_status': paymentStatus.trim().isEmpty
          ? 'pending'
          : paymentStatus.trim().toLowerCase(),
    };
  }

  PayrollRecord copyWith({
    String? id,
    String? payrollPeriodId,
    String? employeeId,
    double? basicSalary,
    double? allowance,
    double? overtime,
    double? deduction,
    double? tax,
    double? netSalary,
    DateTime? paymentDate,
    String? paymentStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? employeeName,
    String? employeeCode,
  }) {
    return PayrollRecord(
      id: id ?? this.id,
      payrollPeriodId: payrollPeriodId ?? this.payrollPeriodId,
      employeeId: employeeId ?? this.employeeId,
      basicSalary: basicSalary ?? this.basicSalary,
      allowance: allowance ?? this.allowance,
      overtime: overtime ?? this.overtime,
      deduction: deduction ?? this.deduction,
      tax: tax ?? this.tax,
      netSalary: netSalary ?? this.netSalary,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      employeeName: employeeName ?? this.employeeName,
      employeeCode: employeeCode ?? this.employeeCode,
    );
  }
}

String _monthName(int month) {
  const months = [
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
  if (month < 1 || month > 12) return 'Unknown';
  return months[month - 1];
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  return int.tryParse(value.toString()) ?? 0;
}
