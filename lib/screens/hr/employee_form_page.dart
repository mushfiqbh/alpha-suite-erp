import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/hr.dart';
import 'package:erp/providers/hr_providers.dart';

class EmployeeFormPage extends ConsumerStatefulWidget {
  const EmployeeFormPage({super.key, this.existing});

  final EmployeeRecord? existing;

  @override
  ConsumerState<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends ConsumerState<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dependenciesResolved = false;
  EmployeeRecord? _initialExisting;

  late final TextEditingController _codeController;
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _salaryController;

  late final TextEditingController _departmentController;
  late final TextEditingController _designationController;
  String? _linkedUserId;
  String? _gender;
  String? _employmentType;
  String? _status;
  DateTime? _dob;
  DateTime? _joiningDate;

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _codeController = TextEditingController(text: existing?.employeeCode ?? '');
    _firstNameController = TextEditingController(
      text: existing?.firstName ?? '',
    );
    _lastNameController = TextEditingController(text: existing?.lastName ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _salaryController = TextEditingController(
      text: existing == null ? '' : existing.basicSalary.toStringAsFixed(0),
    );
    _departmentController = TextEditingController(
      text: existing?.department ?? '',
    );
    _designationController = TextEditingController(
      text: existing?.designation ?? '',
    );
    _linkedUserId = existing?.linkedUserId;
    _gender = existing?.gender;
    _employmentType = existing?.employmentType ?? 'permanent';
    _status = existing?.status ?? 'active';
    _dob = existing?.dob;
    _joiningDate = existing?.joiningDate;
  }

  void _initializeFromRoute(EmployeeRecord existing) {
    _codeController.text = existing.employeeCode;
    _firstNameController.text = existing.firstName;
    _lastNameController.text = existing.lastName ?? '';
    _emailController.text = existing.email ?? '';
    _phoneController.text = existing.phone ?? '';
    _salaryController.text = existing.basicSalary.toStringAsFixed(0);
    _departmentController.text = existing.department ?? '';
    _designationController.text = existing.designation ?? '';
    _linkedUserId = existing.linkedUserId;
    _gender = existing.gender;
    _employmentType = existing.employmentType;
    _status = existing.status;
    _dob = existing.dob;
    _joiningDate = existing.joiningDate;
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
    if (extra is! EmployeeRecord) {
      return;
    }
    _initialExisting = extra;
    _initializeFromRoute(extra);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _departmentController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isDob}) async {
    final initial = isDob ? _dob : _joiningDate;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? (isDob ? DateTime(now.year - 25) : now),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isDob) {
        _dob = picked;
      } else {
        _joiningDate = picked;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSubmitting = true);

    final controller = ref.read(employeeDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final salary = double.tryParse(_salaryController.text.trim()) ?? 0.0;

    final draft = EmployeeRecord(
      id: _initialExisting?.id,
      employeeCode: _trimOrNull(_codeController) ?? '',
      firstName: _firstNameController.text.trim(),
      lastName: _trimOrNull(_lastNameController),
      email: _trimOrNull(_emailController),
      phone: _trimOrNull(_phoneController),
      gender: _gender,
      dob: _dob,
      joiningDate: _joiningDate,
      department: _trimOrNull(_departmentController),
      designation: _trimOrNull(_designationController),
      linkedUserId: _linkedUserId,
      employmentType: _employmentType ?? 'permanent',
      basicSalary: salary,
      status: _status ?? 'active',
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
    );

    try {
      await controller.saveEmployee(draft);
      if (!mounted) {
        return;
      }
      final latestState = ref.read(employeeDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Employee saved successfully.'),
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
          content: Text('Could not save employee: $e'),
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
    final profilesAsync = ref.watch(allProfilesProvider);

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
                Icons.person_rounded,
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
                    isEdit ? 'Edit Employee' : 'New Employee',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update employee profile and assignments.'
                        : 'Create a new employee record and assign to a department.',
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
          constraints: const BoxConstraints(maxWidth: 880),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: 'Identity'),
                  const SizedBox(height: 12),
                  _TextInput(
                    controller: _codeController,
                    label: isEdit
                        ? 'Employee Code'
                        : 'Employee Code (auto-generated if blank)',
                    hintText: 'EMP-0001',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TextInput(
                          controller: _firstNameController,
                          label: 'First Name',
                          hintText: 'Aarav',
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'First name is required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TextInput(
                          controller: _lastNameController,
                          label: 'Last Name',
                          hintText: 'Sharma',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TextInput(
                          controller: _emailController,
                          label: 'Email',
                          hintText: 'name@example.com',
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TextInput(
                          controller: _phoneController,
                          label: 'Phone',
                          hintText: '+91 90000 00000',
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DropdownInput<String>(
                          label: 'Gender',
                          value: _gender,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('Unspecified'),
                            ),
                            ...GenderOptions.values
                                .where((v) => v != null)
                                .map(
                                  (v) => DropdownMenuItem<String>(
                                    value: v,
                                    child: Text(GenderOptions.label(v)),
                                  ),
                                ),
                          ],
                          onChanged: (value) => setState(() => _gender = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateInput(
                          label: 'Date of Birth',
                          value: _dob,
                          onTap: () => _pickDate(isDob: true),
                          onClear: _dob == null
                              ? null
                              : () => setState(() => _dob = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateInput(
                          label: 'Joining Date',
                          value: _joiningDate,
                          onTap: () => _pickDate(isDob: false),
                          onClear: _joiningDate == null
                              ? null
                              : () => setState(() => _joiningDate = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle(title: 'Assignment'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TextInput(
                          controller: _departmentController,
                          label: 'Department',
                          hintText: 'e.g. Engineering, Marketing',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TextInput(
                          controller: _designationController,
                          label: 'Designation',
                          hintText: 'e.g. Senior Engineer, Manager',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  profilesAsync.when(
                    data: (profiles) => _DropdownInput<String>(
                      label: 'Linked User',
                      value: _linkedUserId,
                      items: profiles
                          .where((p) => p['id'] != null && p['role'] != 'admin')
                          .map<DropdownMenuItem<String>>(
                            (p) => DropdownMenuItem<String>(
                              value: p['id'].toString(),
                              child: Text(
                                '${p['full_name'] ?? 'Unknown'}  •  ${p['email'] ?? ''}  (${p['role'] ?? 'no role'})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _linkedUserId = value),
                    ),
                    error: (_, __) => const Text('Failed to load users'),
                    loading: () => _DropdownInput<String>(
                      label: 'Linked User',
                      value: null,
                      items: [],
                      onChanged: (_) {},
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle(title: 'Employment'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DropdownInput<String>(
                          label: 'Employment Type',
                          value: _employmentType,
                          items: EmploymentTypeOptions.values
                              .map(
                                (v) => DropdownMenuItem<String>(
                                  value: v,
                                  child: Text(EmploymentTypeOptions.label(v)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _employmentType = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TextInput(
                          controller: _salaryController,
                          label: 'Basic Salary',
                          hintText: '0',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _DropdownInput<String>(
                    label: 'Status',
                    value: _status,
                    items: EmployeeStatusOptions.values
                        .map(
                          (v) => DropdownMenuItem<String>(
                            value: v,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: EmployeeStatusOptions.color(v),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(EmployeeStatusOptions.label(v)),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _status = value),
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
                label: Text(_isSubmitting ? 'Saving...' : 'Save Employee'),
              ),
            ],
          ),
        ),
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

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType,
    // ignore: unused_element_parameter
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

class _DropdownInput<T> extends StatelessWidget {
  const _DropdownInput({
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
      ),
      items: items,
      onChanged: onChanged,
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
