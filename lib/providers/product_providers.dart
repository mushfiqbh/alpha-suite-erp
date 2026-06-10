import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/product.dart';

class ProductDirectoryState {
  const ProductDirectoryState({
    required this.products,
    required this.isLoading,
    required this.isSaving,
    required this.searchQuery,
    required this.statusFilter,
    required this.categoryFilter,
    this.errorMessage,
  });

  factory ProductDirectoryState.initial() {
    return const ProductDirectoryState(
      products: <ProductRecord>[],
      isLoading: false,
      isSaving: false,
      searchQuery: '',
      statusFilter: null,
      categoryFilter: null,
      errorMessage: null,
    );
  }

  final List<ProductRecord> products;
  final bool isLoading;
  final bool isSaving;
  final String searchQuery;
  final String? statusFilter;
  final String? categoryFilter;
  final String? errorMessage;

  List<String> get availableCategories {
    final set = <String>{};
    for (final product in products) {
      final category = product.category?.trim();
      if (category != null && category.isNotEmpty) {
        set.add(category);
      }
    }
    final list = set.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  ProductDirectoryState copyWith({
    List<ProductRecord>? products,
    bool? isLoading,
    bool? isSaving,
    String? searchQuery,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? categoryFilter,
    bool clearCategoryFilter = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProductDirectoryState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      categoryFilter:
          clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ProductDirectoryController extends StateNotifier<ProductDirectoryState> {
  ProductDirectoryController() : super(ProductDirectoryState.initial()) {
    refresh();
  }

  SupabaseClient get _client => Supabase.instance.client;

  bool get _isConfigured =>
      SupabaseConfig.isConfigured && Supabase.instance.isInitialized;

  Future<void> refresh() async {
    if (!_isConfigured) {
      state = state.copyWith(
        isLoading: false,
        products: const <ProductRecord>[],
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load products.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final data = await _client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      state = state.copyWith(
        isLoading: false,
        products: List<Map<String, dynamic>>.from(data)
            .map(ProductRecord.fromMap)
            .toList(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatError(error, 'Unable to load products.'),
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

  void setCategoryFilter(String? category) {
    if (category == null || category.isEmpty) {
      state = state.copyWith(clearCategoryFilter: true);
      return;
    }
    state = state.copyWith(categoryFilter: category);
  }

  Future<void> saveProduct(ProductRecord product) async {
    if (!_isConfigured) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to save products.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final currentUserId = _client.auth.currentUser?.id;
      final payload = product.id == null
          ? product.toInsertMap(createdById: currentUserId)
          : product.toUpdateMap();

      if (product.id == null) {
        if ((payload['sku'] as String?)?.trim().isEmpty ?? true) {
          payload['sku'] = _generateProductSku();
        }
        await _client.from('products').insert(payload);
      } else {
        await _client.from('products').update(payload).eq('id', product.id!);
      }

      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to save product.'),
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  Future<void> deleteProduct(String id) async {
    if (!_isConfigured) {
      state = state.copyWith(
        errorMessage:
            'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to delete products.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _client.from('products').delete().eq('id', id);
      await refresh();
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: _formatError(error, 'Unable to delete product.'),
      );
    } finally {
      state = state.copyWith(isSaving: false);
    }
  }

  String _generateProductSku() {
    final token = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    final compact = token.length > 8 ? token.substring(token.length - 8) : token;
    return 'PROD-$compact';
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

final productDirectoryProvider =
    StateNotifierProvider<ProductDirectoryController, ProductDirectoryState>((ref) {
  return ProductDirectoryController();
});
