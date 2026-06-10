// ignore_for_file: deprecated_member_use, unused_element

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/product.dart';
import 'package:erp/providers/product_providers.dart';

class ProductManagementView extends ConsumerStatefulWidget {
  const ProductManagementView({super.key});

  @override
  ConsumerState<ProductManagementView> createState() =>
      _ProductManagementViewState();
}

class _ProductManagementViewState extends ConsumerState<ProductManagementView> {
  static const int _rowsPerPage = 6;

  int _currentPage = 0;

  List<ProductRecord> _filteredProducts(ProductDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();

    return state.products.where((product) {
      final matchesSearch =
          query.isEmpty ||
          product.displayName.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          (product.category ?? '').toLowerCase().contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query) ||
          (product.supplier ?? '').toLowerCase().contains(query) ||
          (product.location ?? '').toLowerCase().contains(query);

      final matchesStatus =
          state.statusFilter == null ||
          product.status.toLowerCase() == state.statusFilter!.toLowerCase();

      final matchesCategory =
          state.categoryFilter == null ||
          (product.category ?? '').toLowerCase() ==
              state.categoryFilter!.toLowerCase();

      return matchesSearch && matchesStatus && matchesCategory;
    }).toList();
  }

  void _openProductForm(BuildContext context, {ProductRecord? existing}) {
    context.push(AppRoutes.productNew, extra: existing);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ProductRecord product,
  ) async {
    if (product.id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Delete product?'),
          content: Text(
            'This will permanently remove "${product.displayName}" from the catalogue. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await ref
        .read(productDirectoryProvider.notifier)
        .deleteProduct(product.id!);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${product.displayName} removed from catalogue.'),
        backgroundColor: const Color(0xFF0F172A),
      ),
    );
  }

  Future<void> _showStockPriceSheet(
    BuildContext context,
    WidgetRef ref,
    ProductRecord product,
  ) async {
    if (product.id == null) return;
    final controller = ref.read(productDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final stockController = TextEditingController(
      text: product.stock.toString(),
    );
    final priceController = TextEditingController(
      text: product.price.toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Color(0xFF4F46E5),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Adjust stock & price',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                product.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: stockController,
                            enabled: !isSaving,
                            keyboardType: TextInputType.number,
                            decoration: _sheetInputDecoration(
                              label: 'Stock on hand',
                              hint: '0',
                              icon: Icons.inventory_2_outlined,
                            ),
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) return 'Required';
                              final parsed = int.tryParse(raw);
                              if (parsed == null) return 'Whole numbers only';
                              if (parsed < 0) return 'Must be zero or greater';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: priceController,
                            enabled: !isSaving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _sheetInputDecoration(
                              label: 'Selling price',
                              hint: '0.00',
                              icon: Icons.payments_outlined,
                            ),
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) return 'Required';
                              final parsed = double.tryParse(raw);
                              if (parsed == null) return 'Enter a valid number';
                              if (parsed < 0) return 'Must be zero or greater';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cost price, SKU and other details stay the same. Only stock and selling price will be updated.',
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!(formKey.currentState?.validate() ??
                                        false)) {
                                      return;
                                    }
                                    setSheetState(() => isSaving = true);
                                    final newStock = int.parse(
                                      stockController.text.trim(),
                                    );
                                    final newPrice = double.parse(
                                      priceController.text.trim(),
                                    );
                                    final updated = product.copyWith(
                                      stock: newStock,
                                      price: newPrice,
                                    );
                                    final navigator = Navigator.of(
                                      sheetContext,
                                    );
                                    await controller.saveProduct(updated);
                                    final latestState = ref.read(
                                      productDirectoryProvider,
                                    );
                                    if (!context.mounted) return;
                                    if (latestState.errorMessage == null) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${product.displayName} updated.',
                                          ),
                                          backgroundColor: const Color(
                                            0xFF10B981,
                                          ),
                                        ),
                                      );
                                      navigator.pop();
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            latestState.errorMessage!,
                                          ),
                                          backgroundColor: const Color(
                                            0xFFDC2626,
                                          ),
                                        ),
                                      );
                                      setSheetState(() => isSaving = false);
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(isSaving ? 'Saving...' : 'Save'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _sheetInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  Future<void> _showFiltersSheet(
    BuildContext context,
    WidgetRef ref,
    ProductDirectoryState state,
  ) async {
    final controller = ref.read(productDirectoryProvider.notifier);
    String? selectedStatus = state.statusFilter;
    String? selectedCategory = state.categoryFilter;

    final categories = List<String>.from(state.availableCategories);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              margin: const EdgeInsets.all(12),
              padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Filter products',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            selectedStatus = null;
                            selectedCategory = null;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SheetLabel(text: 'Status'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ProductStatusOptions.values.map((value) {
                      final selected = selectedStatus == value;
                      return ChoiceChip(
                        label: Text(ProductStatusOptions.label(value)),
                        selected: selected,
                        onSelected: (isSelected) {
                          setSheetState(() {
                            selectedStatus = isSelected ? value : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  _SheetLabel(text: 'Category'),
                  const SizedBox(height: 8),
                  if (categories.isEmpty)
                    const Text(
                      'Categories will appear once products are added.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final selected = selectedCategory == category;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (isSelected) {
                            setSheetState(() {
                              selectedCategory = isSelected ? category : null;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        controller.setStatusFilter(selectedStatus);
                        controller.setCategoryFilter(selectedCategory);
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('Apply filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDirectoryProvider);
    final controller = ref.read(productDirectoryProvider.notifier);

    final filteredProducts = _filteredProducts(state);

    final totalPages = filteredProducts.isEmpty
        ? 1
        : (filteredProducts.length / _rowsPerPage).ceil();
    final int safePage = _currentPage.clamp(0, totalPages - 1).toInt();
    final pageStart = filteredProducts.isEmpty
        ? 0
        : (safePage * _rowsPerPage) + 1;
    final int pageEnd = filteredProducts.isEmpty
        ? 0
        : math.min(pageStart + _rowsPerPage - 1, filteredProducts.length);
    final visibleProducts = filteredProducts
        .skip(safePage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    final activeFilterCount =
        (state.statusFilter != null ? 1 : 0) +
        (state.categoryFilter != null ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      floatingActionButton: _NewProductFab(
        onPressed: () => _openProductForm(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchBarSection(
                    searchQuery: state.searchQuery,
                    activeFilterCount: activeFilterCount,
                    onChanged: (value) {
                      controller.setSearchQuery(value);
                      setState(() => _currentPage = 0);
                    },
                    onFilterTap: () => _showFiltersSheet(context, ref, state),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Product Catalogue',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    filteredProducts.isEmpty
                                        ? 'No products match the current search and filters.'
                                        : 'Showing $pageStart-$pageEnd of ${filteredProducts.length} products',
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (state.isLoading)
                              const Padding(
                                padding: EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                  ),
                                ),
                              ),
                            OutlinedButton.icon(
                              onPressed: state.isSaving
                                  ? null
                                  : controller.refresh,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                        if (state.errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: Text(
                              state.errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFB91C1C),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (filteredProducts.isEmpty && !state.isLoading)
                          _EmptyProductsState(
                            hasFilters:
                                state.searchQuery.isNotEmpty ||
                                state.statusFilter != null ||
                                state.categoryFilter != null,
                            onCreate: () => _openProductForm(context),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width >= 1120
                                  ? 3
                                  : width >= 480
                                  ? 2
                                  : 1;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 10,
                                          mainAxisExtent: 188,
                                        ),
                                    itemCount: visibleProducts.length,
                                    itemBuilder: (context, index) {
                                      final product = visibleProducts[index];
                                      return _ProductCard(
                                        product: product,
                                        onEdit: () => _openProductForm(
                                          context,
                                          existing: product,
                                        ),
                                        onDelete: () => _confirmDelete(
                                          context,
                                          ref,
                                          product,
                                        ),
                                        onAdjustStockPrice: () =>
                                            _showStockPriceSheet(
                                              context,
                                              ref,
                                              product,
                                            ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _PaginationBar(
                                    totalItems: filteredProducts.length,
                                    pageIndex: safePage,
                                    pageCount: totalPages,
                                    pageStart: pageStart,
                                    pageEnd: pageEnd,
                                    onPreviousPage: safePage == 0
                                        ? null
                                        : () {
                                            setState(
                                              () => _currentPage = safePage - 1,
                                            );
                                          },
                                    onNextPage: safePage >= totalPages - 1
                                        ? null
                                        : () {
                                            setState(
                                              () => _currentPage = safePage + 1,
                                            );
                                          },
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewProductFab extends StatelessWidget {
  const _NewProductFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5EF7), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_box_rounded, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'New Product',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onAdjustStockPrice,
  });

  final ProductRecord product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAdjustStockPrice;

  @override
  Widget build(BuildContext context) {
    final statusColor = ProductStatusOptions.color(product.status);
    final isLowStock = product.isLowStock;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      color: Color(0xFF4F46E5),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.sku.isEmpty ? 'No SKU' : 'SKU ${product.sku}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: ProductStatusOptions.label(product.status),
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: product.categoryLabel,
                  ),
                  if (product.barcode != null)
                    _InfoChip(
                      icon: Icons.qr_code_rounded,
                      label: product.barcode!,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.priceLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Stock',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${product.stock}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isLowStock
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            product.unit,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isLowStock) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: Color(0xFFDC2626),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Product actions',
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      } else if (value == 'adjust') {
                        onAdjustStockPrice();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'adjust',
                        child: Row(
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 10),
                            Text('Adjust stock / price'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Color(0xFFDC2626),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFDC2626)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchBarSection extends StatelessWidget {
  const SearchBarSection({
    super.key,
    required this.searchQuery,
    required this.activeFilterCount,
    required this.onChanged,
    required this.onFilterTap,
  });

  final String searchQuery;
  final int activeFilterCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.collapsed(
                  offset: searchQuery.length,
                ),
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Search products, SKU or category...',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          _FilterButton(
            activeFilterCount: activeFilterCount,
            onTap: onFilterTap,
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeFilterCount, required this.onTap});

  final int activeFilterCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF0F172A),
                size: 20,
              ),
            ),
          ),
        ),
        if (activeFilterCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 18),
              child: Text(
                '$activeFilterCount',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.totalItems,
    required this.pageIndex,
    required this.pageCount,
    required this.pageStart,
    required this.pageEnd,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int totalItems;
  final int pageIndex;
  final int pageCount;
  final int pageStart;
  final int pageEnd;
  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 520;
          final pager = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                onPressed: onPreviousPage,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('Prev'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onNextPage,
                icon: const Icon(Icons.chevron_right_rounded),
                label: const Text('Next'),
              ),
            ],
          );

          final pageLabel = Text(
            'Page ${pageIndex + 1} of $pageCount',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );

          if (isWide) {
            return Row(
              children: [
                const Spacer(),
                pageLabel,
                const SizedBox(width: 16),
                pager,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              pageLabel,
              const SizedBox(height: 12),
              pager,
            ],
          );
        },
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({required this.hasFilters, required this.onCreate});

  final bool hasFilters;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            hasFilters
                ? Icons.manage_search_rounded
                : Icons.inventory_2_outlined,
            size: 52,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching products found' : 'No products yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'Try a different search term or clear the filters to continue.'
                : 'Create your first product to start tracking stock, prices, and sales.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_box_rounded),
            label: const Text('Add Product'),
          ),
        ],
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF475569),
        letterSpacing: 0.6,
      ),
    );
  }
}
