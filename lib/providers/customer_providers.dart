import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/customer.dart';

class CustomerDirectoryState {
  const CustomerDirectoryState({
    required this.customers,
    required this.assignees,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    required this.statusFilter,
    required this.typeFilter,
    this.errorMessage,
  });

  factory CustomerDirectoryState.initial() {
    return const CustomerDirectoryState(
      customers: <CustomerRecord>[],
      assignees: <ProfileOption>[],
      isLoading: false,
      isSaving: false,
      searchQuery: '',
      statusFilter: null,
      typeFilter: null,
      errorMessage: null,
    );
  }

  final List<CustomerRecord> customers;
  final List<ProfileOption> assignees;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? statusFilter;
  final String? typeFilter;
  final String? errorMessage;

  CustomerDirectoryState copyWith({
    List<CustomerRecord>? customers,
    List<ProfileOption>? assignees,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? typeFilter,
    bool clearTypeFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomerDirectoryState(
      customers: customers ?? this.customers,
      assignees: assignees ?? this.assignees,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CustomerDirectoryController
    extends StateNotifier<CustomerDirectoryState> {
  CustomerDirectoryController() : super(CustomerDirectoryState.initial()) {
    refresh();
  }

  SupabaseClient get _client => Supabase.instance.client;

  bool get _isConfigured =>
      SupabaseConfig.isConfigured && Supabase.instance.isInitialized;

  Future<void> refresh() async {
    if (!_isConfigured) {
      state = state.copyWith(
        isLoading: false,
        customers: const <CustomerRecord>[],
        assignees: const <ProfileOption>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load customers.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final customerData = await _client
          .from('customers')
          .select()
          .order('created_at', ascending: false);

      List<ProfileOption> assignees = const <ProfileOption>[];
      try {
        final profileData = await _client
            .from('profiles')
            .select('id, full_name, email')
            .order('full_name', ascending: true);
        assignees = List<Map<String, dynamic>>.from(
          profileData,
        ).map(ProfileOption.fromMap).toList();
      } catch (_) {
        assignees = const <ProfileOption>[];
      }

      state = state.copyWith(
        isLoading: false,
        customers: List<Map<String, dynamic>>.from(
          customerData,
        ).map(CustomerRecord.fromMap).toList(),
        assignees: assignees,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load customers.'),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setStatusFilter(String? status) {
    if (status == null || status.isEmpty) {
      state = state.copyWith(clearStatusFilter: true);
      return;
    }

    state = state.copyWith(statusFilter: status);
  }

  void setTypeFilter(String? type) {
    if (type == null || type.isEmpty) {
      state = state.copyWith(clearTypeFilter: true);
      return;
    }

    state = state.copyWith(typeFilter: type);
  }

  Future<void> saveCustomer(CustomerRecord customer) async {
    if (!_isConfigured) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save customers.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final currentUserId = _client.auth.currentUser?.id;
      final payload = customer.id == null
          ? customer.toInsertMap(createdById: currentUserId)
          : customer.toUpdateMap();

      if (customer.id == null) {
        if ((payload['customer_code'] as String?)?.trim().isEmpty ?? true) {
          payload['customer_code'] = _generateCustomerCode();
        }
        await _client.from('customers').insert(payload);
      } else {
        await _client.from('customers').update(payload).eq('id', customer.id!);
      }

      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save customer.'),
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteCustomer(String id) async {
    if (!_isConfigured) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete customers.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _client.from('customers').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete customer.'),
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  String _generateCustomerCode() {
    final token = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    final compact = token.length > 8
        ? token.substring(token.length - 8)
        : token;
    return 'CUST-$compact';
  }

  String _formatError(Object error, String fallbackMessage) {
    final message = error.toString();
    if (error is AuthRetryableFetchException ||
        message.contains('Failed to fetch') ||
        message.contains('ClientException') ||
        message.contains('SocketException')) {
      return 'Connection error: Unable to reach Supabase. Check your network and configuration.';
    }

    return message.isEmpty ? fallbackMessage : message;
  }
}

final customerDirectoryProvider =
    StateNotifierProvider<CustomerDirectoryController, CustomerDirectoryState>((
      ref,
    ) {
      return CustomerDirectoryController();
    });
