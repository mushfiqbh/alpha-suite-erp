import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/models/hr.dart';
import 'package:erp/providers/hr_providers.dart';

class PayrollPeriodFormPage extends ConsumerStatefulWidget {
  const PayrollPeriodFormPage({super.key, this.existing});

  final PayrollPeriodRecord? existing;

  @override
  ConsumerState<PayrollPeriodFormPage> createState() =>
      _PayrollPeriodFormPageState();
}

class _PayrollPeriodFormPageState extends ConsumerState<PayrollPeriodFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  late final TextEditingController _monthController;
  late final TextEditingController _yearController;
  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;
  String _status = 'open';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _isEditing = existing != null;

    _monthController = TextEditingController(
      text: existing != null ? existing.month.toString() : '',
    );
    _yearController = TextEditingController(
      text: existing != null ? existing.year.toString() : '',
    );
    _startDateController = TextEditingController(
      text: existing?.startDate != null
          ? _formatDisplayDate(existing!.startDate!)
          : '',
    );
    _endDateController = TextEditingController(
      text: existing?.endDate != null
          ? _formatDisplayDate(existing!.endDate!)
          : '',
    );
    _status = existing?.status ?? 'open';
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = _formatDisplayDate(picked);
    }
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDisplayDate(String text) {
    return DateTime.tryParse(text);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final month = int.tryParse(_monthController.text) ?? 0;
    final year = int.tryParse(_yearController.text) ?? 0;
    final startDate = _parseDisplayDate(_startDateController.text);
    final endDate = _parseDisplayDate(_endDateController.text);

    final period = PayrollPeriodRecord(
      id: widget.existing?.id,
      month: month,
      year: year,
      startDate: startDate,
      endDate: endDate,
      status: _status,
      createdAt: widget.existing?.createdAt,
      updatedAt: null,
    );

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(payrollPeriodListProvider.notifier).savePeriod(period);

    if (!mounted) return;

    final latest = ref.read(payrollPeriodListProvider);
    setState(() => _isSubmitting = false);

    if (latest.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Payroll period updated.' : 'Payroll period created.',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      if (mounted) context.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(latest.errorMessage!),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payrollPeriodListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Payroll Period' : 'New Payroll Period',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle(title: 'Period Details'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FormField(
                      label: 'Month',
                      controller: _monthController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = int.tryParse(v ?? '');
                        if (val == null || val < 1 || val > 12) {
                          return 'Enter 1-12';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _FormField(
                      label: 'Year',
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final val = int.tryParse(v ?? '');
                        if (val == null || val < 2000) {
                          return 'Enter valid year';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start Date',
                      controller: _startDateController,
                      onPick: () => _pickDate(_startDateController),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'End Date',
                      controller: _endDateController,
                      onPick: () => _pickDate(_endDateController),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Status'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                items: PayrollPeriodStatusOptions.values.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      PayrollPeriodStatusOptions.label(s),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 32),
              if (state.isSaving || _isSubmitting)
                const Center(child: CircularProgressIndicator())
              else
                FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isEditing ? 'Update Period' : 'Create Period',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared widgets for this form
// ===========================================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.controller,
    required this.onPick,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onPick;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      validator: validator,
      onTap: onPick,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
        suffixIcon: const Icon(
          Icons.calendar_today_rounded,
          color: Color(0xFF64748B),
          size: 18,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
