import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/product.dart';
import 'package:erp/providers/product_providers.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, this.existing});

  final ProductRecord? existing;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dependenciesResolved = false;

  late final ProductRecord? _initialExisting;

  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _customUnitController;
  late final TextEditingController _priceController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late final TextEditingController _reorderController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _supplierController;
  late final TextEditingController _locationController;
  late final TextEditingController _taxController;

  late String _selectedStatus;
  late String? _selectedUnit;
  bool _isTaxable = true;

  String _generateDraftSku() {
    final token = DateTime.now().millisecondsSinceEpoch
        .toRadixString(36)
        .toUpperCase();
    final compact = token.length > 8
        ? token.substring(token.length - 8)
        : token;
    return 'PROD-$compact';
  }

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;

    _skuController = TextEditingController(
      text: existing != null && existing.sku.isNotEmpty
          ? existing.sku
          : _generateDraftSku(),
    );
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _categoryController = TextEditingController(text: existing?.category ?? '');
    final initialUnitRaw = (existing == null || existing.unit.isEmpty)
        ? 'pcs'
        : existing.unit;
    final initialUnit = initialUnitRaw.toLowerCase();
    if (ProductUnitOptions.isKnown(initialUnit)) {
      _selectedUnit = initialUnit;
      _customUnitController = TextEditingController();
    } else {
      _selectedUnit = ProductUnitOptions.customSentinel;
      _customUnitController = TextEditingController(text: initialUnit);
    }
    _priceController = TextEditingController(
      text: existing != null ? existing.price.toStringAsFixed(2) : '0.00',
    );
    _costController = TextEditingController(
      text: existing != null ? existing.cost.toStringAsFixed(2) : '0.00',
    );
    _stockController = TextEditingController(
      text: existing != null ? existing.stock.toString() : '0',
    );
    _reorderController = TextEditingController(
      text: existing != null ? existing.reorderLevel.toString() : '0',
    );
    _barcodeController = TextEditingController(text: existing?.barcode ?? '');
    _supplierController = TextEditingController(text: existing?.supplier ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _taxController = TextEditingController(
      text: existing != null ? existing.taxRate.toStringAsFixed(2) : '0.00',
    );

    _selectedStatus = existing?.status ?? 'active';
    _isTaxable = existing?.isTaxable ?? true;
  }

  void _initializeFromRoute(ProductRecord existing) {
    _skuController = TextEditingController(
      text: existing.sku.isNotEmpty ? existing.sku : _generateDraftSku(),
    );
    _nameController = TextEditingController(text: existing.name);
    _descriptionController = TextEditingController(
      text: existing.description ?? '',
    );
    _categoryController = TextEditingController(text: existing.category ?? '');
    final initialUnitRaw = existing.unit.isEmpty ? 'pcs' : existing.unit;
    final initialUnit = initialUnitRaw.toLowerCase();
    if (ProductUnitOptions.isKnown(initialUnit)) {
      _selectedUnit = initialUnit;
      _customUnitController = TextEditingController();
    } else {
      _selectedUnit = ProductUnitOptions.customSentinel;
      _customUnitController = TextEditingController(text: initialUnit);
    }
    _priceController = TextEditingController(
      text: existing.price.toStringAsFixed(2),
    );
    _costController = TextEditingController(
      text: existing.cost.toStringAsFixed(2),
    );
    _stockController = TextEditingController(text: existing.stock.toString());
    _reorderController = TextEditingController(
      text: existing.reorderLevel.toString(),
    );
    _barcodeController = TextEditingController(text: existing.barcode ?? '');
    _supplierController = TextEditingController(text: existing.supplier ?? '');
    _locationController = TextEditingController(text: existing.location ?? '');
    _taxController = TextEditingController(
      text: existing.taxRate.toStringAsFixed(2),
    );

    _selectedStatus = existing.status.isEmpty ? 'active' : existing.status;
    _isTaxable = existing.isTaxable;
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
    if (extra is! ProductRecord) {
      return;
    }
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _customUnitController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _barcodeController.dispose();
    _supplierController.dispose();
    _locationController.dispose();
    _taxController.dispose();

    _initialExisting = extra;
    _initializeFromRoute(extra);
    setState(() {});
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _customUnitController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    _barcodeController.dispose();
    _supplierController.dispose();
    _locationController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  double _parseDouble(String raw, {double fallback = 0}) {
    final value = double.tryParse(raw.trim());
    return value ?? fallback;
  }

  int _parseInt(String raw, {int fallback = 0}) {
    final value = int.tryParse(raw.trim());
    return value ?? fallback;
  }

  String _resolveUnitValue() {
    final selected = _selectedUnit;
    if (selected == null) {
      return 'pcs';
    }
    if (selected == ProductUnitOptions.customSentinel) {
      final custom = _customUnitController.text.trim();
      return custom.isEmpty ? 'pcs' : custom.toLowerCase();
    }
    return selected;
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    final controller = ref.read(productDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = ProductRecord(
      id: _initialExisting?.id,
      sku: _skuController.text.trim(),
      name: _nameController.text.trim(),
      description: _trimOrNull(_descriptionController),
      category: _trimOrNull(_categoryController),
      unit: _resolveUnitValue(),
      price: _parseDouble(_priceController.text),
      cost: _parseDouble(_costController.text),
      stock: _parseInt(_stockController.text),
      reorderLevel: _parseInt(_reorderController.text),
      status: _selectedStatus,
      barcode: _trimOrNull(_barcodeController),
      supplier: _trimOrNull(_supplierController),
      location: _trimOrNull(_locationController),
      taxRate: _parseDouble(_taxController.text),
      isTaxable: _isTaxable,
      imageUrl: _initialExisting?.imageUrl,
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
      createdBy: _initialExisting?.createdBy,
    );

    try {
      await controller.saveProduct(draft);
      final latestState = ref.read(productDirectoryProvider);
      if (!mounted) {
        return;
      }
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Product saved successfully.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        navigator.go(AppRoutes.products);
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(latestState.errorMessage!),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _trimOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _requiredText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _nonNegativeNumber(String? value, {bool allowDecimals = true}) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final numeric = allowDecimals
        ? double.tryParse(value.trim())
        : int.tryParse(value.trim());
    if (numeric == null) {
      return 'Enter a valid number';
    }
    if (numeric < 0) {
      return 'Must be zero or greater';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _initialExisting != null;
    final isSaving =
        _isSubmitting ||
        ref.watch(productDirectoryProvider.select((state) => state.isSaving));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: const Color(0xFF0F172A),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              GoRouter.of(context).go(AppRoutes.products);
            }
          },
        ),
        title: Text(
          isEditing ? 'Edit Product' : 'New Product',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionCard(
                      title: 'General information',
                      children: [
                        _FormRow(
                          children: [
                            _TextField(
                              controller: _skuController,
                              label: 'SKU',
                              hint: 'Internal product code',
                              validator: _requiredText,
                            ),
                            _TextField(
                              controller: _nameController,
                              label: 'Product name',
                              hint: 'What is this product called?',
                              validator: _requiredText,
                            ),
                          ],
                        ),
                        _FormRow(
                          children: [
                            _TextField(
                              controller: _categoryController,
                              label: 'Category',
                              hint: 'e.g. Beverages, Hardware',
                            ),
                            _UnitField(
                              selectedUnit: _selectedUnit,
                              customController: _customUnitController,
                              onChanged: (value) {
                                setState(() {
                                  _selectedUnit = value;
                                  if (value !=
                                      ProductUnitOptions.customSentinel) {
                                    _customUnitController.clear();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        _FormRow(
                          full: true,
                          child: _TextField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Add details, notes, or specifications',
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Pricing & stock',
                      children: [
                        _FormRow(
                          children: [
                            _TextField(
                              controller: _priceController,
                              label: 'Selling price',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) => _nonNegativeNumber(
                                value,
                                allowDecimals: true,
                              ),
                            ),
                            _TextField(
                              controller: _costController,
                              label: 'Cost price',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) => _nonNegativeNumber(
                                value,
                                allowDecimals: true,
                              ),
                            ),
                          ],
                        ),
                        _FormRow(
                          children: [
                            _TextField(
                              controller: _stockController,
                              label: 'Stock on hand',
                              hint: '0',
                              keyboardType: TextInputType.number,
                              validator: (value) => _nonNegativeNumber(
                                value,
                                allowDecimals: false,
                              ),
                            ),
                            _TextField(
                              controller: _taxController,
                              label: 'Tax rate (%)',
                              hint: '0.00',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) => _nonNegativeNumber(
                                value,
                                allowDecimals: true,
                              ),
                            ),
                          ],
                        ),
                        _FormRow(
                          full: true,
                          child: SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _isTaxable,
                            activeThumbColor: const Color(0xFF4F46E5),
                            title: const Text(
                              'Apply tax to this product',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: const Text(
                              'Toggle off for tax-exempt items.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                            onChanged: (value) {
                              setState(() => _isTaxable = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Logistics',
                      children: [
                        _FormRow(
                          children: [
                            _TextField(
                              controller: _barcodeController,
                              label: 'Barcode',
                              hint: 'UPC / EAN code',
                            ),
                            _TextField(
                              controller: _supplierController,
                              label: 'Supplier',
                              hint: 'Preferred vendor',
                            ),
                          ],
                        ),
                        _FormRow(
                          full: true,
                          child: _TextField(
                            controller: _locationController,
                            label: 'Storage location',
                            hint: 'Warehouse, shelf, bin',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () {
                                    if (Navigator.of(context).canPop()) {
                                      Navigator.of(context).pop();
                                    } else {
                                      GoRouter.of(
                                        context,
                                      ).go(AppRoutes.products);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isSaving ? null : _handleSave,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.3,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: Text(
                              isSaving
                                  ? 'Saving...'
                                  : isEditing
                                  ? 'Update product'
                                  : 'Create product',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({this.children, this.full = false, this.child})
    : assert(
        (children == null) != (child == null),
        'Provide either children or child, not both.',
      );

  final List<Widget>? children;
  final bool full;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (full) {
      return Padding(padding: const EdgeInsets.only(bottom: 16), child: child!);
    }

    final kids = children!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 560;
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < kids.length; i++) ...[
                  kids[i],
                  if (i != kids.length - 1) const SizedBox(height: 16),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < kids.length; i++) ...[
                Expanded(child: kids[i]),
                if (i != kids.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _UnitField extends StatelessWidget {
  const _UnitField({
    required this.selectedUnit,
    required this.customController,
    required this.onChanged,
  });

  final String? selectedUnit;
  final TextEditingController customController;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isCustom = selectedUnit == ProductUnitOptions.customSentinel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DropdownField<String>(
          label: 'Unit',
          value: selectedUnit,
          items: <DropdownMenuItem<String>>[
            for (final value in ProductUnitOptions.values)
              DropdownMenuItem<String>(
                value: value,
                child: Text(ProductUnitOptions.label(value)),
              ),
            const DropdownMenuItem<String>(
              value: ProductUnitOptions.customSentinel,
              child: Text('Custom...'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            onChanged(value);
          },
        ),
        if (isCustom) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: customController,
            decoration: const InputDecoration(
              labelText: 'Custom unit',
              hintText: 'e.g. bundle, kit, licence',
              filled: true,
              fillColor: Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(18)),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
            ),
            validator: (value) {
              if (selectedUnit != ProductUnitOptions.customSentinel) {
                return null;
              }
              if (value == null || value.trim().isEmpty) {
                return 'Enter a custom unit';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }
}
