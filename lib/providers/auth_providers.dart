import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/core/supabase_config.dart';
import 'package:erp/services/auth_service.dart';

enum UserRole { admin, operations, sales, hr, viewer }

extension UserRoleLabel on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.operations:
        return 'Operations';
      case UserRole.sales:
        return 'Sales';
      case UserRole.hr:
        return 'HR';
      case UserRole.viewer:
        return 'Viewer';
    }
  }
}

class AuthSession {
  const AuthSession({required this.userId, required this.role, this.avatarUrl});

  final String userId;
  final UserRole role;
  final String? avatarUrl;
}

class AuthState {
  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    required this.userId,
    required this.role,
    required this.errorMessage,
    this.avatarUrl,
  });

  factory AuthState.initial() {
    return const AuthState(
      isLoading: false,
      isAuthenticated: false,
      userId: '',
      role: null,
      errorMessage: null,
    );
  }

  final bool isLoading;
  final bool isAuthenticated;
  final String userId;
  final UserRole? role;
  final String? errorMessage;
  final String? avatarUrl;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? userId,
    UserRole? role,
    bool clearRole = false,
    String? errorMessage,
    bool clearError = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      role: clearRole ? null : (role ?? this.role),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final appBootstrapProvider = FutureProvider<void>((ref) async {
  if (!SupabaseConfig.isConfigured) {
    return;
  }

  // lib/main.dart already calls Supabase.initialize at startup. Calling it
  // again here throws a "already initialized" exception, which we silently
  // ignore — but that swallow also hides real network/config errors. Skip
  // the redundant init and only run it when the client isn't ready yet.
  if (Supabase.instance.isInitialized) {
    return;
  }

  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    ).timeout(const Duration(seconds: 3));
  } catch (error) {
    // Log instead of silently swallowing so config / network issues surface
    // in `flutter run` logs during development.
    // ignore: avoid_print
    print('[appBootstrapProvider] Supabase.initialize failed: $error');
  }
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(AuthState.initial());

  final AuthService _authService;

  Future<void> restoreSession() async {
    // Yield to the event loop to avoid modifying authProvider state during Riverpod build phase
    await Future.microtask(() {});
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _authService.getPersistedSession();

      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          userId: '',
          clearRole: true,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userId: session.userId,
        role: session.role,
        avatarUrl: session.avatarUrl,
        clearError: true,
      );
    } catch (error) {
      String errorMessage = error.toString();
      if (error is AuthRetryableFetchException ||
          errorMessage.contains('Failed to fetch') ||
          errorMessage.contains('ClientException')) {
        errorMessage =
            'Connection error: Unable to reach the server. Please check your internet connection and Supabase URL configuration.';
      }
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        userId: '',
        clearRole: true,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _authService.login(
        identifier: identifier,
        password: password,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userId: session.userId,
        role: session.role,
        avatarUrl: session.avatarUrl,
        clearError: true,
      );
    } catch (error) {
      String errorMessage = error.toString();
      if (error is AuthRetryableFetchException ||
          errorMessage.contains('Failed to fetch') ||
          errorMessage.contains('ClientException')) {
        errorMessage =
            'Connection error: Unable to reach the server. Please check your internet connection and Supabase URL configuration.';
      } else if (errorMessage.startsWith('StateError: ')) {
        errorMessage = errorMessage.substring('StateError: '.length);
      }
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        userId: '',
        clearRole: true,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> signUp({
    required String identifier,
    required String password,
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      // Ensure Supabase is initialized before calling the auth API. On some
      // platforms (notably web/headless test runs) the top-level
      // `Supabase.initialize` in main.dart may not have completed yet.
      if (!Supabase.instance.isInitialized && SupabaseConfig.isConfigured) {
        await Supabase.initialize(
          url: SupabaseConfig.url,
          anonKey: SupabaseConfig.anonKey,
        );
      }

      final session = await _authService.signUp(
        identifier: identifier,
        password: password,
        name: name,
      );

      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          userId: '',
          clearRole: true,
          errorMessage:
              'Account created. Please confirm your email to continue.',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userId: session.userId,
        role: session.role,
        clearError: true,
      );
    } catch (error) {
      String errorMessage;
      if (error is AuthException) {
        // Surface the real reason from Supabase (e.g. "Database error saving
        // new user", "User already registered", "Signups not allowed", weak
        // password, etc.) so the user can act on it.
        errorMessage = error.message.isNotEmpty
            ? error.message
            : 'Sign-up failed. Please try again.';
      } else if (error is AuthRetryableFetchException ||
          error.toString().contains('Failed to fetch') ||
          error.toString().contains('ClientException') ||
          error.toString().contains('SocketException')) {
        errorMessage =
            'Connection error: Unable to reach the server. Please check your internet connection and Supabase URL configuration.';
      } else if (error.toString().startsWith('StateError: ')) {
        errorMessage = error.toString().substring('StateError: '.length);
      } else {
        errorMessage = error.toString();
      }
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        userId: '',
        clearRole: true,
        errorMessage: errorMessage,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _authService.logout();
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: false,
      userId: '',
      clearRole: true,
      clearError: true,
    );
  }

  Future<void> updateProfile({required String fullName, String? phone}) async {
    try {
      await _authService.updateProfile(fullName: fullName, phone: phone);
      // Refresh so the UI picks up the new metadata.
      await restoreSession();
    } catch (_) {
      // Silently fail — the modal can show a generic error if needed.
    }
  }

  Future<void> uploadAvatar(Uint8List bytes) async {
    try {
      final url = await _authService.uploadAvatar(bytes);
      state = state.copyWith(avatarUrl: url);
    } catch (_) {
      // Silently fail.
    }
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});

final roleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider).role;
});

/// Minimal projection of `public.profiles` for the current user. Used
/// by the dashboard greeting and account surfaces.
class CurrentProfile {
  const CurrentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.role,
  });

  factory CurrentProfile.fromMap(Map<String, dynamic> data) {
    return CurrentProfile(
      id: data['id']?.toString() ?? '',
      fullName: (data['full_name'] ?? data['email'] ?? 'there')
          .toString()
          .trim(),
      email: data['email']?.toString(),
      role: _parseRole(data['role']?.toString()),
    );
  }

  final String id;
  final String fullName;
  final String? email;
  final UserRole? role;

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'there';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  static UserRole? _parseRole(String? value) {
    if (value == null) return null;
    switch (value.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'operations':
        return UserRole.operations;
      case 'sales':
        return UserRole.sales;
      case 'hr':
        return UserRole.hr;
      case 'viewer':
        return UserRole.viewer;
      default:
        return null;
    }
  }
}

class CurrentProfileController
    extends StateNotifier<AsyncValue<CurrentProfile?>> {
  CurrentProfileController(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.userId != prev?.userId) {
        if (next.isAuthenticated && next.userId.isNotEmpty) {
          _load(next.userId);
        } else {
          state = const AsyncValue.data(null);
        }
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  SupabaseClient get _client => Supabase.instance.client;

  bool get _isConfigured =>
      SupabaseConfig.isConfigured && Supabase.instance.isInitialized;

  Future<void> _load(String userId) async {
    if (!_isConfigured) {
      state = const AsyncValue.data(null);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final data = await _client
          .from('profiles')
          .select('id, full_name, email, role')
          .eq('id', userId)
          .maybeSingle();
      if (data == null) {
        state = const AsyncValue.data(null);
      } else {
        state = AsyncValue.data(
          CurrentProfile.fromMap(Map<String, dynamic>.from(data)),
        );
      }
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> refresh() async {
    final userId = _ref.read(authProvider).userId;
    if (userId.isEmpty) {
      state = const AsyncValue.data(null);
      return;
    }
    await _load(userId);
  }
}

final currentProfileProvider =
    StateNotifierProvider<
      CurrentProfileController,
      AsyncValue<CurrentProfile?>
    >((ref) {
      return CurrentProfileController(ref);
    });

/// Active employee count for the dashboard "Employees" KPI. Reads
/// from `public.profiles` where `is_active = true`. Returns 0 if
/// Supabase isn't configured or the user isn't allowed to read it.
class ActiveEmployeeCountController extends StateNotifier<AsyncValue<int>> {
  ActiveEmployeeCountController(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.isAuthenticated != (prev?.isAuthenticated ?? false) ||
          next.userId != prev?.userId) {
        if (next.isAuthenticated) {
          _load();
        } else {
          state = const AsyncValue.data(0);
        }
      }
    }, fireImmediately: true);
  }

  final Ref _ref;
  SupabaseClient get _client => Supabase.instance.client;

  bool get _isConfigured =>
      SupabaseConfig.isConfigured && Supabase.instance.isInitialized;

  Future<void> _load() async {
    if (!_isConfigured) {
      state = const AsyncValue.data(0);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final data = await _client
          .from('profiles')
          .select('id')
          .eq('is_active', true);
      state = AsyncValue.data(List<Map<String, dynamic>>.from(data).length);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> refresh() => _load();
}

final activeEmployeeCountProvider =
    StateNotifierProvider<ActiveEmployeeCountController, AsyncValue<int>>((
      ref,
    ) {
      return ActiveEmployeeCountController(ref);
    });

final splashDecisionProvider = FutureProvider<String>((ref) async {
  // Use ref.read (not ref.watch) so that when appBootstrapProvider completes
  // it does NOT invalidate splashDecisionProvider and cause an infinite loop.
  await ref.read(appBootstrapProvider.future);

  // Small delay to let the event loop settle before touching authProvider state.
  await Future.delayed(const Duration(milliseconds: 50));
  try {
    await ref
        .read(authProvider.notifier)
        .restoreSession()
        .timeout(const Duration(seconds: 4));
  } catch (_) {
    // Defensive fallback: splash should never hard-fail routing.
    return AppRoutes.login;
  }

  final isAuthenticated = ref.read(authProvider).isAuthenticated;
  return isAuthenticated ? AppRoutes.dashboard : AppRoutes.login;
});
