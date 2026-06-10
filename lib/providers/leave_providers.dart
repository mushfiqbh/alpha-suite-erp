import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/leave.dart';

// ===========================================================================
// Shared helpers
// ===========================================================================

String _formatError(Object error, String fallback) {
  final message = error.toString();
  if (error is AuthRetryableFetchException ||
      message.contains('Failed to fetch') ||
      message.contains('ClientException') ||
      message.contains('SocketException')) {
    return 'Connection error: Unable to reach Supabase. Check your network and configuration.';
  }
  return message.isEmpty ? fallback : message;
}

bool _supabaseReady() {
  return SupabaseConfig.isConfigured && Supabase.instance.isInitialized;
}

SupabaseClient get _client => Supabase.instance.client;

// ===========================================================================
// Leave Types
// ===========================================================================

class LeaveTypeDirectoryState {
  const LeaveTypeDirectoryState({
    required this.types,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    this.errorMessage,
  });

  factory LeaveTypeDirectoryState.initial() => const LeaveTypeDirectoryState(
        types: <LeaveTypeRecord>[],
        isLoading: false,
        isSaving: false,
        searchQuery: '',
      );

  final List<LeaveTypeRecord> types;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? errorMessage;

  LeaveTypeDirectoryState copyWith({
    List<LeaveTypeRecord>? types,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeaveTypeDirectoryState(
      types: types ?? this.types,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LeaveTypeDirectoryController
    extends StateNotifier<LeaveTypeDirectoryState> {
  LeaveTypeDirectoryController() : super(LeaveTypeDirectoryState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        types: const <LeaveTypeRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load leave types.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _client.from('leave_types').select().order('name');
      state = state.copyWith(
        isLoading: false,
        types: List<Map<String, dynamic>>.from(data)
            .map(LeaveTypeRecord.fromMap)
            .toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load leave types.'),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> saveLeaveType(LeaveTypeRecord record) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save leave types.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = record.toMap();
      if (record.id == null) {
        await _client.from('leave_types').insert(payload);
      } else {
        await _client.from('leave_types').update(payload).eq('id', record.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save leave type.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteLeaveType(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete leave types.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('leave_types').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete leave type.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final leaveTypeDirectoryProvider = StateNotifierProvider<
    LeaveTypeDirectoryController, LeaveTypeDirectoryState>((ref) {
  return LeaveTypeDirectoryController();
});

// ===========================================================================
// Leave Requests
// ===========================================================================

class LeaveRequestDirectoryState {
  const LeaveRequestDirectoryState({
    required this.requests,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    required this.approvalStatusFilter,
    this.errorMessage,
  });

  factory LeaveRequestDirectoryState.initial() =>
      const LeaveRequestDirectoryState(
        requests: <LeaveRequestRecord>[],
        isLoading: false,
        isSaving: false,
        searchQuery: '',
        approvalStatusFilter: null,
      );

  final List<LeaveRequestRecord> requests;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? approvalStatusFilter;
  final String? errorMessage;

  LeaveRequestDirectoryState copyWith({
    List<LeaveRequestRecord>? requests,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? approvalStatusFilter,
    bool clearApprovalStatusFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LeaveRequestDirectoryState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      approvalStatusFilter: clearApprovalStatusFilter
          ? null
          : (approvalStatusFilter ?? this.approvalStatusFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class LeaveRequestDirectoryController
    extends StateNotifier<LeaveRequestDirectoryState> {
  LeaveRequestDirectoryController()
      : super(LeaveRequestDirectoryState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        requests: const <LeaveRequestRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load leave requests.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var query = _client.from('leave_requests').select();
      final filter = state.approvalStatusFilter;
      if (filter != null && filter.isNotEmpty && filter != 'All') {
        query = query.eq('approval_status', filter);
      }
      final data = await query.order('from_date', ascending: false);
      state = state.copyWith(
        isLoading: false,
        requests: List<Map<String, dynamic>>.from(data)
            .map(LeaveRequestRecord.fromMap)
            .toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load leave requests.'),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setApprovalStatusFilter(String? status) {
    if (status == null || status.isEmpty || status == 'All') {
      state = state.copyWith(clearApprovalStatusFilter: true);
    } else {
      state = state.copyWith(approvalStatusFilter: status);
    }
    refresh();
  }

  Future<void> saveLeaveRequest(LeaveRequestRecord record) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save leave requests.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = record.toMap();
      if (record.id == null) {
        await _client.from('leave_requests').insert(payload);
      } else {
        await _client
            .from('leave_requests')
            .update(payload)
            .eq('id', record.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save leave request.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> updateLeaveRequest(
    LeaveRequestRecord record,
    Map<String, dynamic> patch,
  ) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to update leave requests.',
      );
      return;
    }
    if (record.id == null) {
      state = state.copyWith(
        errorMessage: 'Cannot update a leave request that has not been saved.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client
          .from('leave_requests')
          .update(patch)
          .eq('id', record.id!);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to update leave request.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> approve(LeaveRequestRecord record, String approverId) async {
    final updated = record.copyWith(approvalStatus: 'approved');
    await updateLeaveRequest(updated, updated.toApprovalMap(approverId: approverId));
  }

  Future<void> reject(LeaveRequestRecord record, String approverId) async {
    final updated = record.copyWith(approvalStatus: 'rejected');
    await updateLeaveRequest(updated, updated.toApprovalMap(approverId: approverId));
  }

  Future<void> deleteLeaveRequest(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete leave requests.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('leave_requests').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete leave request.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final leaveRequestDirectoryProvider = StateNotifierProvider<
    LeaveRequestDirectoryController, LeaveRequestDirectoryState>((ref) {
  return LeaveRequestDirectoryController();
});
