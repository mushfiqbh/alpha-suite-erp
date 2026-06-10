import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/customer.dart';
import 'package:erp/providers/customer_providers.dart';
import 'package:erp/providers/sales_providers.dart';

class CustomerManagementView extends ConsumerStatefulWidget {
  const CustomerManagementView({super.key});

  @override
  ConsumerState<CustomerManagementView> createState() =>
      _CustomerManagementViewState();
}

class _CustomerManagementViewState
    extends ConsumerState<CustomerManagementView> {
  static const int _rowsPerPage = 5;

  int _currentPage = 0;

  List<CustomerRecord> _filteredCustomers(CustomerDirectoryState state) {
    final query = state.searchQuery.trim().toLowerCase();

    return state.customers.where((customer) {
      final matchesSearch =
          query.isEmpty ||
          customer.displayName.toLowerCase().contains(query) ||
          customer.customerCode.toLowerCase().contains(query) ||
          (customer.email ?? '').toLowerCase().contains(query) ||
          (customer.phone ?? '').toLowerCase().contains(query) ||
          (customer.city ?? '').toLowerCase().contains(query) ||
          (customer.country ?? '').toLowerCase().contains(query) ||
          (customer.source ?? '').toLowerCase().contains(query) ||
          (customer.industry ?? '').toLowerCase().contains(query);

      final matchesStatus =
          state.statusFilter == null ||
          customer.status.toLowerCase() == state.statusFilter!.toLowerCase();

      final matchesType =
          state.typeFilter == null ||
          customer.customerType.toLowerCase() ==
              state.typeFilter!.toLowerCase();

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  Future<void> _showFiltersSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerDirectoryState state,
    List<String> customerTypes,
  ) async {
    final controller = ref.read(customerDirectoryProvider.notifier);
    String? selectedStatus = state.statusFilter;
    String? selectedType = state.typeFilter;

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
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Filters',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Narrow the list by status or customer type.',
                      style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All statuses'),
                        ),
                        ...CustomerStatusOptions.values.map(
                          (status) => DropdownMenuItem<String?>(
                            value: status,
                            child: Text(CustomerStatusOptions.label(status)),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() => selectedStatus = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Customer type',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All types'),
                        ),
                        ...customerTypes.map(
                          (type) => DropdownMenuItem<String?>(
                            value: type,
                            child: Text(
                              type.trim().isEmpty
                                  ? 'Unspecified'
                                  : type
                                        .split(RegExp(r'\s+'))
                                        .where((part) => part.isNotEmpty)
                                        .map(
                                          (part) =>
                                              part[0].toUpperCase() +
                                              part.substring(1).toLowerCase(),
                                        )
                                        .join(' '),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setSheetState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              selectedStatus = null;
                              selectedType = null;
                            });
                          },
                          child: const Text('Clear'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () {
                            controller.setStatusFilter(selectedStatus);
                            controller.setTypeFilter(selectedType);
                            if (mounted) {
                              setState(() => _currentPage = 0);
                            }
                            Navigator.of(sheetContext).pop();
                          },
                          child: const Text('Apply'),
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

  Future<void> _openCustomerForm(BuildContext context) {
    return context.push(AppRoutes.customerNew);
  }

  Future<void> _openCustomerEdit(
    BuildContext context,
    CustomerRecord customer,
  ) {
    return context.push(AppRoutes.customerNew, extra: customer);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CustomerRecord customer,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete customer?'),
          content: Text(
            'This will permanently delete ${customer.displayName}. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(customerDirectoryProvider.notifier)
        .deleteCustomer(customer.id!);

    if (!mounted) {
      return;
    }

    final latestState = ref.read(customerDirectoryProvider);
    if (latestState.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('${customer.displayName} deleted.'),
          backgroundColor: const Color(0xFF475569),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerDirectoryProvider);
    final controller = ref.read(customerDirectoryProvider.notifier);
    final filteredCustomers = _filteredCustomers(state);

    final customerTypes = <String>{
      'company',
      'individual',
      'organization',
      'partner',
      'dealer',
      ...state.customers
          .map((customer) => customer.customerType.trim().toLowerCase())
          .where((value) => value.isNotEmpty),
    }.toList()..sort();

    final totalPages = filteredCustomers.isEmpty
        ? 1
        : (filteredCustomers.length / _rowsPerPage).ceil();
    final int safePage = _currentPage.clamp(0, totalPages - 1).toInt();
    final pageStart = filteredCustomers.isEmpty
        ? 0
        : (safePage * _rowsPerPage) + 1;
    final int pageEnd = filteredCustomers.isEmpty
        ? 0
        : math.min(pageStart + _rowsPerPage - 1, filteredCustomers.length);
    final visibleCustomers = filteredCustomers
        .skip(safePage * _rowsPerPage)
        .take(_rowsPerPage)
        .toList();

    final activeFilterCount =
        (state.statusFilter != null ? 1 : 0) +
        (state.typeFilter != null ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      floatingActionButton: _NewCustomerFab(
        onPressed: () => _openCustomerForm(context),
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
                    onFilterTap: () =>
                        _showFiltersSheet(context, ref, state, customerTypes),
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
                                    'Customer Directory',
                                    style: GoogleFonts.poppins(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    filteredCustomers.isEmpty
                                        ? 'No customers match the current search and filters.'
                                        : 'Showing $pageStart-$pageEnd of ${filteredCustomers.length} customers',
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
                        if (filteredCustomers.isEmpty && !state.isLoading)
                          _EmptyCustomersState(
                            hasFilters:
                                state.searchQuery.isNotEmpty ||
                                state.statusFilter != null ||
                                state.typeFilter != null,
                            onCreate: () => _openCustomerForm(context),
                          )
                        else
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final crossAxisCount = width >= 1120
                                  ? 3
                                  : width >= 720
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
                                          crossAxisSpacing: 12,
                                          mainAxisExtent: 150,
                                        ),
                                    itemCount: visibleCustomers.length,
                                    itemBuilder: (context, index) {
                                      final customer = visibleCustomers[index];
                                      return _CustomerCard(
                                        customer: customer,
                                        onEdit: () => _openCustomerEdit(
                                          context,
                                          customer,
                                        ),
                                        onDelete: () => _confirmDelete(
                                          context,
                                          ref,
                                          customer,
                                        ),
                                        onSelectForSale: () {
                                          ref
                                              .read(
                                                salesSelectionProvider.notifier,
                                              )
                                              .select(customer);
                                          context.push(AppRoutes.pos);
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  _PaginationBar(
                                    totalCustomers: filteredCustomers.length,
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

class _NewCustomerFab extends StatelessWidget {
  const _NewCustomerFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'New Customer',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchBarSection extends StatefulWidget {
  const SearchBarSection({
    super.key,
    required this.searchQuery,
    required this.onChanged,
    required this.activeFilterCount,
    required this.onFilterTap,
  });

  final String searchQuery;
  final ValueChanged<String> onChanged;
  final int activeFilterCount;
  final VoidCallback onFilterTap;

  @override
  State<SearchBarSection> createState() => _SearchBarSectionState();
}

class _SearchBarSectionState extends State<SearchBarSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant SearchBarSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery &&
        widget.searchQuery != _controller.text) {
      _controller.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = widget.activeFilterCount > 0;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                hintText: 'Search by name, email, company or ID...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: widget.onFilterTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
                ),
                if (hasFilters)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        '${widget.activeFilterCount}',
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
            ),
          ),
        ),
      ],
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.totalCustomers,
    required this.pageIndex,
    required this.pageCount,
    required this.pageStart,
    required this.pageEnd,
    required this.onPreviousPage,
    required this.onNextPage,
  });

  final int totalCustomers;
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

class _EmptyCustomersState extends StatelessWidget {
  const _EmptyCustomersState({
    required this.hasFilters,
    required this.onCreate,
  });

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
            hasFilters ? Icons.manage_search_rounded : Icons.groups_2_outlined,
            size: 52,
            color: const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No matching customers found' : 'No customers yet',
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
                : 'Create your first customer to start tracking relationships and sales opportunities.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Add Customer'),
          ),
        ],
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onSelectForSale,
  });

  final CustomerRecord customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSelectForSale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _CustomerIdentity(customer: customer)),
              const SizedBox(width: 6),
              _CardIconButton(
                icon: Icons.add_shopping_cart_rounded,
                color: const Color(0xFF10B981),
                tooltip: 'Sell to this customer',
                onPressed: onSelectForSale,
              ),
              const SizedBox(width: 4),
              _CardIconButton(
                icon: Icons.edit_outlined,
                color: const Color(0xFF4F46E5),
                tooltip: 'Edit customer',
                onPressed: onEdit,
              ),
              const SizedBox(width: 4),
              _CardIconButton(
                icon: Icons.delete_outline_rounded,
                color: const Color(0xFFDC2626),
                tooltip: 'Delete customer',
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ContactSummary(customer: customer),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SmallInlineCell(
                  icon: Icons.phone_iphone_rounded,
                  value: customer.phone ?? 'No phone',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallInlineCell(
                  icon: Icons.alternate_email_rounded,
                  value: customer.email ?? 'No email',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardIconButton extends StatelessWidget {
  const _CardIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 20,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class _CustomerIdentity extends StatelessWidget {
  const _CustomerIdentity({required this.customer});

  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) {
    final initials = customer.displayName.isNotEmpty
        ? customer.displayName
              .split(' ')
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0])
              .join()
              .toUpperCase()
        : 'C';

    return Row(
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(
            initials,
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customer.displayName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${customer.customerCode} â€¢ ${customer.typeLabel}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactSummary extends StatelessWidget {
  const _ContactSummary({required this.customer});

  final CustomerRecord customer;

  @override
  Widget build(BuildContext context) {
    return Text(
      customer.location,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF0F172A),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SmallInlineCell extends StatelessWidget {
  const _SmallInlineCell({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
