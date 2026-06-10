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
// Department
// ---------------------------------------------------------------------------

class DepartmentRecord {
  const DepartmentRecord({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DepartmentRecord.empty() {
    return const DepartmentRecord(
      id: null,
      name: '',
      description: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory DepartmentRecord.fromMap(Map<String, dynamic> data) {
    return DepartmentRecord(
      id: data['id']?.toString(),
      name: (data['name'] ?? '').toString(),
      description: _emptyToNull(data['description']?.toString()),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String name;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name.trim(),
      'description': _emptyToNull(description),
    };
  }

  DepartmentRecord copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DepartmentRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// Designation
// ---------------------------------------------------------------------------

class DesignationRecord {
  const DesignationRecord({
    required this.id,
    required this.departmentId,
    required this.title,
    required this.grade,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DesignationRecord.empty({String? departmentId}) {
    return DesignationRecord(
      id: null,
      departmentId: departmentId,
      title: '',
      grade: null,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory DesignationRecord.fromMap(Map<String, dynamic> data) {
    return DesignationRecord(
      id: data['id']?.toString(),
      departmentId: data['department_id']?.toString(),
      title: (data['title'] ?? '').toString(),
      grade: _emptyToNull(data['grade']?.toString()),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String? departmentId;
  final String title;
  final String? grade;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'department_id': _emptyToNull(departmentId),
      'title': title.trim(),
      'grade': _emptyToNull(grade),
    };
  }

  DesignationRecord copyWith({
    String? id,
    String? departmentId,
    String? title,
    String? grade,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DesignationRecord(
      id: id ?? this.id,
      departmentId: departmentId ?? this.departmentId,
      title: title ?? this.title,
      grade: grade ?? this.grade,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
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
    required this.departmentId,
    required this.designationId,
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
      departmentId: null,
      designationId: null,
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
      departmentId: data['department_id']?.toString(),
      designationId: data['designation_id']?.toString(),
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
  final String? departmentId;
  final String? designationId;
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
      'department_id': _emptyToNull(departmentId),
      'designation_id': _emptyToNull(designationId),
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
    String? departmentId,
    String? designationId,
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
      departmentId: departmentId ?? this.departmentId,
      designationId: designationId ?? this.designationId,
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
