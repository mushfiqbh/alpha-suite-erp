import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/holiday.dart';

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
// Holidays
// ===========================================================================

class HolidayDirectoryState {
  const HolidayDirectoryState({
    required this.holidays,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    required this.typeFilter,
    this.errorMessage,
  });

  factory HolidayDirectoryState.initial() => const HolidayDirectoryState(
        holidays: <HolidayRecord>[],
        isLoading: false,
        isSaving: false,
        searchQuery: '',
        typeFilter: null,
      );

  final List<HolidayRecord> holidays;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? typeFilter;
  final String? errorMessage;

  HolidayDirectoryState copyWith({
    List<HolidayRecord>? holidays,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? typeFilter,
    bool clearTypeFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HolidayDirectoryState(
      holidays: holidays ?? this.holidays,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class HolidayDirectoryController
    extends StateNotifier<HolidayDirectoryState> {
  HolidayDirectoryController() : super(HolidayDirectoryState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        isLoading: false,
        holidays: const <HolidayRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load holidays.',
      );
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var query = _client.from('holidays').select();
      final filter = state.typeFilter;
      if (filter != null && filter.isNotEmpty && filter != 'All') {
        query = query.eq('holiday_type', filter);
      }
      final data = await query.order('holiday_date');
      state = state.copyWith(
        isLoading: false,
        holidays: List<Map<String, dynamic>>.from(data)
            .map(HolidayRecord.fromMap)
            .toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load holidays.'),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setTypeFilter(String? type) {
    if (type == null || type.isEmpty || type == 'All') {
      state = state.copyWith(clearTypeFilter: true);
    } else {
      state = state.copyWith(typeFilter: type);
    }
    refresh();
  }

  Future<void> saveHoliday(HolidayRecord record) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save holidays.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      final payload = record.toMap();
      if (record.id == null) {
        await _client.from('holidays').insert(payload);
      } else {
        await _client.from('holidays').update(payload).eq('id', record.id!);
      }
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save holiday.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteHoliday(String id) async {
    if (!_supabaseReady()) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete holidays.',
      );
      return;
    }
    state = state.copyWith(isSaving: true, clearError: true);
    try {
      await _client.from('holidays').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete holiday.'),
      );
      return;
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }
}

final holidayDirectoryProvider = StateNotifierProvider<
    HolidayDirectoryController, HolidayDirectoryState>((ref) {
  return HolidayDirectoryController();
});
