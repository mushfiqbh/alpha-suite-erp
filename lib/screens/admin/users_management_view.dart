import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:erp/providers/auth_providers.dart';

class ProfilesState {
  final List<Map<String, dynamic>> profiles;
  final bool isLoading;
  final String? errorMessage;
  final String searchQuery;
  final UserRole? roleFilter;
  final bool? statusFilter;

  ProfilesState({
    required this.profiles,
    required this.isLoading,
    this.errorMessage,
    required this.searchQuery,
    this.roleFilter,
    this.statusFilter,
  });

  factory ProfilesState.initial() {
    return ProfilesState(
      profiles: [],
      isLoading: false,
      searchQuery: '',
      roleFilter: null,
      statusFilter: null,
    );
  }

  ProfilesState copyWith({
    List<Map<String, dynamic>>? profiles,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
    UserRole? roleFilter,
    bool clearRoleFilter = false,
    bool? statusFilter,
    bool clearStatusFilter = false,
  }) {
    return ProfilesState(
      profiles: profiles ?? this.profiles,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
      roleFilter: clearRoleFilter ? null : (roleFilter ?? this.roleFilter),
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
    );
  }
}

class ProfilesController extends StateNotifier<ProfilesState> {
  ProfilesController() : super(ProfilesState.initial()) {
    fetchProfiles();
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> fetchProfiles() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      state = state.copyWith(
        isLoading: false,
        profiles: List<Map<String, dynamic>>.from(data),
      );
    } catch (error) {
      String errorMessage = error.toString();
      if (error is AuthRetryableFetchException ||
          errorMessage.contains('Failed to fetch') ||
          errorMessage.contains('ClientException')) {
        errorMessage =
            'Connection error: Unable to reach the server. Please check your internet connection.';
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setRoleFilter(UserRole? role) {
    if (role == null) {
      state = state.copyWith(clearRoleFilter: true);
    } else {
      state = state.copyWith(roleFilter: role);
    }
  }

  void setStatusFilter(bool? status) {
    if (status == null) {
      state = state.copyWith(clearStatusFilter: true);
    } else {
      state = state.copyWith(statusFilter: status);
    }
  }

  Future<void> updateProfile({
    required String id,
    required String fullName,
    required String phone,
    required UserRole role,
    required bool isActive,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _client
          .from('profiles')
          .update({
            'full_name': fullName,
            'phone': phone,
            'role': role.name,
            'is_active': isActive,
          })
          .eq('id', id);

      await fetchProfiles();
    } catch (error) {
      String errorMessage = error.toString();
      if (error is AuthRetryableFetchException ||
          errorMessage.contains('Failed to fetch') ||
          errorMessage.contains('ClientException')) {
        errorMessage =
            'Connection error: Unable to save changes. Check connection.';
      }
      state = state.copyWith(isLoading: false, errorMessage: errorMessage);
      rethrow;
    }
  }
}

final profilesProvider =
    StateNotifierProvider<ProfilesController, ProfilesState>((ref) {
      return ProfilesController();
    });

class UsersManagementView extends ConsumerWidget {
  const UsersManagementView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profilesProvider);

    final filteredProfiles = state.profiles.where((profile) {
      final name = (profile['full_name'] ?? '').toString().toLowerCase();
      final email = (profile['email'] ?? '').toString().toLowerCase();
      final matchesSearch =
          name.contains(state.searchQuery.toLowerCase()) ||
          email.contains(state.searchQuery.toLowerCase());

      final rawRole = (profile['role'] ?? 'viewer').toString().toLowerCase();
      final matchesRole =
          state.roleFilter == null || rawRole == state.roleFilter!.name;

      final isActive = profile['is_active'] as bool? ?? true;
      final matchesStatus =
          state.statusFilter == null || isActive == state.statusFilter;

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Filters and Search Bar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => ref
                          .read(profilesProvider.notifier)
                          .setSearchQuery(val),
                      decoration: InputDecoration(
                        hintText: 'Search user directories by name or email...',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Role Filter
                  DropdownButton<UserRole?>(
                    value: state.roleFilter,
                    hint: const Text('Filter by Role'),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<UserRole?>(
                        value: null,
                        child: Text('All Roles'),
                      ),
                      ...UserRole.values.map(
                        (role) => DropdownMenuItem<UserRole?>(
                          value: role,
                          child: Text(role.label),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        ref.read(profilesProvider.notifier).setRoleFilter(val),
                  ),
                ],
              ),
            ),
          ),

          // Main User Grid
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade600,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref
                              .read(profilesProvider.notifier)
                              .fetchProfiles(),
                          child: const Text('Retry Connection'),
                        ),
                      ],
                    ),
                  )
                : filteredProfiles.isEmpty
                ? Center(
                    child: Text(
                      'No matching users found in the system.',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredProfiles.length,
                    itemBuilder: (context, index) {
                      final profile = filteredProfiles[index];
                      return _UserCard(
                        profile: profile,
                        onEdit: () => _showEditDialog(context, ref, profile),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> profile,
  ) {
    final nameController = TextEditingController(
      text: profile['full_name'] ?? '',
    );
    final phoneController = TextEditingController(text: profile['phone'] ?? '');
    final rawRole = (profile['role'] ?? 'viewer').toString().toLowerCase();
    UserRole selectedRole = UserRole.values.firstWhere(
      (r) => r.name == rawRole,
      orElse: () => UserRole.viewer,
    );
    bool isActive = profile['is_active'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Configure Access Settings',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDENTITY: ${profile['email'] ?? 'No Email Registered'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Security Role',
                    ),
                    items: UserRole.values
                        .map(
                          (role) => DropdownMenuItem<UserRole>(
                            value: role,
                            child: Text(role.label),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => selectedRole = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  SwitchListTile(
                    title: const Text('Account Active'),
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    onChanged: (val) {
                      setState(() => isActive = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    // Show a quick loader overlay
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Updating user security policy...'),
                        duration: Duration(seconds: 1),
                      ),
                    );

                    try {
                      await ref
                          .read(profilesProvider.notifier)
                          .updateProfile(
                            id: profile['id'],
                            fullName: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            role: selectedRole,
                            isActive: isActive,
                          );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User policy updated successfully.'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Save Policies'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  const _UserCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final rawRole = (profile['role'] ?? 'viewer').toString().toLowerCase();
    final role = UserRole.values.firstWhere(
      (r) => r.name == rawRole,
      orElse: () => UserRole.viewer,
    );
    final fullName = profile['full_name'] ?? 'User';
    final email = profile['email'] ?? 'No email';
    final phone = profile['phone'] ?? '—';
    final initials = fullName.isNotEmpty
        ? fullName.substring(0, 1).toUpperCase()
        : 'U';

    Color roleBgColor = Colors.grey.shade100;
    Color roleTextColor = Colors.grey.shade700;

    switch (role) {
      case UserRole.admin:
        roleBgColor = Colors.purple.shade50;
        roleTextColor = Colors.purple.shade700;
        break;
      case UserRole.operations:
        roleBgColor = Colors.teal.shade50;
        roleTextColor = Colors.teal.shade700;
        break;
      case UserRole.sales:
        roleBgColor = Colors.blue.shade50;
        roleTextColor = Colors.blue.shade700;
        break;
      case UserRole.hr:
        roleBgColor = Colors.indigo.shade50;
        roleTextColor = Colors.indigo.shade700;
        break;
      case UserRole.viewer:
        roleBgColor = Colors.grey.shade100;
        roleTextColor = Colors.grey.shade700;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: Colors.indigo.shade50,
          child: Text(
            initials,
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              fullName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: roleBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                role.label,
                style: TextStyle(
                  color: roleTextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                email,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(
                phone,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: Colors.grey.shade600,
              onPressed: onEdit,
              tooltip: 'Configure policies',
            ),
          ],
        ),
      ),
    );
  }
}
