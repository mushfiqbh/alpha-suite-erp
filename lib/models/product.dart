import 'package:flutter/material.dart';

String? _emptyToNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _titleCase(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase());

  return words.join(' ');
}

double _parseDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase() ?? '';
  return text == 'true' || text == 't' || text == '1' || text == 'yes';
}

class ProductStatusOptions {
  static const List<String> values = <String>[
    'active',
    'inactive',
    'draft',
    'archived',
    'out_of_stock',
  ];

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'draft':
        return 'Draft';
      case 'archived':
        return 'Archived';
      case 'out_of_stock':
        return 'Out of stock';
      default:
        return _titleCase(value.replaceAll('_', ' '));
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return const Color(0xFF10B981);
      case 'inactive':
        return const Color(0xFF64748B);
      case 'draft':
        return const Color(0xFFF59E0B);
      case 'archived':
        return const Color(0xFF94A3B8);
      case 'out_of_stock':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF334155);
    }
  }
}

class ProductUnitOptions {
  static const String customSentinel = '__custom__';

  static const List<String> values = <String>[
    'pcs',
    'box',
    'pack',
    'set',
    'pair',
    'dozen',
    'kg',
    'g',
    'lb',
    'oz',
    'l',
    'ml',
    'm',
    'cm',
    'mm',
    'sqm',
    'hour',
    'day',
    'service',
  ];

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'pcs':
        return 'Pieces (pcs)';
      case 'box':
        return 'Box';
      case 'pack':
        return 'Pack';
      case 'set':
        return 'Set';
      case 'pair':
        return 'Pair';
      case 'dozen':
        return 'Dozen';
      case 'kg':
        return 'Kilogram (kg)';
      case 'g':
        return 'Gram (g)';
      case 'lb':
        return 'Pound (lb)';
      case 'oz':
        return 'Ounce (oz)';
      case 'l':
        return 'Litre (L)';
      case 'ml':
        return 'Millilitre (mL)';
      case 'm':
        return 'Metre (m)';
      case 'cm':
        return 'Centimetre (cm)';
      case 'mm':
        return 'Millimetre (mm)';
      case 'sqm':
        return 'Square metre (m²)';
      case 'hour':
        return 'Hour';
      case 'day':
        return 'Day';
      case 'service':
        return 'Service';
      case customSentinel:
        return 'Custom...';
      default:
        return value;
    }
  }

  static bool isKnown(String value) {
    if (value.isEmpty) return true;
    final normalized = value.toLowerCase();
    return values.any((option) => option == normalized);
  }
}

class ProductRecord {
  const ProductRecord({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.category,
    required this.unit,
    required this.price,
    required this.cost,
    required this.stock,
    required this.reorderLevel,
    required this.status,
    required this.barcode,
    required this.supplier,
    required this.location,
    required this.taxRate,
    required this.isTaxable,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory ProductRecord.empty({String? sku}) {
    return ProductRecord(
      id: null,
      sku: sku ?? '',
      name: '',
      description: null,
      category: null,
      unit: 'pcs',
      price: 0,
      cost: 0,
      stock: 0,
      reorderLevel: 0,
      status: 'active',
      barcode: null,
      supplier: null,
      location: null,
      taxRate: 0,
      isTaxable: true,
      imageUrl: null,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );
  }

  factory ProductRecord.fromMap(Map<String, dynamic> data) {
    return ProductRecord(
      id: data['id']?.toString(),
      sku: (data['sku'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      description: _emptyToNull(data['description']?.toString()),
      category: _emptyToNull(data['category']?.toString()),
      unit: (data['unit'] ?? 'pcs').toString(),
      price: _parseDouble(data['price']),
      cost: _parseDouble(data['cost']),
      stock: _parseInt(data['stock']),
      reorderLevel: _parseInt(data['reorder_level']),
      status: (data['status'] ?? 'active').toString().toLowerCase(),
      barcode: _emptyToNull(data['barcode']?.toString()),
      supplier: _emptyToNull(data['supplier']?.toString()),
      location: _emptyToNull(data['location']?.toString()),
      taxRate: _parseDouble(data['tax_rate']),
      isTaxable: data['is_taxable'] == null
          ? true
          : _parseBool(data['is_taxable']),
      imageUrl: _emptyToNull(data['image_url']?.toString()),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      createdBy: data['created_by']?.toString(),
    );
  }

  final String? id;
  final String sku;
  final String name;
  final String? description;
  final String? category;
  final String unit;
  final double price;
  final double cost;
  final int stock;
  final int reorderLevel;
  final String status;
  final String? barcode;
  final String? supplier;
  final String? location;
  final double taxRate;
  final bool isTaxable;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  String get displayName {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    return sku.trim().isNotEmpty ? sku : 'Unnamed Product';
  }

  String get subtitle {
    final parts = <String>[
      if (category != null && category!.trim().isNotEmpty) category!.trim(),
      if (sku.trim().isNotEmpty) 'SKU ${sku.trim()}',
    ];
    return parts.isEmpty ? 'No category set' : parts.join(' • ');
  }

  String get priceLabel {
    return '\$${price.toStringAsFixed(2)}';
  }

  String get stockLabel {
    return '$stock $unit';
  }

  String get categoryLabel {
    final trimmed = category?.trim() ?? '';
    return trimmed.isEmpty ? 'Uncategorized' : _titleCase(trimmed);
  }

  bool get isLowStock => reorderLevel > 0 && stock <= reorderLevel;

  Map<String, dynamic> toInsertMap({required String? createdById}) {
    return <String, dynamic>{
      'sku': sku.trim(),
      'name': name.trim(),
      'description': _emptyToNull(description),
      'category': _emptyToNull(category),
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim().toLowerCase(),
      'price': price,
      'cost': cost,
      'stock': stock,
      'reorder_level': reorderLevel,
      'status': status.trim().isEmpty ? 'active' : status.trim().toLowerCase(),
      'barcode': _emptyToNull(barcode),
      'supplier': _emptyToNull(supplier),
      'location': _emptyToNull(location),
      'tax_rate': taxRate,
      'is_taxable': isTaxable,
      'image_url': _emptyToNull(imageUrl),
      'created_by': _emptyToNull(createdById),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'sku': sku.trim(),
      'name': name.trim(),
      'description': _emptyToNull(description),
      'category': _emptyToNull(category),
      'unit': unit.trim().isEmpty ? 'pcs' : unit.trim().toLowerCase(),
      'price': price,
      'cost': cost,
      'stock': stock,
      'reorder_level': reorderLevel,
      'status': status.trim().isEmpty ? 'active' : status.trim().toLowerCase(),
      'barcode': _emptyToNull(barcode),
      'supplier': _emptyToNull(supplier),
      'location': _emptyToNull(location),
      'tax_rate': taxRate,
      'is_taxable': isTaxable,
      'image_url': _emptyToNull(imageUrl),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ProductRecord copyWith({
    String? id,
    String? sku,
    String? name,
    String? description,
    String? category,
    String? unit,
    double? price,
    double? cost,
    int? stock,
    int? reorderLevel,
    String? status,
    String? barcode,
    String? supplier,
    String? location,
    double? taxRate,
    bool? isTaxable,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ProductRecord(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stock: stock ?? this.stock,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      status: status ?? this.status,
      barcode: barcode ?? this.barcode,
      supplier: supplier ?? this.supplier,
      location: location ?? this.location,
      taxRate: taxRate ?? this.taxRate,
      isTaxable: isTaxable ?? this.isTaxable,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}
