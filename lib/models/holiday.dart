import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Holiday type options
// ---------------------------------------------------------------------------

class HolidayTypeOptions {
  static const List<String> values = <String>[
    'Public',
    'Religious',
    'Observance',
    'Company',
    'Optional',
  ];

  static const String defaultValue = 'Public';

  static String label(String value) {
    if (value.trim().isEmpty) return defaultValue;
    return value;
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'public':
        return const Color(0xFF3B82F6); // blue
      case 'religious':
        return const Color(0xFF8B5CF6); // violet
      case 'observance':
        return const Color(0xFFF59E0B); // amber
      case 'company':
        return const Color(0xFF10B981); // green
      case 'optional':
        return const Color(0xFF6B7280); // gray
      default:
        return const Color(0xFF6B7280);
    }
  }
}

// ---------------------------------------------------------------------------
// Holiday
// ---------------------------------------------------------------------------

class HolidayRecord {
  const HolidayRecord({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HolidayRecord.empty() {
    return const HolidayRecord(
      id: null,
      name: '',
      date: null,
      type: HolidayTypeOptions.defaultValue,
      createdAt: null,
      updatedAt: null,
    );
  }

  factory HolidayRecord.fromMap(Map<String, dynamic> data) {
    return HolidayRecord(
      id: data['id']?.toString(),
      name: (data['holiday_name'] ?? '').toString(),
      date: _parseDate(data['holiday_date']?.toString()),
      type: (data['holiday_type'] ?? HolidayTypeOptions.defaultValue).toString(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
    );
  }

  final String? id;
  final String name;
  final DateTime? date;
  final String type;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get typeLabel => HolidayTypeOptions.label(type);

  Color get typeColor => HolidayTypeOptions.color(type);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'holiday_name': name.trim(),
      'holiday_date': _formatDate(date),
      'holiday_type': type,
    };
  }

  HolidayRecord copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HolidayRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
