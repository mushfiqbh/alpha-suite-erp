import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/customer.dart';
import 'package:erp/providers/customer_providers.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key, this.existing});

  final CustomerRecord? existing;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  late final CustomerRecord? _initialExisting;

  late final TextEditingController _codeController;
  late final TextEditingController _companyController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _shippingController;
  late final TextEditingController _cityController;

  bool _dependenciesResolved = false;

  String _generateDraftCode() {
    final token = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    final compact = token.length > 8
        ? token.substring(token.length - 8)
        : token;
    return 'CUST-$compact';
  }

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _codeController = TextEditingController(
      text: existing?.customerCode.isNotEmpty == true
          ? existing!.customerCode
          : _generateDraftCode(),
    );
    _companyController = TextEditingController(
      text: existing?.companyName ?? '',
    );
    _firstNameController = TextEditingController(
      text: existing?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: existing?.lastName ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _shippingController = TextEditingController(
      text: existing?.shippingAddress ?? '',
    );
    _cityController = TextEditingController(text: existing?.city ?? '');
  }

  void _initializeFromRoute(CustomerRecord existing) {
    _codeController = TextEditingController(
      text: existing.customerCode.isNotEmpty == true
          ? existing.customerCode
          : _generateDraftCode(),
    );
    _companyController = TextEditingController(
      text: existing.companyName ?? '',
    );
    _firstNameController = TextEditingController(
      text: existing.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: existing.lastName ?? '');
    _emailController = TextEditingController(text: existing.email ?? '');
    _phoneController = TextEditingController(text: existing.phone ?? '');
    _shippingController = TextEditingController(
      text: existing.shippingAddress ?? '',
    );
    _cityController = TextEditingController(text: existing.city ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesResolved) {
      return;
    }
    _dependenciesResolved = true;
    if (_initialExisting != null) {
      return;
    }
    final extra = GoRouterState.of(context).extra;
    if (extra is! CustomerRecord) {
      return;
    }
    // Dispose the placeholder controllers created in initState, then rebuild
    // them from the route-supplied record.
    _codeController.dispose();
    _companyController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _shippingController.dispose();
    _cityController.dispose();
    _initialExisting = extra;
    _initializeFromRoute(extra);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _companyController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _shippingController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    final controller = ref.read(customerDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = CustomerRecord(
      id: _initialExisting?.id,
      customerCode: _codeController.text.trim(),
      customerType: 'company',
      companyName: _trimOrNull(_companyController),
      firstName: _trimOrNull(_firstNameController),
      lastName: _trimOrNull(_lastNameController),
      email: _trimOrNull(_emailController),
      phone: _trimOrNull(_phoneController),
      website: null,
      industry: null,
      billingAddress: null,
      shippingAddress: _trimOrNull(_shippingController),
      city: _trimOrNull(_cityController),
      country: null,
      status: 'prospect',
      source: null,
      assignedTo: null,
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
      createdBy: _initialExisting?.createdBy,
    );

    try {
      await controller.saveCustomer(draft);
      final latestState = ref.read(customerDirectoryProvider);
      if (!mounted) {
        return;
      }
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Customer saved successfully.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          navigator.go(AppRoutes.customers);
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(latestState.errorMessage!),
            backgroundColor: Colors.red.shade600,
          ),
        );
        setState(() => _isSubmitting = false);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save customer: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String? _trimOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    final existing = _initialExisting;
    final isEdit = existing != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to customers',
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.customers);
            }
          },
        ),
        title: Row(
          children: [
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isEdit ? 'Edit Customer' : 'New Customer',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TextInput(
                    controller: _codeController,
                    label: 'Customer Code',
                    hintText: 'CUST-0001',
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Customer code is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _FieldRow(
                    left: _TextInput(
                      controller: _firstNameController,
                      label: 'First Name',
                      hintText: 'Sarah',
                    ),
                    right: _TextInput(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hintText: 'Ahmed',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldRow(
                    left: _TextInput(
                      controller: _companyController,
                      label: 'Company Name',
                      hintText: 'Nova Blue Tech',
                    ),
                    right: _TextInput(
                      controller: _emailController,
                      label: 'Email',
                      hintText: 'billing@company.com',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FieldRow(
                    left: _TextInput(
                      controller: _phoneController,
                      label: 'Phone',
                      hintText: '+1 (555) 123-4567',
                      keyboardType: TextInputType.phone,
                    ),
                    right: _TextInput(
                      controller: _cityController,
                      label: 'City',
                      hintText: 'Dhaka',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TextInput(
                    controller: _shippingController,
                    label: 'Shipping Address',
                    hintText: 'Street, warehouse, delivery note',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        if (GoRouter.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.customers);
                        }
                      },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 20),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _handleSave,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSubmitting ? 'Saving...' : 'Save Customer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        if (!isWide) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
        ),
      ),
    );
  }
}
