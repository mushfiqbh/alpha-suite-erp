import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/holiday.dart';
import 'package:erp/providers/holiday_providers.dart';

class HolidayFormPage extends ConsumerStatefulWidget {
  const HolidayFormPage({super.key, this.existing});

  final HolidayRecord? existing;

  @override
  ConsumerState<HolidayFormPage> createState() => _HolidayFormPageState();
}

class _HolidayFormPageState extends ConsumerState<HolidayFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dependenciesResolved = false;
  HolidayRecord? _initialExisting;

  late final TextEditingController _nameController;
  DateTime? _holidayDate;
  String _type = HolidayTypeOptions.values.first;

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _holidayDate = existing?.date;
    _type = (existing?.type ?? '').isEmpty
        ? HolidayTypeOptions.values.first
        : existing!.type;
  }

  void _initializeFromRoute(HolidayRecord existing) {
    _nameController.text = existing.name;
    _holidayDate = existing.date;
    _type = existing.type.isEmpty
        ? HolidayTypeOptions.values.first
        : existing.type;
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
    if (extra is! HolidayRecord) {
      return;
    }
    _initialExisting = extra;
    _initializeFromRoute(extra);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _holidayDate ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) {
      return;
    }
    setState(() => _holidayDate = picked);
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_holidayDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a holiday date.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final controller = ref.read(holidayDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = HolidayRecord(
      id: _initialExisting?.id,
      name: _nameController.text.trim(),
      date: _holidayDate,
      type: _type,
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
    );

    try {
      await controller.saveHoliday(draft);
      if (!mounted) {
        return;
      }
      final latestState = ref.read(holidayDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Holiday saved successfully.'),
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
          content: Text('Could not save holiday: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
                Icons.celebration_rounded,
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
                    isEdit ? 'Edit Holiday' : 'New Holiday',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update the holiday entry.'
                        : 'Add a holiday to the company calendar.',
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
                  const _SectionTitle(title: 'Holiday Details'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Holiday Name',
                      hintText: 'New Year, Diwali, Independence Day',
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
                        return 'Holiday name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date',
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
                              suffixIcon: _holidayDate == null
                                  ? const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                    )
                                  : IconButton(
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () =>
                                          setState(() => _holidayDate = null),
                                    ),
                            ),
                            child: Text(
                              _formatDate(_holidayDate),
                              style: TextStyle(
                                color: _holidayDate == null
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _type,
                          decoration: InputDecoration(
                            labelText: 'Type',
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
                          items: HolidayTypeOptions.values
                              .map(
                                (v) => DropdownMenuItem<String>(
                                  value: v,
                                  child: Text(HolidayTypeOptions.label(v)),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) {
                              return;
                            }
                            setState(() => _type = v);
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
                label: Text(_isSubmitting ? 'Saving...' : 'Save Holiday'),
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
