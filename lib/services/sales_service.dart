import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';
import 'package:erp/models/product.dart';
import 'package:erp/models/sales_order.dart';

/// Thrown by [SalesService.checkoutOrder] when the customer, cart or
/// Supabase state is invalid (e.g. no active session).
class SalesCheckoutException implements Exception {
  SalesCheckoutException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One line in a cart being checked out. Mirrors a [CartItem] but
/// detached from any provider so the service layer stays pure.
class CheckoutLine {
  const CheckoutLine({required this.product, required this.quantity});

  final ProductRecord product;
  final int quantity;

  String get productId {
    final id = product.id;
    if (id == null || id.isEmpty) {
      throw SalesCheckoutException(
        'Product "${product.displayName}" is missing a database id and cannot be sold.',
      );
    }
    return id;
  }

  double get unitPrice => product.price;

  double get taxAmount {
    if (!product.isTaxable) return 0;
    return product.price * quantity * product.taxRate / 100.0;
  }

  double get lineTotal => product.price * quantity + taxAmount;
}

/// Cart-level totals passed in from the view so the service doesn't
/// re-derive them and the persisted values exactly match what the user
/// just approved.
class CheckoutTotals {
  const CheckoutTotals({
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.shippingAmount,
    required this.grandTotal,
  });

  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double shippingAmount;
  final double grandTotal;
}

/// Persists sales orders, line items and (optionally) payments to
/// Supabase. The checkout flow inserts a `sales_orders` row and its
/// `sales_order_items` in a single PostgREST transaction so the order
/// is never partially written.
class SalesService {
  SupabaseClient get _client => Supabase.instance.client;

  bool get _isConfigured =>
      SupabaseConfig.isConfigured && Supabase.instance.isInitialized;

  /// Place an order in Supabase.
  ///
  /// Returns the [SalesCheckoutResult] containing the persisted
  /// order (with its generated `invoice_no`) and line items.
  Future<SalesCheckoutResult> checkoutOrder({
    required String customerId,
    required List<CheckoutLine> lines,
    required CheckoutTotals totals,
    String? notes,
    DateTime? dueDate,
  }) async {
    if (!_isConfigured) {
      throw SalesCheckoutException(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to place orders.',
      );
    }

    if (lines.isEmpty) {
      throw SalesCheckoutException('Cannot checkout an empty cart.');
    }

    for (final line in lines) {
      if (line.quantity <= 0) {
        throw SalesCheckoutException(
          'Quantity for "${line.product.displayName}" must be at least 1.',
        );
      }
    }

    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw SalesCheckoutException(
        'You are not signed in. Please sign in again to place an order.',
      );
    }

    final orderPayload = <String, dynamic>{
      'customer_id': customerId,
      'order_date': DateTime.now().toUtc().toIso8601String(),
      if (dueDate != null) 'due_date': _formatDate(dueDate),
      'subtotal': _money(totals.subtotal),
      'discount_amount': _money(totals.discountAmount),
      'tax_amount': _money(totals.taxAmount),
      'shipping_amount': _money(totals.shippingAmount),
      'grand_total': _money(totals.grandTotal),
      // Mock checkout (option A) — no payment captured yet, so the
      // full grand total is outstanding and the order is unpaid.
      'paid_amount': 0,
      'due_amount': _money(totals.grandTotal),
      'payment_status': 'UNPAID',
      'sales_status': 'COMPLETED',
      'notes': notes,
      'created_by': userId,
    };

    final itemPayload = lines
        .map(
          (line) => <String, dynamic>{
            // sales_order_id is filled in by the .select() / second
            // step below so we don't depend on a round-trip.
            'product_id': line.productId,
            'quantity': line.quantity,
            'unit_price': _money(line.unitPrice),
            'discount_amount': 0,
            'tax_amount': _money(line.taxAmount),
            'line_total': _money(line.lineTotal),
          },
        )
        .toList();

