import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/customer.dart';
import 'package:erp/models/product.dart';
import 'package:erp/models/sales_order.dart';
import 'package:erp/providers/customer_providers.dart';
import 'package:erp/providers/product_providers.dart';
import 'package:erp/providers/sales_providers.dart';
import 'package:erp/utils/formatters.dart';

enum ActivityIconType { invoice, inventory, system }

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.meta,
    required this.iconType,
    this.onTap,
    this.muted = false,
  });

  final String title;
  final String meta;
  final ActivityIconType iconType;
  final VoidCallback? onTap;
  final bool muted;
}

class ActivityFeedWidget extends ConsumerWidget {
  const ActivityFeedWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(recentSalesOrdersProvider);
    final productsState = ref.watch(productDirectoryProvider);
    final customersState = ref.watch(customerDirectoryProvider);

    final items = <ActivityItem>[];

    final customersById = <String, CustomerRecord>{
      for (final customer in customersState.customers)
        if (customer.id != null) customer.id!: customer,
    };

    final navContext = context;
    ordersAsync.whenData((orders) {
      for (final order in orders.take(5)) {
        items.add(_orderActivity(order, customersById, navContext, ref));
      }
    });

    for (final product in productsState.products.take(3)) {
      items.add(_productActivity(product, navContext));
    }

