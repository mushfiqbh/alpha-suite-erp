import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/access_request.dart';

/// Manages role access requests submitted by viewer-role users
/// and approved / rejected by admins.
class AccessRequestService {
  AccessRequestService() {
    _isConfigured = SupabaseConfig.isConfigured;
    _client = Supabase.instance.client;
  }

  late final bool _isConfigured;
  late final SupabaseClient _client;

  /// Submit a new access request for the current user.
  Future<AccessRequestRecord> submitRequest({
    required String userId,
    required String requestedRole,
    String? note,
  }) async {
    if (!_isConfigured) throw Exception('Supabase not configured');
    if (userId.isEmpty) throw Exception('User ID is required');

    final payload = <String, dynamic>{
      'user_id': userId,
      'requested_role': requestedRole.toLowerCase(),
      'status': 'pending',
      if (note != null && note.trim().isNotEmpty) 'notes': note.trim(),
    };

    final inserted = await _client
        .from('access_requests')
        .insert(payload)
        .select()
        .single();

    return AccessRequestRecord.fromMap(inserted);
  }

  /// Fetch pending access requests (admin use).
  Future<List<AccessRequestRecord>> listPendingRequests() async {
    if (!_isConfigured) return [];

    final data = await _client
        .from('access_requests')
        .select('*, profiles:user_id(full_name, email)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return data.map((row) => AccessRequestRecord.fromMap(row)).toList();
  }

  /// Fetch all access requests for the current user.
  Future<List<AccessRequestRecord>> listMyRequests(String userId) async {
    if (!_isConfigured) return [];
    if (userId.isEmpty) return [];

    final data = await _client
        .from('access_requests')
        .select('*, profiles:user_id(full_name, email)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return data.map((row) => AccessRequestRecord.fromMap(row)).toList();
  }

  /// Fetch all access requests (admin view).
  Future<List<AccessRequestRecord>> listAllRequests() async {
    if (!_isConfigured) return [];

    final data = await _client
        .from('access_requests')
        .select('*, profiles:user_id(full_name, email)')
        .order('created_at', ascending: false);

    return data.map((row) => AccessRequestRecord.fromMap(row)).toList();
  }

  /// Approve an access request: updates the request status and
  /// promotes the user's role in the profiles table.
  Future<void> approveRequest({
    required String requestId,
    required String reviewerId,
    required String userId,
    required String role,
  }) async {
    if (!_isConfigured) return;
    if (requestId.isEmpty) return;

    // Update the request status.
    await _client
        .from('access_requests')
        .update({
          'status': 'approved',
          'reviewed_by': reviewerId,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', requestId);

    // Promote the user's role.
    await _client.from('profiles').update({'role': role}).eq('id', userId);
  }

  /// Reject an access request.
  Future<void> rejectRequest({
    required String requestId,
    required String reviewerId,
    String? reason,
  }) async {
    if (!_isConfigured) return;
    if (requestId.isEmpty) return;

    await _client
        .from('access_requests')
        .update({
          'status': 'rejected',
          'reviewed_by': reviewerId,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          if (reason != null && reason.trim().isNotEmpty)
            'notes': reason.trim(),
        })
        .eq('id', requestId);
  }
}
