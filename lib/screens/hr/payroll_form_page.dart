import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/models/hr.dart';
import 'package:erp/providers/hr_providers.dart';

class PayrollFormPage extends ConsumerStatefulWidget {
  const PayrollFormPage({super.key, this.existing});

  final PayrollRecord? existing;

  @override
  ConsumerState<PayrollFormPage> createState() => _PayrollFormPageState();
}

class _PayrollFormPageState extends ConsumerState<PayrollFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isEditing = false;

  late final TextEditingController _employeeIdController;
  late final TextEditingController _basicSalaryController;
  late final TextEditingController _allowanceController;
  late final TextEditingController _overtimeController;
  late final TextEditingController _deductionController;
  late final TextEditingController _taxController;
  late final TextEditingController _paymentDateController;
  String _paymentStatus = 'pending';
  String _payrollPeriodId = '';

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _isEditing = existing != null;

    _employeeIdController = TextEditingController(
      text: existing?.employeeId ?? '',
    );
    _basicSalaryController = TextEditingController(
      text: existing != null ? existing.basicSalary.toStringAsFixed(2) : '',
    );
    _allowanceController = TextEditingController(
      text: existing != null ? existing.allowance.toStringAsFixed(2) : '',
    );
    _overtimeController = TextEditingController(
      text: existing != null ? existing.overtime.toStringAsFixed(2) : '',
    );
    _deductionController = TextEditingController(
      text: existing != null ? existing.deduction.toStringAsFixed(2) : '',
    );
    _taxController = TextEditingController(
      text: existing != null ? existing.tax.toStringAsFixed(2) : '',
    );
    _paymentDateController = TextEditingController(
      text: existing?.paymentDate != null
          ? _formatDisplayDate(existing!.paymentDate!)
          : '',
    );
    _paymentStatus = existing?.paymentStatus ?? 'pending';
    _payrollPeriodId = existing?.payrollPeriodId ?? '';
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _basicSalaryController.dispose();
    _allowanceController.dispose();
    _overtimeController.dispose();
    _deductionController.dispose();
    _taxController.dispose();
    _paymentDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _paymentDateController.text = _formatDisplayDate(picked);
    }
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  double _parseAmount(String text) {
    return double.tryParse(text.trim()) ?? 0;
  }

  void _recalcNetSalary() {
    // Trigger a rebuild to show the updated net salary
    setState(() {});
  }

  double get _netSalary {
    final basic = _parseAmount(_basicSalaryController.text);
    final allowance = _parseAmount(_allowanceController.text);
    final overtime = _parseAmount(_overtimeController.text);
    final deduction = _parseAmount(_deductionController.text);
    final tax = _parseAmount(_taxController.text);
    return (basic + allowance + overtime) - (deduction + tax);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_payrollPeriodId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payroll period ID is required.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final basicSalary = _parseAmount(_basicSalaryController.text);
    final allowance = _parseAmount(_allowanceController.text);
    final overtime = _parseAmount(_overtimeController.text);
    final deduction = _parseAmount(_deductionController.text);
    final tax = _parseAmount(_taxController.text);
    final netSalary = (basicSalary + allowance + overtime) - (deduction + tax);
    final paymentDate = DateTime.tryParse(_paymentDateController.text);

    final payroll = PayrollRecord(
      id: widget.existing?.id,
      payrollPeriodId: _payrollPeriodId,
      employeeId: _employeeIdController.text.trim(),
      basicSalary: basicSalary,
      allowance: allowance,
      overtime: overtime,
      deduction: deduction,
      tax: tax,
      netSalary: netSalary >= 0 ? netSalary : 0,
      paymentDate: paymentDate,
      paymentStatus: _paymentStatus,
      createdAt: widget.existing?.createdAt,
      updatedAt: null,
    );

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(payrollListProvider.notifier).savePayroll(payroll);

    if (!mounted) return;

    final latest = ref.read(payrollListProvider);
    setState(() => _isSubmitting = false);

    if (latest.errorMessage == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Payroll updated.' : 'Payroll created.'),
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
    final netSalary = _netSalary;
    final state = ref.watch(payrollListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Payroll Entry' : 'New Payroll Entry',
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
              const SizedBox(height: 24),
              _SectionTitle(title: 'Earnings'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _basicSalaryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _inputDecoration('Basic Salary (₹)'),
                onChanged: (_) => _recalcNetSalary(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _allowanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration('Allowance (₹)'),
                      onChanged: (_) => _recalcNetSalary(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _overtimeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration('Overtime (₹)'),
                      onChanged: (_) => _recalcNetSalary(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionTitle(title: 'Deductions'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _deductionController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration('Deduction (₹)'),
                      onChanged: (_) => _recalcNetSalary(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _taxController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: _inputDecoration('Tax (₹)'),
                      onChanged: (_) => _recalcNetSalary(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Net Salary Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Salary',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '₹${netSalary.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionTitle(title: 'Payment'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _paymentDateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: _inputDecoration(
                  'Payment Date',
                  suffixIcon: const Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _paymentStatus,
                decoration: _inputDecoration('Payment Status'),
                items: PaymentStatusOptions.values.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(
                      PaymentStatusOptions.label(s),
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _paymentStatus = v);
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
                    _isEditing ? 'Update Payroll' : 'Create Payroll',
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

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
      suffixIcon: suffixIcon,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

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
