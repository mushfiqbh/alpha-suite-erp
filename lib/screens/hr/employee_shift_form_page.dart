import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/shift.dart';
import 'package:erp/providers/hr_providers.dart';

class EmployeeShiftFormPage extends ConsumerStatefulWidget {
  const EmployeeShiftFormPage({super.key, this.existing});

  final EmployeeShiftRecord? existing;

  @override
  ConsumerState<EmployeeShiftFormPage> createState() =>
      _EmployeeShiftFormPageState();
}

class _EmployeeShiftFormPageState
    extends ConsumerState<EmployeeShiftFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dependenciesResolved = false;
  EmployeeShiftRecord? _initialExisting;

  String? _employeeId;
  String? _shiftId;
  DateTime? _effectiveFrom;
  DateTime? _effectiveTo;

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _employeeId = existing?.employeeId;
    _shiftId = existing?.shiftId;
    _effectiveFrom = existing?.effectiveFrom;
    _effectiveTo = existing?.effectiveTo;
  }

  void _initializeFromRoute(EmployeeShiftRecord existing) {
    _employeeId = existing.employeeId;
    _shiftId = existing.shiftId;
    _effectiveFrom = existing.effectiveFrom;
    _effectiveTo = existing.effectiveTo;
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
    if (extra is! EmployeeShiftRecord) {
      return;
    }
    _initialExisting = extra;
    _initializeFromRoute(extra);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_effectiveFrom ?? DateTime.now())
        : (_effectiveTo ?? _effectiveFrom ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _effectiveFrom = picked;
      } else {
        _effectiveTo = picked;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_shiftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a shift.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_effectiveFrom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick an effective-from date.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_effectiveTo != null && _effectiveTo!.isBefore(_effectiveFrom!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Effective-to date must be on or after effective-from date.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final controller = ref.read(shiftDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = EmployeeShiftRecord(
      id: _initialExisting?.id,
      employeeId: _employeeId!,
      shiftId: _shiftId!,
      effectiveFrom: _effectiveFrom,
      effectiveTo: _effectiveTo,
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
    );

    try {
      await controller.saveAssignment(draft);
      if (!mounted) {
        return;
      }
      final latestState = ref.read(shiftDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Assignment saved successfully.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          navigator.go(AppRoutes.hr);
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
          content: Text('Could not save assignment: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shiftDirectoryProvider);
    final employees = state.employees;
    final shifts = state.shifts;
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
          tooltip: 'Back to HR',
          onPressed: () {
            if (GoRouter.of(context).canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.hr);
            }
          },
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.assignment_ind_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isEdit ? 'Edit Shift Assignment' : 'New Shift Assignment',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update the employee shift schedule.'
                        : 'Assign a shift to an employee for a specific period.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: 'Assignment'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _employeeId,
                    isExpanded: true,
                    decoration: _decoration('Employee'),
                    items: employees
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.id,
                            child: Text(
                              '${e.fullName}  •  ${e.employeeCode}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _employeeId = value),
                    validator: (value) {
                      if (value == null) {
                        return 'Employee is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _shiftId,
                    isExpanded: true,
                    decoration: _decoration('Shift'),
                    items: shifts
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(
                              '${s.shiftName}  •  ${s.displayWindow}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _shiftId = value),
                    validator: (value) {
                      if (value == null) {
                        return 'Shift is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DateInput(
                          label: 'Effective From',
                          value: _effectiveFrom,
                          onTap: () => _pickDate(isFrom: true),
                          onClear: _effectiveFrom == null
                              ? null
                              : () => setState(() => _effectiveFrom = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateInput(
                          label: 'Effective To (optional)',
                          value: _effectiveTo,
                          onTap: () => _pickDate(isFrom: false),
                          onClear: _effectiveTo == null
                              ? null
                              : () => setState(() => _effectiveTo = null),
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
                          context.go(AppRoutes.hr);
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
                label: Text(
                  _isSubmitting ? 'Saving...' : 'Save Assignment',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: const Color(0xFF0F172A),
      ),
    );
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
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
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_rounded, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          value == null
              ? 'Select date'
              : '${value!.year.toString().padLeft(4, '0')}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: value == null
                ? const Color(0xFF94A3B8)
                : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }
}
