import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/attendance.dart';

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
  if (message.contains('row-level security') || message.contains('42501')) {
    return 'Permission denied: Your account does not have the required role to perform this action. Contact an administrator.';
  }
  return message.isEmpty ? fallback : message;
}

bool _supabaseReady() {
  return SupabaseConfig.isConfigured && Supabase.instance.isInitialized;
}

SupabaseClient get _client => Supabase.instance.client;

// ===========================================================================
// Attendance
// ===========================================================================

class AttendanceDirectoryState {
  const AttendanceDirectoryState({
    required this.records,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    required this.statusFilter,
    this.errorMessage,
  });

  factory AttendanceDirectoryState.initial() => const AttendanceDirectoryState(
    records: <AttendanceRecord>[],
    isLoading: false,
    isSaving: false,
    searchQuery: '',
    statusFilter: null,
  );

  final List<AttendanceRecord> records;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? statusFilter;
  final String? errorMessage;

  AttendanceDirectoryState copyWith({
    List<AttendanceRecord>? records,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AttendanceDirectoryState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AttendanceDirectoryController
    extends StateNotifier<AttendanceDirectoryState> {
  AttendanceDirectoryController() : super(AttendanceDirectoryState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        records: const <AttendanceRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load attendance.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var query = _client.from('attendance').select();
      final filter = state.statusFilter;
      if (filter != null && filter.isNotEmpty && filter != 'All') {
        query = query.eq('attendance_status', filter);
      }
      final data = await query.order('attendance_date', ascending: false);
      state = state.copyWith(
        isLoading: false,
        records: List<Map<String, dynamic>>.from(
          data,
        ).map(AttendanceRecord.fromMap).toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load attendance.'),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? status) {
    if (status == null || status.isEmpty || status == 'All') {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
    refresh();
  }

  Future<void> saveAttendance(AttendanceRecord record) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save attendance.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = record.toMap();
      if (record.id == null) {
        await _client.from('attendance').insert(payload);
      } else {
        await _client.from('attendance').update(payload).eq('id', record.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save attendance.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  /// Saves (inserts or updates) multiple attendance records in a single batch
  /// without emitting intermediate state updates.  Calls [refresh] once after
  /// all saves complete.
  Future<({int saved, int errors})> saveAttendanceBatch(
    List<AttendanceRecord> records,
  ) async {
    int saved = 0;
    int errors = 0;

    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save attendance.',
      );
      return (saved: 0, errors: records.length);
    }

    for (final record in records) {
      try {
        final payload = record.toMap();
        if (record.id == null) {
          await _client.from('attendance').insert(payload);
        } else {
          await _client.from('attendance').update(payload).eq('id', record.id!);
        }
        saved++;
      } catch (_) {
        errors++;
      }
    }

    await refresh();
    return (saved: saved, errors: errors);
  }

  Future<void> deleteAttendance(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete attendance.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('attendance').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete attendance.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final attendanceDirectoryProvider =
    StateNotifierProvider<
      AttendanceDirectoryController,
      AttendanceDirectoryState
    >((ref) {
      return AttendanceDirectoryController();
    });

// ===========================================================================
// Attendance Logs
// ===========================================================================

class AttendanceLogDirectoryState {
  const AttendanceLogDirectoryState({
    required this.logs,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    required this.logTypeFilter,
    this.errorMessage,
  });

  factory AttendanceLogDirectoryState.initial() =>
      const AttendanceLogDirectoryState(
        logs: <AttendanceLogRecord>[],
        isLoading: false,
        isSaving: false,
        searchQuery: '',
        logTypeFilter: null,
      );

  final List<AttendanceLogRecord> logs;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? logTypeFilter;
  final String? errorMessage;

  AttendanceLogDirectoryState copyWith({
    List<AttendanceLogRecord>? logs,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? logTypeFilter,
    bool clearLogTypeFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AttendanceLogDirectoryState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      logTypeFilter: clearLogTypeFilter
          ? null
          : (logTypeFilter ?? this.logTypeFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AttendanceLogDirectoryController
    extends StateNotifier<AttendanceLogDirectoryState> {
  AttendanceLogDirectoryController()
    : super(AttendanceLogDirectoryState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        logs: const <AttendanceLogRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load attendance logs.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var query = _client.from('attendance_logs').select();
      final filter = state.logTypeFilter;
      if (filter != null && filter.isNotEmpty && filter != 'All') {
        query = query.eq('log_type', filter);
      }
      final data = await query.order('log_time', ascending: false);
      state = state.copyWith(
        isLoading: false,
        logs: List<Map<String, dynamic>>.from(
          data,
        ).map(AttendanceLogRecord.fromMap).toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load attendance logs.'),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setLogTypeFilter(String? logType) {
    if (logType == null || logType.isEmpty || logType == 'All') {
      state = state.copyWith(clearLogTypeFilter: true);
    } else {
      state = state.copyWith(logTypeFilter: logType);
    }
    refresh();
  }

  Future<void> saveLog(AttendanceLogRecord record) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save attendance logs.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = record.toMap();
      if (record.id == null) {
        await _client.from('attendance_logs').insert(payload);
      } else {
        await _client
            .from('attendance_logs')
            .update(payload)
            .eq('id', record.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save attendance log.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteLog(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete attendance logs.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('attendance_logs').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete attendance log.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final attendanceLogDirectoryProvider =
    StateNotifierProvider<
      AttendanceLogDirectoryController,
      AttendanceLogDirectoryState
    >((ref) {
      return AttendanceLogDirectoryController();
    });
