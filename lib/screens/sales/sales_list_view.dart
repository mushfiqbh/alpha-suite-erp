// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/models/customer.dart';
import 'package:erp/models/sales_order.dart';
import 'package:erp/providers/customer_providers.dart';
import 'package:erp/providers/sales_providers.dart';
import 'package:erp/utils/formatters.dart';

/// Read-only table view of recent sales orders pulled from
/// `public.sales_orders`. Used by the `/sales` route. The
/// checkout / point-of-sale workflow lives at `/pos` instead.
class SalesListView extends ConsumerStatefulWidget {
  const SalesListView({super.key});

  @override
  ConsumerState<SalesListView> createState() => _SalesListViewState();
}

class _SalesListViewState extends ConsumerState<SalesListView> {
  static const double _desktopBreakpoint = 960;

  final MoneyFormatter _money = const MoneyFormatter();
  final DateTimeFormatter _dateTime = const DateTimeFormatter();

  String _search = '';
  String? _paymentFilter;
  String? _salesStatusFilter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(recentSalesOrdersProvider);
    final customers = ref.watch(customerDirectoryProvider).customers;
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          _FiltersBar(
            search: _search,
            paymentFilter: _paymentFilter,
            salesStatusFilter: _salesStatusFilter,
            onSearchChanged: (value) => setState(() => _search = value),
            onPaymentChanged: (value) => setState(() => _paymentFilter = value),
            onSalesStatusChanged: (value) =>
                setState(() => _salesStatusFilter = value),
            onClear: () => setState(() {
              _search = '';
              _paymentFilter = null;
              _salesStatusFilter = null;
            }),
            onRefresh: () =>
                ref.read(recentSalesOrdersProvider.notifier).refresh(),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ordersAsync.when(
              data: (orders) => _buildContent(
                context,
                orders: orders,
                customers: customers,
                isDesktop: isDesktop,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                message: error.toString(),
                onRetry: () =>
                    ref.read(recentSalesOrdersProvider.notifier).refresh(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required List<SalesOrderRecord> orders,
    required List<CustomerRecord> customers,
    required bool isDesktop,
  }) {
    if (orders.isEmpty) {
      return const _EmptyState();
    }

    final filtered = _applyFilters(orders);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _SummaryStrip(
            totalCount: orders.length,
            filteredCount: filtered.length,
            totalRevenue: filtered.fold<double>(
              0,
              (sum, order) => sum + order.grandTotal,
            ),
            outstanding: filtered.fold<double>(
              0,
              (sum, order) => sum + order.dueAmount,
            ),
            money: _money,
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          if (isDesktop)
            Expanded(
              child: _SalesOrdersTable(
                orders: filtered,
                customers: customers,
                money: _money,
                dateTime: _dateTime,
                onTapOrder: (order) => _showOrderDetails(context, order),
                onMarkPaymentDone: (orderId) => ref
                    .read(recentSalesOrdersProvider.notifier)
                    .markPaymentDone(orderId),
                onMarkAsUnpaid: (orderId) => ref
                    .read(recentSalesOrdersProvider.notifier)
                    .markAsUnpaid(orderId),
              ),
            )
          else
            Expanded(
              child: _SalesOrdersCards(
                orders: filtered,
                customers: customers,
                money: _money,
                dateTime: _dateTime,
                onTapOrder: (order) => _showOrderDetails(context, order),
                onMarkPaymentDone: (orderId) => ref
                    .read(recentSalesOrdersProvider.notifier)
                    .markPaymentDone(orderId),
                onMarkAsUnpaid: (orderId) => ref
                    .read(recentSalesOrdersProvider.notifier)
                    .markAsUnpaid(orderId),
              ),
            ),
        ],
      ),
    );
  }

