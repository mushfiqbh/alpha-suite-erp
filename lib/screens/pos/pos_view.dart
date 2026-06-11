// ignore_for_file: deprecated_member_use, unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/models/customer.dart';
import 'package:erp/models/product.dart';
import 'package:erp/models/sales_order.dart';
import 'package:erp/providers/customer_providers.dart';
import 'package:erp/providers/product_providers.dart';
import 'package:erp/providers/sales_providers.dart';
import 'package:erp/services/sales_service.dart';

class PosView extends ConsumerStatefulWidget {
  const PosView({super.key});

  @override
  ConsumerState<PosView> createState() => _PosViewState();
}

class _PosViewState extends ConsumerState<PosView> {
  static const double _desktopBreakpoint = 960;

  String _localSearch = '';
  String? _localStatusFilter;
  String? _localCategoryFilter;

  @override
  void initState() {
    super.initState();
    // Mirror product directory filters into local state on first frame.
    final productState = ref.read(productDirectoryProvider);
    _localSearch = productState.searchQuery;
    _localStatusFilter = productState.statusFilter;
    _localCategoryFilter = productState.categoryFilter;
  }

  List<ProductRecord> _filteredProducts(ProductDirectoryState state) {
    final query = _localSearch.trim().toLowerCase();

    return state.products.where((product) {
      final matchesSearch =
          query.isEmpty ||
          product.displayName.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          (product.category ?? '').toLowerCase().contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query);

      final matchesStatus =
          _localStatusFilter == null ||
          product.status.toLowerCase() == _localStatusFilter!.toLowerCase();

      final matchesCategory =
          _localCategoryFilter == null ||
          (product.category ?? '').toLowerCase() ==
              _localCategoryFilter!.toLowerCase();

      // Only sellable products: active status and in stock.
      final isSellable =
          product.status.toLowerCase() == 'active' && product.stock > 0;

      return matchesSearch && matchesStatus && matchesCategory && isSellable;
    }).toList();
  }

  void _addProduct(ProductRecord product) {
    final customer = ref.read(salesSelectionProvider);
    if (customer == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            'Pick a customer first',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return;
    }
    ref.read(cartProvider.notifier).addProduct(product);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          'Added ${product.displayName} to cart',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmCheckout(CartSummary summary) async {
    final customer = ref.read(salesSelectionProvider);
    if (customer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Confirm checkout'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer: ${customer.displayName}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.itemCount} item${summary.itemCount == 1 ? '' : 's'} • '
                  '${ref.read(cartProvider).length} line${ref.read(cartProvider).length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 24),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: ref.read(cartProvider).map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.product.displayName}  × ${item.quantity}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '\$${item.lineSubtotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const Divider(height: 24),
                _SummaryRow(label: 'Subtotal', value: summary.subtotal),
                if (summary.taxTotal > 0)
                  _SummaryRow(label: 'Tax', value: summary.taxTotal),
                const SizedBox(height: 6),
                _SummaryRow(
                  label: 'Total',
                  value: summary.grandTotal,
                  emphasized: true,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFF4F46E5),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will create a sales order in Supabase and decrement product stock.',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF3730A3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Place order'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final customerId = customer.id;
    if (customerId == null || customerId.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            'Customer record is missing an id — cannot place the order.',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return;
    }

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final lines = <CheckoutLine>[
      for (final item in cart)
        CheckoutLine(product: item.product, quantity: item.quantity),
    ];
    final totals = CheckoutTotals(
      subtotal: summary.subtotal,
      taxAmount: summary.taxTotal,
      discountAmount: 0,
      shippingAmount: 0,
      grandTotal: summary.grandTotal,
    );

    // Show a non-dismissable progress indicator while we talk to Supabase.
    final progressNotifier = ValueNotifier<bool>(false);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (progressContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: ValueListenableBuilder<bool>(
              valueListenable: progressNotifier,
              builder: (_, saving, __) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (saving)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    else
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        saving ? 'Saving sale…' : 'Sale saved',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    final service = ref.read(salesServiceProvider);
    SalesCheckoutResult? result;
    Object? failure;
    try {
      result = await service.checkoutOrder(
        customerId: customerId,
        lines: lines,
        totals: totals,
      );
    } on SalesCheckoutException catch (error) {
      failure = error;
    } catch (error) {
      failure = error;
    }

    if (!mounted) return;

    if (failure != null || result == null) {
      progressNotifier.value = false;
      // Dismiss the progress dialog.
      Navigator.of(context, rootNavigator: true).pop();
      final message = failure is SalesCheckoutException
          ? failure.message
          : 'Could not place the order. Please try again.';
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Brief "saved" tick, then dismiss the progress dialog.
    progressNotifier.value = false;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    // Refresh product stock counts (the DB trigger already updated them).
    ref.invalidate(productDirectoryProvider);

    // Clear the local cart + selection.
    ref.read(cartProvider.notifier).clear();
    ref.read(salesSelectionProvider.notifier).clear();

    // Refresh the recent-orders stream (used by other pages if any).
    // ignore: unused_result
    ref.refresh(recentSalesOrdersProvider);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          'Order ${result.invoiceNo} placed for ${customer.displayName}.',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showNewCustomerModal() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('New Customer'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name *',
                    hintText: 'Guest Customer',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: '+1 555-000-0000',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'customer@example.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    hintText: 'Street, city, etc.',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Select'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) return;

    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final customer = CustomerRecord(
      id: null,
      customerCode: '',
      customerType: 'company',
      companyName: name,
      firstName: null,
      lastName: null,
      email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
      phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
      website: null,
      industry: null,
      billingAddress: addressCtrl.text.trim().isEmpty
          ? null
          : addressCtrl.text.trim(),
      shippingAddress: null,
      city: null,
      country: null,
      status: 'active',
      source: 'pos',
      assignedTo: null,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();

    // Save to Supabase and wait for refresh.
    await ref.read(customerDirectoryProvider.notifier).saveCustomer(customer);

    if (!mounted) return;

    // Find the newly saved customer and select them.
    final customers = ref.read(customerDirectoryProvider).customers;
    final savedCustomer = customers.firstWhere(
      (c) => c.companyName == name && c.phone == customer.phone,
      orElse: () => customers.isNotEmpty ? customers.first : customer,
    );

    ref.read(salesSelectionProvider.notifier).select(savedCustomer);
  }

  Future<void> _openMobileCartSheet({
    required BuildContext context,
    required CustomerRecord? customer,
    required List<CartItem> cart,
    required CartSummary summary,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Expanded(
                    child: _CartPanel(
                      customer: customer,
                      cart: cart,
                      summary: summary,
                      onCheckout: cart.isEmpty
                          ? null
                          : () {
                              Navigator.of(sheetContext).pop();
                              _confirmCheckout(summary);
                            },
                      compact: true,
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
    final productState = ref.watch(productDirectoryProvider);
    final customer = ref.watch(salesSelectionProvider);
    final cart = ref.watch(cartProvider);
    final summary = CartSummary(
      subtotal: ref.watch(cartSubtotalProvider),
      taxTotal: ref.watch(cartTaxProvider),
      grandTotal: ref.watch(cartTotalProvider),
      itemCount: ref.watch(cartItemCountProvider),
    );

    final products = _filteredProducts(productState);
    final isDesktop = MediaQuery.of(context).size.width >= _desktopBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      floatingActionButton: !isDesktop && cart.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 4),
              child: FloatingActionButton.extended(
                heroTag: 'sales-cart-fab',
                onPressed: () => _openMobileCartSheet(
                  context: context,
                  customer: customer,
                  cart: cart,
                  summary: summary,
                ),
                backgroundColor: const Color(0xFF4F46E5),
                elevation: 6,
                icon: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  'Cart • ${summary.itemCount}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : null,
      body: isDesktop
          ? _buildDesktopLayout(
              context: context,
              customer: customer,
              products: products,
              productState: productState,
              cart: cart,
              summary: summary,
            )
          : _buildMobileLayout(
              context: context,
              customer: customer,
              products: products,
              productState: productState,
              cart: cart,
              summary: summary,
            ),
    );
  }

  Widget _buildDesktopLayout({
    required BuildContext context,
    required CustomerRecord? customer,
    required List<ProductRecord> products,
    required ProductDirectoryState productState,
    required List<CartItem> cart,
    required CartSummary summary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CustomerBanner(
                  customer: customer,
                  onChange: _showNewCustomerModal,
                  onClear: customer == null
                      ? null
                      : () {
                          ref.read(salesSelectionProvider.notifier).clear();
                          ref.read(cartProvider.notifier).clear();
                        },
                ),
                const SizedBox(height: 18),
                _ProductSearchBar(
                  searchQuery: _localSearch,
                  onChanged: (value) {
                    setState(() => _localSearch = value);
                  },
                  onClear: () => setState(() => _localSearch = ''),
                ),
                const SizedBox(height: 18),
                _ProductGrid(products: products, onAdd: _addProduct),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 360,
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 20, 20, 20),
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
            child: _CartPanel(
              customer: customer,
              cart: cart,
              summary: summary,
              onCheckout: cart.isEmpty ? null : () => _confirmCheckout(summary),
              compact: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout({
    required BuildContext context,
    required CustomerRecord? customer,
    required List<ProductRecord> products,
    required ProductDirectoryState productState,
    required List<CartItem> cart,
    required CartSummary summary,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CustomerBanner(
            customer: customer,
            onChange: _showNewCustomerModal,
            onClear: customer == null
                ? null
                : () {
                    ref.read(salesSelectionProvider.notifier).clear();
                    ref.read(cartProvider.notifier).clear();
                  },
          ),
          const SizedBox(height: 16),
          _ProductSearchBar(
            searchQuery: _localSearch,
            onChanged: (value) {
              setState(() => _localSearch = value);
            },
            onClear: () => setState(() => _localSearch = ''),
          ),
          const SizedBox(height: 16),
          _ProductGrid(products: products, onAdd: _addProduct),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // No external state to sync; cart and selection are observed via Riverpod.
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasized
        ? GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          )
        : const TextStyle(
            color: Color(0xFF334155),
            fontWeight: FontWeight.w500,
          );
    final labelStyle = emphasized
        ? GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          )
        : const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text('\$${value.toStringAsFixed(2)}', style: valueStyle),
        ],
      ),
    );
  }
}

class _CustomerBanner extends StatelessWidget {
  const _CustomerBanner({
    required this.customer,
    required this.onChange,
    required this.onClear,
  });

  final CustomerRecord? customer;
  final VoidCallback onChange;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                color: Color(0xFF4F46E5),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Add a walk-in customer to start a sale.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onChange,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Start Sale'),
            ),
          ],
        ),
      );
    }

    final c = customer!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6D5EF7), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                _initials(c.displayName),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        c.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (c.customerCode.isNotEmpty) '#${c.customerCode}',
                    c.typeLabel,
                    c.location,
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BannerIconButton(
            icon: Icons.swap_horiz_rounded,
            tooltip: 'Change customer',
            onPressed: onChange,
          ),
          if (onClear != null) ...[
            const SizedBox(width: 6),
            _BannerIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Clear selection',
              onPressed: onClear!,
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _BannerIconButton extends StatelessWidget {
  const _BannerIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _ProductSearchBar extends StatelessWidget {
  const _ProductSearchBar({
    required this.searchQuery,
    required this.onChanged,
    required this.onClear,
  });

  final String searchQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        onChanged: onChanged,
        controller: TextEditingController.fromValue(
          TextEditingValue(
            text: searchQuery,
            selection: TextSelection.collapsed(offset: searchQuery.length),
          ),
        ),
        decoration: InputDecoration(
          hintText: 'Search products by name, SKU, or category',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
          ),
          suffixIcon: searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                    size: 18,
                  ),
                  onPressed: onClear,
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.products, required this.onAdd});

  final List<ProductRecord> products;
  final ValueChanged<ProductRecord> onAdd;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              'No sellable products found',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try adjusting your search or filters.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1120
            ? 3
            : width >= 720
            ? 3
            : width >= 480
            ? 2
            : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 10,
            mainAxisExtent: 110,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            return _SalesProductCard(
              product: products[index],
              onAdd: () => onAdd(products[index]),
            );
          },
        );
      },
    );
  }
}

