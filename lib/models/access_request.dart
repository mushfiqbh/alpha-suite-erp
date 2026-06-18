/// Models for the role access request workflow.
/// Mirrors the public.access_requests table defined in
/// `lib/migrations/0008_create_access_requests_table.sql`.
library;

import 'package:flutter/foundation.dart';

import 'package:erp/providers/auth_providers.dart';

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

@immutable
class AccessRequestRecord {
  const AccessRequestRecord({
    required this.id,
    required this.userId,
    required this.requestedRole,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.notes,
    this.userName,
    this.userEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AccessRequestRecord.fromMap(Map<String, dynamic> data) {
    // Extract nested profile data if joined
    final profileData = data['profiles'] as Map<String, dynamic>?;
    return AccessRequestRecord(
      id: data['id']?.toString(),
      userId: data['user_id'].toString(),
      requestedRole: (data['requested_role'] ?? 'viewer').toString(),
      status: (data['status'] ?? 'pending').toString(),
      reviewedBy: data['reviewed_by']?.toString(),
      reviewedAt: _parseDate(data['reviewed_at']),
      notes: data['notes']?.toString(),
      userName: profileData?['full_name']?.toString(),
      userEmail: profileData?['email']?.toString(),
      createdAt: _parseDate(data['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(data['updated_at']) ?? DateTime.now(),
    );
  }

  final String? id;
  final String userId;
  final String requestedRole;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? notes;
  final String? userName;
  final String? userEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserRole? get requestedUserRole {
    return UserRole.values.cast<UserRole?>().firstWhere(
      (r) => r!.name == requestedRole,
      orElse: () => null,
    );
  }

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isRejected => status.toLowerCase() == 'rejected';

  AccessRequestRecord copyWith({
    String? id,
    String? userId,
    String? requestedRole,
    String? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? notes,
    String? userName,
    String? userEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AccessRequestRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      requestedRole: requestedRole ?? this.requestedRole,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      notes: notes ?? this.notes,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
