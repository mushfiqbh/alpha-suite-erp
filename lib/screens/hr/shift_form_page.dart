import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/shift.dart';
import 'package:erp/providers/hr_providers.dart';

class ShiftFormPage extends ConsumerStatefulWidget {
  const ShiftFormPage({super.key, this.existing});

  final ShiftRecord? existing;

  @override
  ConsumerState<ShiftFormPage> createState() => _ShiftFormPageState();
}

class _ShiftFormPageState extends ConsumerState<ShiftFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dependenciesResolved = false;
  ShiftRecord? _initialExisting;

  late final TextEditingController _nameController;
  late final TextEditingController _graceController;
  late final TextEditingController _workingHoursController;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _nameController = TextEditingController(text: existing?.shiftName ?? '');
    _graceController = TextEditingController(
      text: existing == null ? '10' : existing.graceMinutes.toString(),
    );
    _workingHoursController = TextEditingController(
      text: existing == null
          ? '8'
          : existing.workingHours.toStringAsFixed(2),
    );
    _startTime = existing?.startTime?.timeOfDay;
    _endTime = existing?.endTime?.timeOfDay;
  }

  void _initializeFromRoute(ShiftRecord existing) {
    _nameController.text = existing.shiftName;
    _graceController.text = existing.graceMinutes.toString();
    _workingHoursController.text = existing.workingHours.toStringAsFixed(2);
    _startTime = existing.startTime?.timeOfDay;
    _endTime = existing.endTime?.timeOfDay;
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
    if (extra is! ShiftRecord) {
      return;
    }
    _initialExisting = extra;
    _initializeFromRoute(extra);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _graceController.dispose();
    _workingHoursController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_endTime ?? const TimeOfDay(hour: 18, minute: 0));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose both start and end times.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final controller = ref.read(shiftDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = ShiftRecord(
      id: _initialExisting?.id,
      shiftName: _nameController.text.trim(),
      startTime: ShiftTime(_startTime!.hour, _startTime!.minute),
      endTime: ShiftTime(_endTime!.hour, _endTime!.minute),
      graceMinutes: int.tryParse(_graceController.text.trim()) ?? 0,
      workingHours: double.tryParse(_workingHoursController.text.trim()) ?? 0,
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
    );

    try {
      await controller.saveShift(draft);
      if (!mounted) {
        return;
      }
      final latestState = ref.read(shiftDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Shift saved successfully.'),
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
          content: Text('Could not save shift: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return 'Select time';
    }
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
                Icons.schedule_rounded,
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
                    isEdit ? 'Edit Shift' : 'New Shift',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update shift timings and grace period.'
                        : 'Define a reusable shift template for employee rosters.',
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
                  const _SectionTitle(title: 'Shift Definition'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Shift Name',
                      hintText: 'General, Morning, Night',
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
                        borderSide: const BorderSide(
                          color: Color(0xFF4F46E5),
                          width: 1.5,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Shift name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeInput(
                          label: 'Start Time',
                          value: _startTime,
                          formatted: _formatTime(_startTime),
                          onTap: () => _pickTime(isStart: true),
                          onClear: _startTime == null
                              ? null
                              : () => setState(() => _startTime = null),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeInput(
                          label: 'End Time',
                          value: _endTime,
                          formatted: _formatTime(_endTime),
                          onTap: () => _pickTime(isStart: false),
                          onClear: _endTime == null
                              ? null
                              : () => setState(() => _endTime = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _graceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Grace Minutes',
                            hintText: '10',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF4F46E5),
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final v = int.tryParse((value ?? '').trim());
                            if (v == null || v < 0) {
                              return 'Must be a non-negative integer';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _workingHoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Working Hours',
                            hintText: '8.0',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF4F46E5),
                                width: 1.5,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final v =
                                double.tryParse((value ?? '').trim()) ?? -1;
                            if (v <= 0) {
                              return 'Must be greater than zero';
                            }
                            return null;
                          },
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
                label: Text(_isSubmitting ? 'Saving...' : 'Save Shift'),
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

class _TimeInput extends StatelessWidget {
  const _TimeInput({
    required this.label,
    required this.value,
    required this.formatted,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final TimeOfDay? value;
  final String formatted;
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
              ? const Icon(Icons.access_time_rounded, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(
          formatted,
          style: TextStyle(
            color: value == null
                ? const Color(0xFF94A3B8)
                : const Color(0xFF0F172A),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
