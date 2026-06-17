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

class CustomerStatusOptions {
  static const List<String> values = <String>[
    'active',
    'inactive',
    'prospect',
    'lead',
    'customer',
    'vip',
  ];

  static String label(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'prospect':
        return 'Prospect';
      case 'lead':
        return 'Lead';
      case 'customer':
        return 'Customer';
      case 'vip':
        return 'VIP';
      default:
        return _titleCase(value);
    }
  }

  static Color color(String value) {
    switch (value.toLowerCase()) {
      case 'active':
      case 'customer':
        return const Color(0xFF10B981);
      case 'inactive':
        return const Color(0xFF64748B);
      case 'prospect':
        return const Color(0xFFF59E0B);
      case 'lead':
        return const Color(0xFFF97316);
      case 'vip':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF334155);
    }
  }
}

class CustomerRecord {
  const CustomerRecord({
    required this.id,
    required this.customerCode,
    required this.customerType,
    required this.companyName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.website,
    required this.industry,
    required this.billingAddress,
    required this.shippingAddress,
    required this.city,
    required this.country,
    required this.status,
    required this.source,
    required this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  factory CustomerRecord.empty({String? customerCode}) {
    return CustomerRecord(
      id: null,
      customerCode: customerCode ?? '',
      customerType: 'company',
      companyName: null,
      firstName: null,
      lastName: null,
      email: null,
      phone: null,
      website: null,
      industry: null,
      billingAddress: null,
      shippingAddress: null,
      city: null,
      country: null,
      status: 'prospect',
      source: null,
      assignedTo: null,
      createdAt: null,
      updatedAt: null,
      createdBy: null,
    );
  }

  factory CustomerRecord.fromMap(Map<String, dynamic> data) {
    return CustomerRecord(
      id: data['id']?.toString(),
      customerCode: (data['customer_code'] ?? '').toString(),
      customerType: (data['customer_type'] ?? 'company').toString(),
      companyName: _emptyToNull(data['company_name']?.toString()),
      firstName: _emptyToNull(data['first_name']?.toString()),
      lastName: _emptyToNull(data['last_name']?.toString()),
      email: _emptyToNull(data['email']?.toString()),
      phone: _emptyToNull(data['phone']?.toString()),
      website: _emptyToNull(data['website']?.toString()),
      industry: _emptyToNull(data['industry']?.toString()),
      billingAddress: _emptyToNull(data['billing_address']?.toString()),
      shippingAddress: _emptyToNull(data['shipping_address']?.toString()),
      city: _emptyToNull(data['city']?.toString()),
      country: _emptyToNull(data['country']?.toString()),
      status: (data['status'] ?? 'prospect').toString().toLowerCase(),
      source: _emptyToNull(data['source']?.toString()),
      assignedTo: data['assigned_to']?.toString(),
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? ''),
      createdBy: data['created_by']?.toString(),
    );
  }

  final String? id;
  final String customerCode;
  final String customerType;
  final String? companyName;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? website;
  final String? industry;
  final String? billingAddress;
  final String? shippingAddress;
  final String? city;
  final String? country;
  final String status;
  final String? source;
  final String? assignedTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  String get displayName {
    final company = companyName?.trim() ?? '';
    if (company.isNotEmpty) {
      return company;
    }

    final person = [
      firstName?.trim() ?? '',
      lastName?.trim() ?? '',
    ].where((value) => value.isNotEmpty).join(' ');

    if (person.isNotEmpty) {
      return person;
    }

    return customerCode.isNotEmpty ? customerCode : 'Unnamed Customer';
  }

  String get subtitle {
    final parts = <String>[
      if (email != null) email!,
      if (phone != null) phone!,
    ];
    return parts.join(' • ');
  }

  String get location {
    final parts = <String>[
      if (city != null) city!,
      if (country != null) country!,
    ];
    return parts.isEmpty ? 'No location set' : parts.join(', ');
  }

  String get typeLabel =>
      customerType.trim().isEmpty ? 'Unspecified' : _titleCase(customerType);

  Map<String, dynamic> toInsertMap({required String? createdById}) {
    return <String, dynamic>{
      'customer_code': customerCode.trim(),
      'customer_type': customerType.trim().isEmpty
          ? 'company'
          : customerType.trim(),
      'company_name': _emptyToNull(companyName),
      'first_name': _emptyToNull(firstName),
      'last_name': _emptyToNull(lastName),
      'email': _emptyToNull(email),
      'phone': _emptyToNull(phone),
      'website': _emptyToNull(website),
      'industry': _emptyToNull(industry),
      'billing_address': _emptyToNull(billingAddress),
      'shipping_address': _emptyToNull(shippingAddress),
      'city': _emptyToNull(city),
      'country': _emptyToNull(country),
      'status': status.trim().isEmpty
          ? 'prospect'
          : status.trim().toLowerCase(),
      'source': _emptyToNull(source),
      'assigned_to': _emptyToNull(assignedTo),
      'created_by': _emptyToNull(createdById),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return <String, dynamic>{
      'customer_code': customerCode.trim(),
      'customer_type': customerType.trim().isEmpty
          ? 'company'
          : customerType.trim(),
      'company_name': _emptyToNull(companyName),
      'first_name': _emptyToNull(firstName),
      'last_name': _emptyToNull(lastName),
      'email': _emptyToNull(email),
      'phone': _emptyToNull(phone),
      'website': _emptyToNull(website),
      'industry': _emptyToNull(industry),
      'billing_address': _emptyToNull(billingAddress),
      'shipping_address': _emptyToNull(shippingAddress),
      'city': _emptyToNull(city),
      'country': _emptyToNull(country),
      'status': status.trim().isEmpty
          ? 'prospect'
          : status.trim().toLowerCase(),
      'source': _emptyToNull(source),
      'assigned_to': _emptyToNull(assignedTo),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  CustomerRecord copyWith({
    String? id,
    String? customerCode,
    String? customerType,
    String? companyName,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? website,
    String? industry,
    String? billingAddress,
    String? shippingAddress,
    String? city,
    String? country,
    String? status,
    String? source,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return CustomerRecord(
      id: id ?? this.id,
      customerCode: customerCode ?? this.customerCode,
      customerType: customerType ?? this.customerType,
      companyName: companyName ?? this.companyName,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      website: website ?? this.website,
      industry: industry ?? this.industry,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      city: city ?? this.city,
      country: country ?? this.country,
      status: status ?? this.status,
      source: source ?? this.source,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class ProfileOption {
  const ProfileOption({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory ProfileOption.fromMap(Map<String, dynamic> data) {
    return ProfileOption(
      id: data['id']?.toString() ?? '',
      fullName: (data['full_name'] ?? 'Unnamed User').toString(),
      email: _emptyToNull(data['email']?.toString()),
    );
  }

  final String id;
  final String fullName;
  final String? email;

  String get displayName {
    if (email == null || email!.isEmpty) {
      return fullName;
    }
    return '$fullName • $email';
  }
}
