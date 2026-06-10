/// Models for the sales workflow. Mirrors the public.sales_orders,
/// public.sales_order_items and public.sales_payments tables defined in
/// `lib/migrations/0004_create_sales_tables.sql`.
library;

import 'package:flutter/foundation.dart';

String? _emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

double _parseDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

@immutable
class SalesOrderRecord {
  const SalesOrderRecord({
    required this.id,
    required this.invoiceNo,
    required this.customerId,
    required this.orderDate,
    required this.dueDate,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.shippingAmount,
    required this.grandTotal,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentStatus,
    required this.salesStatus,
    required this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SalesOrderRecord.fromMap(Map<String, dynamic> data) {
    return SalesOrderRecord(
      id: data['id']?.toString(),
      invoiceNo: (data['invoice_no'] ?? '').toString(),
      customerId: data['customer_id']?.toString(),
      orderDate: _parseDate(data['order_date']) ?? DateTime.now(),
      dueDate: _parseDate(data['due_date']),
      subtotal: _parseDouble(data['subtotal']),
      discountAmount: _parseDouble(data['discount_amount']),
      taxAmount: _parseDouble(data['tax_amount']),
      shippingAmount: _parseDouble(data['shipping_amount']),
      grandTotal: _parseDouble(data['grand_total']),
      paidAmount: _parseDouble(data['paid_amount']),
      dueAmount: _parseDouble(data['due_amount']),
      paymentStatus: (data['payment_status'] ?? 'UNPAID').toString(),
      salesStatus: (data['sales_status'] ?? 'COMPLETED').toString(),
      notes: _emptyToNull(data['notes']?.toString()),
      createdBy: data['created_by']?.toString(),
      createdAt: _parseDate(data['created_at']),
      updatedAt: _parseDate(data['updated_at']),
    );
  }

  final String? id;
  final String invoiceNo;
  final String? customerId;
  final DateTime orderDate;
  final DateTime? dueDate;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double shippingAmount;
  final double grandTotal;
  final double paidAmount;
  final double dueAmount;
  final String paymentStatus;
  final String salesStatus;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

@immutable
class SalesOrderItemRecord {
  const SalesOrderItemRecord({
    required this.id,
    required this.salesOrderId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.taxAmount,
    required this.lineTotal,
    required this.createdAt,
  });

  factory SalesOrderItemRecord.fromMap(Map<String, dynamic> data) {
    return SalesOrderItemRecord(
      id: data['id']?.toString(),
      salesOrderId: data['sales_order_id']?.toString(),
      productId: data['product_id']?.toString(),
      quantity: _parseInt(data['quantity']),
      unitPrice: _parseDouble(data['unit_price']),
      discountAmount: _parseDouble(data['discount_amount']),
      taxAmount: _parseDouble(data['tax_amount']),
      lineTotal: _parseDouble(data['line_total']),
      createdAt: _parseDate(data['created_at']),
    );
  }

  final String? id;
  final String? salesOrderId;
  final String? productId;
  final int quantity;
  final double unitPrice;
  final double discountAmount;
  final double taxAmount;
  final double lineTotal;
  final DateTime? createdAt;
}

/// Result of a successful checkout — what the sales view shows in the
/// post-checkout success snackbar / dialog.
@immutable
class SalesCheckoutResult {
  const SalesCheckoutResult({
    required this.order,
    required this.items,
  });

  final SalesOrderRecord order;
  final List<SalesOrderItemRecord> items;

  String get invoiceNo => order.invoiceNo;
}
