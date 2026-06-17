import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/providers/auth_providers.dart';

class AccountView extends ConsumerWidget {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;
    final userName = currentUser?.userMetadata?['full_name'] as String?;
    final email = currentUser?.email ?? 'ইমেইল নেই';
    final role = authState.role;
    final roleLabel = role?.label ?? 'দর্শক';
    final avatarUrl = authState.avatarUrl;
    final initials = email.isNotEmpty ? email[0].toUpperCase() : 'A';

    void showEditProfileModal(BuildContext context, WidgetRef ref) {
      final nameController = TextEditingController(text: userName ?? '');
      final phoneController = TextEditingController(
        text:
            currentUser?.userMetadata?['phone'] as String? ??
            currentUser?.phone ??
            '',
      );
      final formKey = GlobalKey<FormState>();
      ValueNotifier<Uint8List?> avatarBytes = ValueNotifier(null);
      ValueNotifier<bool> uploading = ValueNotifier(false);

      showDialog(
        context: context,
        builder: (modalContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'প্রোফাইল সম্পাদনা',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar picker
                    Center(
                      child: Stack(
                        children: [
                          ValueListenableBuilder<Uint8List?>(
                            valueListenable: avatarBytes,
                            builder: (_, bytes, __) => CircleAvatar(
                              radius: 48,
                              backgroundColor: const Color(0xFFEEF2FF),
                              backgroundImage: bytes != null
                                  ? MemoryImage(bytes)
                                  : (avatarUrl != null
                                        ? NetworkImage(avatarUrl)
                                        : null),
                              child: bytes == null && avatarUrl == null
                                  ? Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Color(0xFF4F46E5),
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 512,
                                  maxHeight: 512,
                                );
                                if (picked == null) return;
                                final bytes = await picked.readAsBytes();
                                avatarBytes.value = bytes;
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4F46E5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Email (read-only)
                    TextFormField(
                      initialValue: email,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'ইমেইল',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Full Name
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'পূর্ণ নাম',
                        hintText: 'আপনার পূর্ণ নাম লিখুন',
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'নাম আবশ্যক';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Phone Number
                    TextFormField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'ফোন নম্বর',
                        hintText: 'আপনার ফোন নম্বর লিখুন',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF4F46E5),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(modalContext).pop(),
              child: Text(
                'বাতিল',
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: uploading,
              builder: (_, isUploading, __) => FilledButton(
                onPressed: isUploading
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;

                        uploading.value = true;

                        // Upload avatar first if changed
                        if (avatarBytes.value != null) {
                          await ref
                              .read(authProvider.notifier)
                              .uploadAvatar(avatarBytes.value!);
                        }

                        // Update name & phone
                        await ref
                            .read(authProvider.notifier)
                            .updateProfile(
                              fullName: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                            );

                        uploading.value = false;

                        if (modalContext.mounted) {
                          Navigator.of(modalContext).pop();
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                ),
                child: isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('সংরক্ষণ'),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 780;

                    final profileCard = Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: const Color(0xFF1D4ED8),
                                backgroundImage: avatarUrl != null
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: avatarUrl == null
                                    ? Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName ?? 'ব্যবহারকারী',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'সক্রিয়',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0369A1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.verified_user_outlined,
                            title: 'ভূমিকা',
                            value: roleLabel,
                          ),
                          const SizedBox(height: 24),
                          _ActionCard(
                            icon: Icons.edit_outlined,
                            iconColor: const Color(0xFFD97706),
                            iconBgColor: const Color(0xFFFEF3C7),
                            title: 'প্রোফাইল সম্পাদনা',
                            subtitle: 'আপনার পূর্ণ নাম আপডেট করুন',
                            onTap: () => showEditProfileModal(context, ref),
                          ),
                          if (role == UserRole.operations ||
                              role == UserRole.sales ||
                              role == UserRole.hr) ...[
                            const SizedBox(height: 12),
                            _ActionCard(
                              icon: Icons.calendar_today_rounded,
                              iconColor: const Color(0xFF4F46E5),
                              iconBgColor: const Color(0xFFEEF2FF),
                              title: 'উপস্থিতি নিন',
                              subtitle: 'আপনার উপস্থিতি রেকর্ড বা আপডেট করুন',
                              onTap: () =>
                                  context.go(AppRoutes.hrAttendanceMark),
                            ),
                          ],
                          if (role == UserRole.admin) ...[
                            const SizedBox(height: 12),
                            _ActionCard(
                              icon: Icons.verified_user_outlined,
                              iconColor: const Color(0xFF7C3AED),
                              iconBgColor: const Color(0xFFEDE9FE),
                              title: 'অ্যাক্সেস অনুরোধ',
                              subtitle:
                                  'ভূমিকা অনুরোধ পর্যালোচনা ও ব্যবস্থাপনা',
                              onTap: () => context.go(AppRoutes.accessRequests),
                            ),
                            const SizedBox(height: 12),
                            _ActionCard(
                              icon: Icons.people_outlined,
                              iconColor: const Color(0xFF059669),
                              iconBgColor: const Color(0xFFD1FAE5),
                              title: 'ব্যবহারকারী ব্যবস্থাপনা',
                              subtitle:
                                  'সিস্টেম ব্যবহারকারী দেখুন ও ব্যবস্থাপনা করুন',
                              onTap: () => context.go(AppRoutes.users),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _ActionCard(
                            icon: Icons.logout_rounded,
                            iconColor: const Color(0xFFDC2626),
                            iconBgColor: const Color(0xFFFEE2E2),
                            title: 'সাইন আউট',
                            subtitle: 'আপনার অ্যাকাউন্ট থেকে সাইন আউট করুন',
                            onTap: authState.isLoading
                                ? null
                                : () async {
                                    await ref
                                        .read(authProvider.notifier)
                                        .logout();
                                    if (context.mounted) {
                                      context.go(AppRoutes.login);
                                    }
                                  },
                          ),
                        ],
                      ),
                    );

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(flex: 3, child: profileCard)],
                      );
                    }

                    return Column(children: [profileCard]);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF334155), size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