  List<SalesOrderRecord> _applyFilters(List<SalesOrderRecord> orders) {
    final query = _search.trim().toLowerCase();
    return orders.where((order) {
      if (_paymentFilter != null &&
          order.paymentStatus.toUpperCase() != _paymentFilter) {
        return false;
      }
      if (_salesStatusFilter != null &&
          order.salesStatus.toUpperCase() != _salesStatusFilter) {
        return false;
      }
      if (query.isEmpty) return true;

      return order.invoiceNo.toLowerCase().contains(query) ||
          (order.notes?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void _showOrderDetails(BuildContext context, SalesOrderRecord order) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) =>
          _OrderDetailsSheet(order: order, money: _money, dateTime: _dateTime),
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({
    required this.search,
    required this.paymentFilter,
    required this.salesStatusFilter,
    required this.onSearchChanged,
    required this.onPaymentChanged,
    required this.onSalesStatusChanged,
    required this.onClear,
    required this.onRefresh,
  });

  final String search;
  final String? paymentFilter;
  final String? salesStatusFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onPaymentChanged;
  final ValueChanged<String?> onSalesStatusChanged;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: 'Search invoice or notes',
                hintStyle: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF4F46E5),
                    width: 1.5,
                  ),
                ),
              ),
              style: GoogleFonts.inter(fontSize: 13),
            ),
          ),
          FilledButton.icon(
            onPressed: onRefresh,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.totalCount,
    required this.filteredCount,
    required this.totalRevenue,
    required this.outstanding,
    required this.money,
  });

  final int totalCount;
  final int filteredCount;
  final double totalRevenue;
  final double outstanding;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        children: [
          _SummaryCell(
            label: 'Showing',
            value: '$filteredCount of $totalCount orders',
          ),
          _SummaryCell(
            label: 'Revenue (filtered)',
            value: money.format(totalRevenue),
          ),
          _SummaryCell(
            label: 'Outstanding',
            value: money.format(outstanding),
            valueColor: outstanding > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _SalesOrdersTable extends StatelessWidget {
  const _SalesOrdersTable({
    required this.orders,
    required this.customers,
    required this.money,
    required this.dateTime,
    required this.onTapOrder,
    required this.onMarkPaymentDone,
    required this.onMarkAsUnpaid,
  });

  final List<SalesOrderRecord> orders;
  final List<CustomerRecord> customers;
  final MoneyFormatter money;
  final DateTimeFormatter dateTime;
  final ValueChanged<SalesOrderRecord> onTapOrder;
  final Future<void> Function(String orderId) onMarkPaymentDone;
  final Future<void> Function(String orderId) onMarkAsUnpaid;

  String _customerNameFor(SalesOrderRecord order) {
    final id = order.customerId;
    if (id == null) return '—';
    for (final customer in customers) {
      if (customer.id == id) return customer.displayName;
    }
    return 'Customer #$id';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 960),
        child: DataTable(
          headingRowHeight: 48,
          dataRowMinHeight: 60,
          dataRowMaxHeight: 72,
          columnSpacing: 24,
          headingTextStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.6,
          ),
          dataTextStyle: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF0F172A),
          ),
          columns: const [
            DataColumn(label: Text('INVOICE')),
            DataColumn(label: Text('CUSTOMER')),
            DataColumn(label: Text('DATE')),
            DataColumn(label: Text('ITEMS')),
            DataColumn(label: Text('TOTAL'), numeric: true),
            DataColumn(label: Text('PAYMENT')),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('')),
          ],
          rows: orders
              .map(
                (order) => DataRow(
                  onSelectChanged: (_) => onTapOrder(order),
                  cells: [
                    DataCell(
                      Text(
                        order.invoiceNo.isEmpty ? '—' : order.invoiceNo,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        _customerNameFor(order),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      Text(
                        dateTime.format(order.orderDate.toLocal()),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '—',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        money.format(order.grandTotal),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(_PaymentChip(status: order.paymentStatus)),
                    DataCell(_SalesStatusChip(status: order.salesStatus)),
                    DataCell(
                      order.paymentStatus.toUpperCase() == 'UNPAID'
                          ? FilledButton(
                              onPressed: () =>
                                  onMarkPaymentDone(order.id ?? ''),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Pay',
                                style: TextStyle(fontSize: 11),
                              ),
                            )
                          : order.paymentStatus.toUpperCase() == 'PAID'
                          ? FilledButton(
                              onPressed: () => onMarkAsUnpaid(order.id ?? ''),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Unpaid',
                                style: TextStyle(fontSize: 11),
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SalesOrdersCards extends StatelessWidget {
  const _SalesOrdersCards({
    required this.orders,
    required this.customers,
    required this.money,
    required this.dateTime,
    required this.onTapOrder,
    required this.onMarkPaymentDone,
    required this.onMarkAsUnpaid,
  });

  final List<SalesOrderRecord> orders;
  final List<CustomerRecord> customers;
  final MoneyFormatter money;
  final DateTimeFormatter dateTime;
  final ValueChanged<SalesOrderRecord> onTapOrder;
  final Future<void> Function(String orderId) onMarkPaymentDone;
  final Future<void> Function(String orderId) onMarkAsUnpaid;

  String _customerNameFor(SalesOrderRecord order) {
    final id = order.customerId;
    if (id == null) return 'Walk-in';
    for (final customer in customers) {
      if (customer.id == id) return customer.displayName;
    }
    return 'Customer #$id';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onTapOrder(order),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.invoiceNo.isEmpty ? '—' : order.invoiceNo,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        money.format(order.grandTotal),
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _customerNameFor(order),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _PaymentChip(status: order.paymentStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        dateTime.format(order.orderDate.toLocal()),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentChip extends StatelessWidget {
  const _PaymentChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final (label, bg, fg) = switch (normalized) {
      'PAID' => ('Paid', const Color(0xFFDCFCE7), const Color(0xFF166534)),
      'PARTIAL' => (
        'Partial',
        const Color(0xFFFEF3C7),
        const Color(0xFF92400E),
      ),
      'UNPAID' => ('Unpaid', const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
      _ => (normalized, const Color(0xFFE2E8F0), const Color(0xFF334155)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _SalesStatusChip extends StatelessWidget {
  const _SalesStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final (label, bg, fg) = switch (normalized) {
      'DRAFT' => ('Draft', const Color(0xFFE0E7FF), const Color(0xFF3730A3)),
      'CONFIRMED' => (
        'Confirmed',
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
      ),
      'FULFILLED' || 'COMPLETED' => (
        'Completed',
        const Color(0xFFDCFCE7),
        const Color(0xFF166534),
      ),
      'CANCELLED' => (
        'Cancelled',
        const Color(0xFFFEE2E2),
        const Color(0xFF991B1B),
      ),
      _ => (normalized, const Color(0xFFE2E8F0), const Color(0xFF334155)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _OrderDetailsSheet extends ConsumerWidget {
  const _OrderDetailsSheet({
    required this.order,
    required this.money,
    required this.dateTime,
  });

  final SalesOrderRecord order;
  final MoneyFormatter money;
  final DateTimeFormatter dateTime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderId = order.id;
    final itemsAsync = orderId == null
        ? const AsyncValue<List<SalesOrderItemRecord>>.data([])
        : ref.watch(salesOrderItemsProvider(orderId));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.invoiceNo.isEmpty
                                ? 'Order details'
                                : 'Invoice ${order.invoiceNo}',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateTime.format(order.orderDate.toLocal()),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PaymentChip(status: order.paymentStatus),
                        if (order.paymentStatus.toUpperCase() == 'UNPAID')
                          FilledButton(
                            onPressed: () {
                              ref
                                  .read(recentSalesOrdersProvider.notifier)
                                  .markPaymentDone(order.id ?? '');
                              Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Payment Done',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        if (order.paymentStatus.toUpperCase() == 'PAID')
                          FilledButton(
                            onPressed: () {
                              ref
                                  .read(recentSalesOrdersProvider.notifier)
                                  .markAsUnpaid(order.id ?? '');
                              Navigator.of(context).pop();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Make Unpaid',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _DetailsRow(
                      label: 'Customer ID',
                      value: order.customerId ?? '—',
                    ),
                    _DetailsRow(
                      label: 'Due date',
                      value: order.dueDate == null
                          ? '—'
                          : dateTime.format(order.dueDate!.toLocal()),
                    ),
                    _DetailsRow(
                      label: 'Created by',
                      value: order.createdBy ?? '—',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Line items',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    itemsAsync.when(
                      data: (items) => items.isEmpty
                          ? _NoItems()
                          : Column(
                              children: items
                                  .map(
                                    (item) =>
                                        _ItemRow(item: item, money: money),
                                  )
                                  .toList(),
                            ),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Unable to load line items: $error',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _TotalsCard(order: order, money: money),
                    if (order.notes != null) ...[
                      const SizedBox(height: 24),
                      _NotesCard(notes: order.notes!),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.money});

  final SalesOrderItemRecord item;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    final id = item.productId ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
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
                  'Product #$id',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${item.quantity} × ${money.format(item.unitPrice)}'
                  '${item.taxAmount > 0 ? ' • Tax ${money.format(item.taxAmount)}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            money.format(item.lineTotal),
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'No line items were saved for this order.',
        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.order, required this.money});

  final SalesOrderRecord order;
  final MoneyFormatter money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Subtotal', value: money.format(order.subtotal)),
          _TotalRow(
            label: 'Discount',
            value: '- ${money.format(order.discountAmount)}',
            valueColor: const Color(0xFFDC2626),
          ),
          _TotalRow(label: 'Tax', value: money.format(order.taxAmount)),
          _TotalRow(
            label: 'Shipping',
            value: money.format(order.shippingAmount),
          ),
          const Divider(height: 18, color: Color(0xFFE2E8F0)),
          _TotalRow(
            label: 'Grand total',
            value: money.format(order.grandTotal),
            isBold: true,
          ),
          _TotalRow(
            label: 'Paid',
            value: money.format(order.paidAmount),
            valueColor: const Color(0xFF10B981),
          ),
          _TotalRow(
            label: 'Outstanding',
            value: money.format(order.dueAmount),
            valueColor: order.dueAmount > 0
                ? const Color(0xFFDC2626)
                : const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
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

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTES',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF92400E),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            notes,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF4F46E5),
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No sales yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Invoices placed from the POS will appear here.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFDC2626),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Unable to load sales',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
