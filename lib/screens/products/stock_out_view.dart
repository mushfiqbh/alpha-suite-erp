import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/models/product.dart';
import 'package:erp/providers/product_providers.dart';

class StockOutView extends ConsumerStatefulWidget {
  const StockOutView({super.key});

  @override
  ConsumerState<StockOutView> createState() => _StockOutViewState();
}

class _StockOutViewState extends ConsumerState<StockOutView> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productDirectoryProvider);
    final stockOutProducts = _stockOutProducts(state.products);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Stock Out Products',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF151C27),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF151C27)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : state.errorMessage != null && state.products.isEmpty
                ? Center(
                    child: Text(
                      state.errorMessage!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFFB23B3B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : stockOutProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: const Color(0xFF006C49).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'All products are well-stocked!',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF464555),
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildProductList(stockOutProducts),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFFF9F9FF),
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF9E9BB8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF9E9BB8),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: const Color(0xFFC7C4D8).withValues(alpha: 0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF4F46E5)),
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(List<ProductRecord> products) {
    final outOfStock = products.where((p) => p.stock <= 0).toList();
    final lowStock = products
        .where((p) => p.stock > 0 && p.stock <= p.reorderLevel)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (outOfStock.isNotEmpty) ...[
          _buildSectionHeader('Out of Stock', outOfStock.length, true),
          ...outOfStock.map((p) => _buildProductTile(p)),
          const SizedBox(height: 8),
        ],
        if (lowStock.isNotEmpty) ...[
          _buildSectionHeader('Low Stock', lowStock.length, false),
          ...lowStock.map((p) => _buildProductTile(p)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String label, int count, bool isCritical) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isCritical
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCritical
                    ? const Color(0xFFB23B3B)
                    : const Color(0xFF684000),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count product${count == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF9E9BB8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(ProductRecord product) {
    final isOutOfStock = product.stock <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOutOfStock
              ? const Color(0xFFFEE2E2)
              : const Color(0xFFFFF3E0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Left: stock indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isOutOfStock
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isOutOfStock
                    ? Icons.error_outline_rounded
                    : Icons.warning_amber_rounded,
                color: isOutOfStock
                    ? const Color(0xFFB23B3B)
                    : const Color(0xFF684000),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Middle: product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF151C27),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF9E9BB8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right: stock count
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.stock}',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isOutOfStock
                        ? const Color(0xFFB23B3B)
                        : const Color(0xFF684000),
                  ),
                ),
                Text(
                  '${product.unit}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF9E9BB8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<ProductRecord> _stockOutProducts(List<ProductRecord> allProducts) {
    final query = _searchQuery.trim().toLowerCase();
    return allProducts.where((p) {
      if (!p.isLowStock) return false;
      if (query.isEmpty) return true;
      return p.displayName.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          (p.category ?? '').toLowerCase().contains(query);
    }).toList()..sort((a, b) {
      // Out of stock first
      final aOut = a.stock <= 0 ? 0 : 1;
      final bOut = b.stock <= 0 ? 0 : 1;
      if (aOut != bOut) return aOut.compareTo(bOut);
      // Then by stock ascending
      return a.stock.compareTo(b.stock);
    });
  }
}
