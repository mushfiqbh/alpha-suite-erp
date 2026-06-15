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

// ===========================================================================
// Payroll Periods
// ===========================================================================

class PayrollPeriodListState {
  const PayrollPeriodListState({
    required this.periods,
    required this.isLoading,
    required this.isSaving,
    this.errorMessage,
  });

  factory PayrollPeriodListState.initial() => const PayrollPeriodListState(
    periods: <PayrollPeriodRecord>[],
    isLoading: false,
    isSaving: false,
  );

  final List<PayrollPeriodRecord> periods;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  PayrollPeriodListState copyWith({
    List<PayrollPeriodRecord>? periods,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PayrollPeriodListState(
      periods: periods ?? this.periods,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PayrollPeriodListController
    extends StateNotifier<PayrollPeriodListState> {
  PayrollPeriodListController() : super(PayrollPeriodListState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        periods: const <PayrollPeriodRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load payroll periods.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _client
          .from('payroll_periods')
          .select()
          .order('year', ascending: false)
          .order('month', ascending: false);

      state = state.copyWith(
        isLoading: false,
        periods: List<Map<String, dynamic>>.from(
          data,
        ).map(PayrollPeriodRecord.fromMap).toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load payroll periods.'),
      );
    }
  }

  Future<void> savePeriod(PayrollPeriodRecord period) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save payroll periods.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = period.toMap();
      if (period.id == null) {
        await _client.from('payroll_periods').insert(payload);
      } else {
        await _client
            .from('payroll_periods')
            .update(payload)
            .eq('id', period.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save payroll period.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deletePeriod(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete payroll periods.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('payroll_periods').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete payroll period.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final payrollPeriodListProvider =
    StateNotifierProvider<PayrollPeriodListController, PayrollPeriodListState>((
      ref,
    ) {
      return PayrollPeriodListController();
    });

// ===========================================================================
// Payrolls (per employee per period)
// ===========================================================================

class PayrollListState {
  const PayrollListState({
    required this.payrolls,
    required this.isLoading,
    required this.isSaving,
    this.errorMessage,
  });

  factory PayrollListState.initial() => const PayrollListState(
    payrolls: <PayrollRecord>[],
    isLoading: false,
    isSaving: false,
  );

  final List<PayrollRecord> payrolls;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  PayrollListState copyWith({
    List<PayrollRecord>? payrolls,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PayrollListState(
      payrolls: payrolls ?? this.payrolls,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class PayrollListController extends StateNotifier<PayrollListState> {
  PayrollListController() : super(PayrollListState.initial());

  String? _periodIdFilter;

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        payrolls: const <PayrollRecord>[],
        errorMessage: 'Supabase is not configured.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var query = _client.from('payrolls').select('''
            *,
            employee:employee_id (
              first_name,
              last_name,
              employee_code
            )
          ''');

      if (_periodIdFilter != null) {
        query = query.eq('payroll_period_id', _periodIdFilter!);
      }

      final data = await query.order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(data).map((row) {
        final employee = row['employee'] as Map<String, dynamic>?;
        final firstName = employee?['first_name']?.toString() ?? '';
        final lastName = employee?['last_name']?.toString() ?? '';
        final name = [
          firstName,
          lastName,
        ].where((p) => p.trim().isNotEmpty).join(' ');

        return PayrollRecord.fromMap({
          ...row,
          'employee_name': name.isNotEmpty ? name : null,
          'employee_code': employee?['employee_code']?.toString(),
        });
      }).toList();

      state = state.copyWith(
        isLoading: false,
        payrolls: list,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load payrolls.'),
      );
    }
  }

  void setPeriodFilter(String? periodId) {
    _periodIdFilter = periodId;
    refresh();
  }

  Future<void> savePayroll(PayrollRecord payroll) async {
    if (!_supabaseReady()) {
      state = state.copyWith(errorMessage: 'Supabase is not configured.');
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = payroll.toMap();
      if (payroll.id == null) {
        await _client.from('payrolls').insert(payload);
      } else {
        await _client.from('payrolls').update(payload).eq('id', payroll.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save payroll.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deletePayroll(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(errorMessage: 'Supabase is not configured.');
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('payrolls').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete payroll.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> bulkGenerate(String periodId, List<String> employeeIds) async {
    if (!_supabaseReady()) {
      state = state.copyWith(errorMessage: 'Supabase is not configured.');
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      // Fetch employees' basic salaries
      final empData = await _client
          .from('employees')
          .select('id, basic_salary')
          .inFilter('id', employeeIds);

      final rows = List<Map<String, dynamic>>.from(empData).map((e) {
        final salary = (e['basic_salary'] as num?)?.toDouble() ?? 0;
        return {
          'payroll_period_id': periodId,
          'employee_id': e['id'].toString(),
          'basic_salary': salary,
          'allowance': 0,
          'overtime': 0,
          'deduction': 0,
          'tax': 0,
          'net_salary': salary,
          'payment_status': 'pending',
        };
      }).toList();

      if (rows.isNotEmpty) {
        await _client.from('payrolls').insert(rows);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to generate payrolls.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final payrollListProvider =
    StateNotifierProvider<PayrollListController, PayrollListState>((ref) {
      return PayrollListController();
    });