    if (items.isEmpty) {
      // Avoid a jarring empty box: render a single muted placeholder.
      items.add(
        const ActivityItem(
          title: 'সাম্প্রতিক কোনো কার্যকলাপ নেই',
          meta: 'বিক্রয় ও ইনভেন্টরি তথ্য এখানে দেখানো হবে',
          iconType: ActivityIconType.system,
          muted: true,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFC7C4D8).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'সাম্প্রতিক কার্যকলাপ',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF151C27),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...items.asMap().entries.map((entry) {
            final item = entry.value;
            return Opacity(
              opacity: item.muted ? 0.6 : 1.0,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: entry.key < items.length - 1 ? 20 : 0,
                ),
                child: InkWell(
                  onTap: item.onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIcon(item.iconType),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF151C27),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.meta,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  letterSpacing: 0.6,
                                  color: const Color(0xFF464555),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.onTap != null)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xFF9E9BB8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => context.push(AppRoutes.sales),
            child: Text(
              'সব লগ দেখুন →',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF3525CD),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static ActivityItem _orderActivity(
    SalesOrderRecord order,
    Map<String, CustomerRecord> customersById,
    BuildContext context,
    WidgetRef ref,
  ) {
    final customerName = order.customerId == null
        ? null
        : customersById[order.customerId]?.displayName;
    final amount = '৳${order.grandTotal.toStringAsFixed(2)}';
    final title = 'ইনভয়েস ${order.invoiceNo} • $amount';
    final metaParts = <String>[
      if (customerName != null) 'গ্রাহক: ${customerName.toUpperCase()}',
      order.paymentStatus.toUpperCase(),
      _relativeTime(order.orderDate),
    ];
    return ActivityItem(
      title: title,
      meta: metaParts.join(' • '),
      iconType: ActivityIconType.invoice,
      onTap: () => _showOrderDetailSheet(context, order, customerName, ref),
    );
  }

  static ActivityItem _productActivity(
    ProductRecord product,
    BuildContext context,
  ) {
    return ActivityItem(
      title: 'নতুন ইনভেন্টরি: ${product.displayName}',
      meta:
          '${(product.category ?? 'INVENTORY').toUpperCase()} • ${_relativeTime(product.createdAt ?? DateTime.now())}',
      iconType: ActivityIconType.inventory,
      onTap: () => context.push(AppRoutes.productNew, extra: product),
    );
  }

  static void _showOrderDetailSheet(
    BuildContext context,
    SalesOrderRecord order,
    String? customerName,
    WidgetRef ref,
  ) {
    final money = const MoneyFormatter();
    final dateTime = const DateTimeFormatter();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (scrollContext, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.invoiceNo.isEmpty
                            ? 'অর্ডার বিবরণ'
                            : 'ইনভয়েস ${order.invoiceNo}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(scrollContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateTime.format(order.orderDate.toLocal()),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                _DetailRow(label: 'গ্রাহক', value: customerName ?? 'ওয়াক-ইন'),
                _DetailRow(
                  label: 'পেমেন্ট',
                  value: order.paymentStatus.toUpperCase(),
                  valueColor: order.paymentStatus.toUpperCase() == 'PAID'
                      ? const Color(0xFF10B981)
                      : order.paymentStatus.toUpperCase() == 'UNPAID'
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFD97706),
                ),
                const SizedBox(height: 8),
                if (order.paymentStatus.toUpperCase() == 'UNPAID')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref
                            .read(recentSalesOrdersProvider.notifier)
                            .markPaymentDone(order.id ?? '');
                        Navigator.of(scrollContext).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'পেমেন্ট সম্পন্ন',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                if (order.paymentStatus.toUpperCase() == 'PAID')
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        ref
                            .read(recentSalesOrdersProvider.notifier)
                            .markAsUnpaid(order.id ?? '');
                        Navigator.of(scrollContext).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'অপরিশোধিত করুন',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                _TotalLine(
                  label: 'সাবটোটাল',
                  value: money.format(order.subtotal),
                ),
                if (order.discountAmount > 0)
                  _TotalLine(
                    label: 'ডিসকাউন্ট',
                    value: '- ${money.format(order.discountAmount)}',
                    valueColor: const Color(0xFFDC2626),
                  ),
                if (order.taxAmount > 0)
                  _TotalLine(
                    label: 'ট্যাক্স',
                    value: money.format(order.taxAmount),
                  ),
                if (order.shippingAmount > 0)
                  _TotalLine(
                    label: 'শিপিং',
                    value: money.format(order.shippingAmount),
                  ),
                const Divider(height: 18, color: Color(0xFFE2E8F0)),
                _TotalLine(
                  label: 'সর্বমোট',
                  value: money.format(order.grandTotal),
                  isBold: true,
                ),
                _TotalLine(
                  label: 'পরিশোধিত',
                  value: money.format(order.paidAmount),
                  valueColor: const Color(0xFF10B981),
                ),
                _TotalLine(
                  label: 'বাকি',
                  value: money.format(order.dueAmount),
                  valueColor: order.dueAmount > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF10B981),
                ),
                if (order.notes != null && order.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCD34D)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'নোট',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF92400E),
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          order.notes!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget _buildIcon(ActivityIconType type) {
    switch (type) {
      case ActivityIconType.inventory:
        return const _ActivityIconContainer(
          backgroundColor: Color(0xFFE8F5E9),
          child: Icon(
            Icons.inventory_2_outlined,
            size: 20,
            color: Color(0xFF2E7D32),
          ),
        );
      case ActivityIconType.invoice:
        return const _ActivityIconContainer(
          backgroundColor: Color(0xFFE3F2FD),
          child: Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: Color(0xFF1565C0),
          ),
        );
      case ActivityIconType.system:
        return const _ActivityIconContainer(
          backgroundColor: Color(0xFFF5F5F5),
          child: Icon(
            Icons.settings_outlined,
            size: 20,
            color: Color(0xFF757575),
          ),
        );
    }
  }
}

String _relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'এইমাত্র';
  if (diff.inMinutes < 60) return '${diff.inMinutes}মি আগে';
  if (diff.inHours < 24) return '${diff.inHours}ঘ আগে';
  if (diff.inDays < 7) return '${diff.inDays}দি আগে';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}সপ্তা আগে';
  return '${(diff.inDays / 30).floor()}মা আগে';
}

class _ActivityIconContainer extends StatelessWidget {
  final Color backgroundColor;
  final Widget child;

  const _ActivityIconContainer({
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(child: child),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isBold ? 14 : 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
