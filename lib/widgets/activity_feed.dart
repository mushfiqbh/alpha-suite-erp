import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/models/customer.dart';
import 'package:erp/models/product.dart';
import 'package:erp/models/sales_order.dart';
import 'package:erp/providers/customer_providers.dart';
import 'package:erp/providers/product_providers.dart';
import 'package:erp/providers/sales_providers.dart';

enum ActivityIconType { invoice, inventory, system }

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.meta,
    required this.iconType,
    this.muted = false,
  });

  final String title;
  final String meta;
  final ActivityIconType iconType;
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

    ordersAsync.whenData((orders) {
      for (final order in orders.take(5)) {
        items.add(_orderActivity(order, customersById));
      }
    });

    for (final product in productsState.products.take(3)) {
      items.add(_productActivity(product));
    }

    if (items.isEmpty) {
      // Avoid a jarring empty box: render a single muted placeholder.
      items.add(
        const ActivityItem(
          title: 'No recent activity',
          meta: 'Sales and inventory will appear here',
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
            'Recent Activity',
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
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              // TODO: deep-link to /sales log when that view exists.
            },
            child: Text(
              'View all logs →',
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
  ) {
    final customerName = order.customerId == null
        ? null
        : customersById[order.customerId]?.displayName;
    final amount = '\$${order.grandTotal.toStringAsFixed(2)}';
    final title = customerName == null
        ? 'Invoice ${order.invoiceNo} • $amount'
        : 'Invoice ${order.invoiceNo} • $amount';
    final metaParts = <String>[
      if (customerName != null) 'CLIENT: ${customerName.toUpperCase()}',
      order.paymentStatus.toUpperCase(),
      _relativeTime(order.orderDate),
    ];
    return ActivityItem(
      title: title,
      meta: metaParts.join(' • '),
      iconType: ActivityIconType.invoice,
    );
  }

  static ActivityItem _productActivity(ProductRecord product) {
    return ActivityItem(
      title: 'New inventory: ${product.displayName}',
      meta:
          '${(product.category ?? 'INVENTORY').toUpperCase()} • ${_relativeTime(product.createdAt ?? DateTime.now())}',
      iconType: ActivityIconType.inventory,
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
  if (diff.inMinutes < 1) return 'JUST NOW';
  if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
  if (diff.inHours < 24) return '${diff.inHours}H AGO';
  if (diff.inDays < 7) return '${diff.inDays}D AGO';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}W AGO';
  return '${(diff.inDays / 30).floor()}MO AGO';
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