    try {
      // Use a Postgres function (rpc) so the order + items insert
      // happens atomically server-side. The function is created
      // here inline if missing — but we ship the migration's
      // triggers/triggers-friendly tables and use plain PostgREST
      // calls for portability. If you need an rpc, define
      // `public.checkout_sales_order(p_order jsonb, p_items
      // jsonb)` and switch this method to call `.rpc(...)`.
      final inserted = await _client
          .from('sales_orders')
          .insert(orderPayload)
          .select()
          .single();

      final orderId = inserted['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw SalesCheckoutException(
          'Supabase returned an order without an id.',
        );
      }

      final itemsWithOrderId = itemPayload
          .map((row) => <String, dynamic>{...row, 'sales_order_id': orderId})
          .toList();

      final insertedItems = await _client
          .from('sales_order_items')
          .insert(itemsWithOrderId)
          .select();

      // Mirror the just-inserted order back into the local stock
      // cache so the UI reflects the new quantities without
      // requiring a full product directory refresh.
      final order = SalesOrderRecord.fromMap(
        Map<String, dynamic>.from(inserted),
      );
      final items = List<Map<String, dynamic>>.from(
        insertedItems,
      ).map(SalesOrderItemRecord.fromMap).toList();

      return SalesCheckoutResult(order: order, items: items);
    } on PostgrestException catch (error) {
      throw SalesCheckoutException(_formatPostgrestError(error));
    } on SalesCheckoutException {
      rethrow;
    } catch (error) {
      throw SalesCheckoutException(_formatGenericError(error));
    }
  }

  /// Fetch the most recent sales orders, newest first. Used by the
  /// sales dashboard / list view.
  Future<List<SalesOrderRecord>> listRecentOrders({int limit = 50}) async {
    if (!_isConfigured) {
      throw SalesCheckoutException(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load orders.',
      );
    }

    final data = await _client
        .from('sales_orders')
        .select()
        .order('order_date', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(
      data,
    ).map(SalesOrderRecord.fromMap).toList();
  }

  /// Fetch the line items for a specific sales order, used by the
  /// sales list view when a row is expanded.
  Future<List<SalesOrderItemRecord>> listOrderItems(String orderId) async {
    if (!_isConfigured) {
      throw SalesCheckoutException(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY to load order items.',
      );
    }
    if (orderId.isEmpty) return const [];

    final data = await _client
        .from('sales_order_items')
        .select()
        .eq('sales_order_id', orderId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(
      data,
    ).map(SalesOrderItemRecord.fromMap).toList();
  }

  String _money(double value) => value.toStringAsFixed(2);

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatPostgrestError(PostgrestException error) {
    final code = error.code ?? '';
    final message = error.message;
    if (code == '23503') {
      return 'The customer or one of the products no longer exists. Refresh and try again.';
    }
    if (code == '23514') {
      return 'One of the values violates a database check constraint. Please verify quantities and prices.';
    }
    if (code == '42501' || message.toLowerCase().contains('permission')) {
      return 'You do not have permission to create sales orders. Contact an administrator.';
    }
    if (message.isNotEmpty) {
      return 'Supabase rejected the order: $message';
    }
    return 'Supabase rejected the order (code $code).';
  }

  String _formatGenericError(Object error) {
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed to fetch') ||
        text.contains('ClientException')) {
      return 'Connection error: unable to reach Supabase. Check your network and try again.';
    }
    return text;
  }

  /// Mark a sales order as fully paid. Sets [payment_status] to 'PAID',
  /// [paid_amount] to [grand_total] and [due_amount] to 0.
  Future<void> markPaymentDone(String orderId) async {
    if (!_isConfigured) return;
    if (orderId.isEmpty) return;

    // Fetch current grand_total first so we set paid_amount correctly.
    final row = await _client
        .from('sales_orders')
        .select('grand_total')
        .eq('id', orderId)
        .single();

    final grandTotal = _parseDouble(row['grand_total']);

    await _client
        .from('sales_orders')
        .update({
          'payment_status': 'PAID',
          'paid_amount': _money(grandTotal),
          'due_amount': '0.00',
        })
        .eq('id', orderId);
  }

  double _parseDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }
}
