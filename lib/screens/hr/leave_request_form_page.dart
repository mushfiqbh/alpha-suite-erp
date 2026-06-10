import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/models/leave.dart';
import 'package:erp/providers/hr_providers.dart';
import 'package:erp/providers/leave_providers.dart';

class LeaveRequestFormPage extends ConsumerStatefulWidget {
  const LeaveRequestFormPage({super.key, this.existing});

  final LeaveRequestRecord? existing;

  @override
  ConsumerState<LeaveRequestFormPage> createState() =>
      _LeaveRequestFormPageState();
}

class _LeaveRequestFormPageState extends ConsumerState<LeaveRequestFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _dependenciesResolved = false;
  LeaveRequestRecord? _initialExisting;

  String? _employeeId;
  String? _leaveTypeId;
  DateTime? _fromDate;
  DateTime? _toDate;
  String _status = LeaveApprovalStatusOptions.defaultValue;

  late final TextEditingController _totalDaysController;
  late final TextEditingController _reasonController;

  @override
  void initState() {
    super.initState();
    _initialExisting = widget.existing;
    final existing = _initialExisting;
    _employeeId = existing?.employeeId;
    _leaveTypeId = existing?.leaveTypeId;
    _fromDate = existing?.fromDate;
    _toDate = existing?.toDate;
    _status = (existing?.approvalStatus ?? '').isEmpty
        ? LeaveApprovalStatusOptions.defaultValue
        : existing!.approvalStatus;
    _totalDaysController = TextEditingController(
      text: existing == null ? '1' : existing.totalDays.toStringAsFixed(1),
    );
    _reasonController = TextEditingController(text: existing?.reason ?? '');
  }

  void _initializeFromRoute(LeaveRequestRecord existing) {
    _employeeId = existing.employeeId;
    _leaveTypeId = existing.leaveTypeId;
    _fromDate = existing.fromDate;
    _toDate = existing.toDate;
    _status = existing.approvalStatus.isEmpty
        ? LeaveApprovalStatusOptions.defaultValue
        : existing.approvalStatus;
    _totalDaysController.text = existing.totalDays.toStringAsFixed(1);
    _reasonController.text = existing.reason ?? '';
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
    if (extra is! LeaveRequestRecord) {
      return;
    }
    _initialExisting = extra;
    _initializeFromRoute(extra);
  }

  @override
  void dispose() {
    _totalDaysController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_fromDate ?? DateTime.now())
        : (_toDate ?? _fromDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 2),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = picked;
        }
      } else {
        _toDate = picked;
      }
      _recalculateDays();
    });
  }

  void _recalculateDays() {
    if (_fromDate == null || _toDate == null) {
      return;
    }
    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day);
    final diff = to.difference(from).inDays;
    final total = diff < 0 ? 0 : diff + 1;
    _totalDaysController.text = total.toStringAsFixed(0);
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
    if (_leaveTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a leave type.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick both from and to dates.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    if (_toDate!.isBefore(_fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('To-date must be on or after from-date.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final controller = ref.read(leaveRequestDirectoryProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = GoRouter.of(context);

    final draft = LeaveRequestRecord(
      id: _initialExisting?.id,
      employeeId: _employeeId!,
      leaveTypeId: _leaveTypeId!,
      fromDate: _fromDate,
      toDate: _toDate,
      totalDays: double.tryParse(_totalDaysController.text.trim()) ?? 1,
      reason: _reasonController.text.trim().isEmpty
          ? null
          : _reasonController.text.trim(),
      approvalStatus: _status,
      approvedBy: _initialExisting?.approvedBy,
      approvedAt: _initialExisting?.approvedAt,
      createdAt: _initialExisting?.createdAt,
      updatedAt: _initialExisting?.updatedAt,
    );

    try {
      await controller.saveLeaveRequest(draft);
      if (!mounted) {
        return;
      }
      final latestState = ref.read(leaveRequestDirectoryProvider);
      if (latestState.errorMessage == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Leave request saved successfully.'),
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
          content: Text('Could not save leave request: $e'),
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
    final hrState = ref.watch(employeeDirectoryProvider);
    final employees = hrState.employees;
    final typesState = ref.watch(leaveTypeDirectoryProvider);
    final leaveTypes = typesState.types;
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
                Icons.event_busy_rounded,
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
                    isEdit ? 'Edit Leave Request' : 'New Leave Request',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    isEdit
                        ? 'Update the leave request details and status.'
                        : 'File a leave request on behalf of an employee.',
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
                  const _SectionTitle(title: 'Requester'),
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
                    onChanged: (value) =>
                        setState(() => _employeeId = value),
                    validator: (value) {
                      if (value == null) {
                        return 'Employee is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Leave Details'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _leaveTypeId,
                    isExpanded: true,
                    decoration: _decoration('Leave Type'),
                    items: leaveTypes
                        .map(
                          (t) => DropdownMenuItem<String>(
                            value: t.id,
                            child: Text(
                              '${t.name}  •  ${t.daysPerYear} days  •  ${t.paidLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _leaveTypeId = value),
                    validator: (value) {
                      if (value == null) {
                        return 'Leave type is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isFrom: true),
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: _decoration('From Date'),
                            child: Text(
                              _formatDate(_fromDate),
                              style: TextStyle(
                                color: _fromDate == null
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDate(isFrom: false),
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: _decoration('To Date'),
                            child: Text(
                              _formatDate(_toDate),
                              style: TextStyle(
                                color: _toDate == null
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _totalDaysController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: _decoration('Total Days'),
                    validator: (value) {
                      final v = double.tryParse((value ?? '').trim()) ?? -1;
                      if (v <= 0) {
                        return 'Must be greater than zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      hintText: 'Family event, medical, etc.',
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
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(title: 'Approval'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _decoration('Approval Status'),
                    items: LeaveApprovalStatusOptions.values
                        .map(
                          (v) => DropdownMenuItem<String>(
                            value: v,
                            child: Text(LeaveApprovalStatusOptions.label(v)),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) {
                        return;
                      }
                      setState(() => _status = v);
                    },
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
                  _isSubmitting ? 'Saving...' : 'Save Leave Request',
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
