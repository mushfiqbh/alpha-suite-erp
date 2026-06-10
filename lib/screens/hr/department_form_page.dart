import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/hr.dart';
import 'package:erp/providers/hr_providers.dart';

class DepartmentFormPage extends ConsumerStatefulWidget {
  const DepartmentFormPage({super.key, this.existing});

  final DepartmentRecord? existing;

  @override
  ConsumerState<DepartmentFormPage> createState() => _DepartmentFormPageState();
}

class _DepartmentFormPageState extends ConsumerState<DepartmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  late final DepartmentRecord? _initialExisting;
  bool _dependenciesResolved = false;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
  }

  void _initializeFromRoute(DepartmentRecord existing) {
    _nameController = TextEditingController(text: existing.name);
    _descriptionController = TextEditingController(
      text: existing.description ?? '',
    );
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
    if (extra is! DepartmentRecord) {
      return;
    }
    _nameController.dispose();
    _descriptionController.dispose();
    _initialExisting = extra;
    _initializeFromRoute(extra);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isSubmitting = true);

    final controller = ref.read(departmentDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = DepartmentRecord(
      id: _initialExisting?.id,
      name: _nameController.text.trim(),
      description: _trimOrNull(_descriptionController),
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
    );

    try {
      await controller.saveDepartment(draft);
      if (!mounted) {
        return;
      }
      final latestState = ref.read(departmentDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Department saved successfully.'),
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
          content: Text('Could not save department: $e'),
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
                Icons.apartment_rounded,
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
                    isEdit ? 'Edit Department' : 'New Department',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update the department definition.'
                        : 'Define a department to group employees and designations.',
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
                  const _SectionTitle(title: 'Department'),
                  const SizedBox(height: 12),
                  _TextInput(
                    controller: _nameController,
                    label: 'Department Name',
                    hintText: 'Engineering, Finance, Marketing',
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Department name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _TextInput(
                    controller: _descriptionController,
                    label: 'Description',
                    hintText: 'Brief summary of the department responsibilities.',
                    maxLines: 3,
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
                  _isSubmitting ? 'Saving...' : 'Save Department',
                ),
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
    // ignore: unused_element_parameter
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
