import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/hr.dart';

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

String _nextCode(String prefix) {
  final token = DateTime.now().millisecondsSinceEpoch
      .toRadixString(36)
      .toUpperCase();
  final compact = token.length > 6 ? token.substring(token.length - 6) : token;
  return '$prefix-$compact';
}

// ===========================================================================
// Employees
// ===========================================================================

class EmployeeDirectoryState {
  const EmployeeDirectoryState({
    required this.employees,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    required this.statusFilter,
    required this.departmentFilter,
    this.errorMessage,
  });

  factory EmployeeDirectoryState.initial() => const EmployeeDirectoryState(
    employees: <EmployeeRecord>[],
    isLoading: false,
    isSaving: false,
    searchQuery: '',
    statusFilter: null,
    departmentFilter: null,
  );

  final List<EmployeeRecord> employees;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? statusFilter;
  final String? departmentFilter;
  final String? errorMessage;

  EmployeeDirectoryState copyWith({
    List<EmployeeRecord>? employees,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? departmentFilter,
    bool clearDepartmentFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return EmployeeDirectoryState(
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      departmentFilter: clearDepartmentFilter
          ? null
          : (departmentFilter ?? this.departmentFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class EmployeeDirectoryController
    extends StateNotifier<EmployeeDirectoryState> {
  EmployeeDirectoryController() : super(EmployeeDirectoryState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        employees: const <EmployeeRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load employees.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final employees = await _client
          .from('employees')
          .select()
          .order('created_at', ascending: false);

      state = state.copyWith(
        isLoading: false,
        employees: List<Map<String, dynamic>>.from(
          employees,
        ).map(EmployeeRecord.fromMap).toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load employees.'),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? status) {
    if (status == null || status.isEmpty) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  void setDepartmentFilter(String? department) {
    if (department == null || department.isEmpty) {
      state = state.copyWith(clearDepartmentFilter: true);
    } else {
      state = state.copyWith(departmentFilter: department);
    }
  }

  Future<void> saveEmployee(EmployeeRecord employee) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save employees.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = employee.toMap();
      if (employee.id == null) {
        if ((payload['employee_code'] as String?)?.trim().isEmpty ?? true) {
          payload['employee_code'] = _nextCode('EMP');
        }
        await _client.from('employees').insert(payload);
      } else {
        await _client.from('employees').update(payload).eq('id', employee.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save employee.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteEmployee(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete employees.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('employees').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete employee.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final employeeDirectoryProvider =
    StateNotifierProvider<EmployeeDirectoryController, EmployeeDirectoryState>((
      ref,
    ) {
      return EmployeeDirectoryController();
    });

// ===========================================================================
// HR KPI
// ===========================================================================

/// Active employee count for the dashboard "Employees" KPI. Reads
/// from `public.employees` where `status = 'active'`. Returns 0 if
/// Supabase isn't configured or the user isn't allowed to read it.
class ActiveHrEmployeeCountController extends StateNotifier<AsyncValue<int>> {
  ActiveHrEmployeeCountController() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    if (!_supabaseReady()) {
      state = const AsyncValue.data(0);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final data = await _client
          .from('employees')
          .select('id')
          .eq('status', 'active');
      state = AsyncValue.data(List<Map<String, dynamic>>.from(data).length);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> refresh() => _load();
}

final activeHrEmployeeCountProvider =
    StateNotifierProvider<ActiveHrEmployeeCountController, AsyncValue<int>>((
      ref,
    ) {
      return ActiveHrEmployeeCountController();
    });