class _SalesProductCard extends ConsumerWidget {
  const _SalesProductCard({required this.product, required this.onAdd});

  final ProductRecord product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inCart = ref
        .watch(cartProvider)
        .where((item) => item.product.id == product.id)
        .fold<int>(0, (sum, item) => sum + item.quantity);
    final stockRemaining = product.stock - inCart;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      product.sku.isEmpty ? 'No SKU' : 'SKU ${product.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.priceLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      product.stockLabel,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _AddButton(
                quantityInCart: inCart,
                stockRemaining: stockRemaining,
                onAdd: onAdd,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.quantityInCart,
    required this.stockRemaining,
    required this.onAdd,
  });

  final int quantityInCart;
  final int stockRemaining;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final canAdd = stockRemaining > 0;
    final color = canAdd ? const Color(0xFF4F46E5) : const Color(0xFFCBD5E1);

    if (quantityInCart == 0) {
      return Material(
        color: canAdd ? const Color(0xFFEEF2FF) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canAdd ? onAdd : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  canAdd ? Icons.add_rounded : Icons.block_rounded,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  canAdd ? 'Add' : 'Out',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_basket_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$quantityInCart in cart',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartPanel extends ConsumerWidget {
  const _CartPanel({
    required this.customer,
    required this.cart,
    required this.summary,
    required this.onCheckout,
    required this.compact,
  });

  final CustomerRecord? customer;
  final List<CartItem> cart;
  final CartSummary summary;
  final VoidCallback? onCheckout;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shopping_cart_rounded,
                  color: Color(0xFF4F46E5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cart',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${summary.itemCount} item${summary.itemCount == 1 ? '' : 's'} • '
                      '${cart.length} line${cart.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (cart.isNotEmpty)
                TextButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).clear();
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Expanded(
          child: cart.isEmpty
              ? _EmptyCartState(customer: customer)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: cart.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = cart[index];
                    return _CartLineTile(item: item);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFAFC),
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryRow(label: 'Subtotal', value: summary.subtotal),
              if (summary.taxTotal > 0)
                _SummaryRow(label: 'Tax', value: summary.taxTotal),
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Total',
                value: summary.grandTotal,
                emphasized: true,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: (onCheckout == null || customer == null)
                    ? null
                    : onCheckout,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                  disabledForegroundColor: const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: Text(
                  customer == null
                      ? 'Pick a customer to checkout'
                      : 'Checkout • \$${summary.grandTotal.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartLineTile extends ConsumerWidget {
  const _CartLineTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    final maxQty = product.stock;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFF4F46E5),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.priceLabel} / ${product.unit}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${item.lineSubtotal.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _QuantityStepper(
            quantity: item.quantity,
            maxQuantity: maxQty,
            onIncrement: () =>
                ref.read(cartProvider.notifier).increment(product.id!),
            onDecrement: () =>
                ref.read(cartProvider.notifier).decrement(product.id!),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ref.read(cartProvider.notifier).removeProduct(product.id!),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFFDC2626),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.maxQuantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final int maxQuantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final canIncrement = quantity < maxQuantity;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onPressed: quantity > 1 ? onDecrement : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$quantity',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onPressed: canIncrement ? onIncrement : null,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 14,
          color: onPressed == null
              ? const Color(0xFFCBD5E1)
              : const Color(0xFF4F46E5),
        ),
      ),
    );
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState({required this.customer});

  final CustomerRecord? customer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Color(0xFF4F46E5),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              customer == null ? 'Pick a customer first' : 'Cart is empty',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              customer == null
                  ? 'Select a customer above to start adding products.'
                  : 'Tap “Add” on any product to start a sale.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartSummary {
  const CartSummary({
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.itemCount,
  });

  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final int itemCount;
}
