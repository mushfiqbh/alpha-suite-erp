import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:erp/models/customer.dart';
import 'package:erp/models/product.dart';
import 'package:erp/models/sales_order.dart';
import 'package:erp/services/sales_service.dart';

/// A single line in the cart.
class CartItem {
  const CartItem({required this.product, required this.quantity});

  final ProductRecord product;
  final int quantity;

  double get lineSubtotal => product.price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(product: product, quantity: quantity ?? this.quantity);
  }
}

/// Holds the customer currently being sold to. Single-customer selection
/// (one sale at a time) — setting a new customer wipes the cart.
class SalesSelectionController extends StateNotifier<CustomerRecord?> {
  SalesSelectionController() : super(null);

  void select(CustomerRecord customer) {
    state = customer;
  }

  void clear() {
    state = null;
  }
}

final salesSelectionProvider =
    StateNotifierProvider<SalesSelectionController, CustomerRecord?>(
      (ref) => SalesSelectionController(),
    );

/// Cart state: list of [CartItem], derived totals, mock checkout helpers.
class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super(const <CartItem>[]);

  /// Add [product] to the cart. If already present, increments quantity.
  /// Quantity is clamped to a non-negative value and to available stock.
  void addProduct(ProductRecord product, {int quantity = 1}) {
    if (quantity <= 0) return;
    final clamped = quantity.clamp(0, _maxAddable(product, 0));
    if (clamped <= 0) return;

    final index = state.indexWhere((item) => item.product.id == product.id);
    if (index == -1) {
      state = <CartItem>[
        ...state,
        CartItem(product: product, quantity: clamped),
      ];
      return;
    }

    final existing = state[index];
    final nextQty = (existing.quantity + clamped).clamp(0, product.stock);
    final updated = <CartItem>[
      for (var i = 0; i < state.length; i++)
        if (i == index) existing.copyWith(quantity: nextQty) else state[i],
    ];
    state = updated;
  }

  /// Set absolute quantity for a product id. Clamped to [0, product.stock].
  void setQuantity(String productId, int quantity) {
    final index = state.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;

    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    final existing = state[index];
    final clamped = quantity.clamp(0, existing.product.stock);
    state = <CartItem>[
      for (var i = 0; i < state.length; i++)
        if (i == index) existing.copyWith(quantity: clamped) else state[i],
    ];
  }

  void increment(String productId) {
    final index = state.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;
    final existing = state[index];
    if (existing.quantity >= existing.product.stock) return;
    setQuantity(productId, existing.quantity + 1);
  }

  void decrement(String productId) {
    final index = state.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;
    final existing = state[index];
    setQuantity(productId, existing.quantity - 1);
  }

  void removeProduct(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void clear() {
    state = const <CartItem>[];
  }

  int _maxAddable(ProductRecord product, int currentInCart) {
    final remaining = product.stock - currentInCart;
    return remaining < 0 ? 0 : remaining;
  }
}

final cartProvider = StateNotifierProvider<CartController, List<CartItem>>((
  ref,
) {
  return CartController();
});

/// Subtotal of all cart line items.
final cartSubtotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold<double>(0, (sum, item) => sum + item.lineSubtotal);
});

/// Total units in cart (sum of quantities).
final cartItemCountProvider = Provider<int>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold<int>(0, (sum, item) => sum + item.quantity);
});

/// Estimated tax from taxable products. Uses each product's [ProductRecord.taxRate]
/// (percentage, e.g. 5 for 5%).
final cartTaxProvider = Provider<double>((ref) {
  final items = ref.watch(cartProvider);
  return items.fold<double>(0, (sum, item) {
    if (!item.product.isTaxable) return sum;
    return sum + (item.lineSubtotal * item.product.taxRate / 100.0);
  });
});

/// Grand total = subtotal + tax.
final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final tax = ref.watch(cartTaxProvider);
  return subtotal + tax;
});

// ---------------------------------------------------------------------------
// Supabase-backed service + recently-placed orders providers.
// ---------------------------------------------------------------------------
final salesServiceProvider = Provider<SalesService>((ref) {
  return SalesService();
});

/// Most recent sales orders, newest first. Refreshed manually via
/// [recentSalesOrdersProvider.notifier] or by invalidating the provider.
class RecentSalesOrdersController
    extends StateNotifier<AsyncValue<List<SalesOrderRecord>>> {
  RecentSalesOrdersController(this._service)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final SalesService _service;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final orders = await _service.listRecentOrders();
      state = AsyncValue.data(orders);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> markPaymentDone(String orderId) async {
    try {
      await _service.markPaymentDone(orderId);
      // Update local state in-place to avoid a loading spinner flash.
      state = state.whenData((orders) {
        return orders.map((order) {
          if (order.id != orderId) return order;
          return SalesOrderRecord(
            id: order.id,
            invoiceNo: order.invoiceNo,
            customerId: order.customerId,
            orderDate: order.orderDate,
            dueDate: order.dueDate,
            subtotal: order.subtotal,
            discountAmount: order.discountAmount,
            taxAmount: order.taxAmount,
            shippingAmount: order.shippingAmount,
            grandTotal: order.grandTotal,
            paidAmount: order.grandTotal,
            dueAmount: 0,
            paymentStatus: 'PAID',
            salesStatus: order.salesStatus,
            notes: order.notes,
            createdBy: order.createdBy,
            createdAt: order.createdAt,
            updatedAt: DateTime.now(),
          );
        }).toList();
      });
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}

final recentSalesOrdersProvider =
    StateNotifierProvider<
      RecentSalesOrdersController,
      AsyncValue<List<SalesOrderRecord>>
    >((ref) {
      return RecentSalesOrdersController(ref.watch(salesServiceProvider));
    });

/// Line items for a single sales order, loaded on demand by the
/// sales list view when a row is expanded.
final salesOrderItemsProvider = FutureProvider.family
    .autoDispose<List<SalesOrderItemRecord>, String>((ref, orderId) {
      final service = ref.watch(salesServiceProvider);
      return service.listOrderItems(orderId);
    });
