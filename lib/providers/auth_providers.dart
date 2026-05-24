import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alpha_suite_erp/core/constants/app_routes.dart';
import 'package:alpha_suite_erp/services/auth_service.dart';

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
  const AuthSession({required this.userId, required this.role});

  final String userId;
  final UserRole role;
}

class AuthState {
  const AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    required this.role,
    required this.errorMessage,
  });

  factory AuthState.initial() {
    return const AuthState(
      isLoading: false,
      isAuthenticated: false,
      role: null,
      errorMessage: null,
    );
  }

  final bool isLoading;
  final bool isAuthenticated;
  final UserRole? role;
  final String? errorMessage;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserRole? role,
    bool clearRole = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: clearRole ? null : (role ?? this.role),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(AuthState.initial());

  final AuthService _authService;

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _authService.getPersistedSession();

      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          clearRole: true,
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        role: session.role,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearRole: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _authService.login(
        email: email,
        password: password,
      );
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        role: session.role,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearRole: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await _authService.signUp(
        email: email,
        password: password,
        role: role,
      );

      if (session == null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: false,
          clearRole: true,
          errorMessage:
              'Account created. Please confirm your email to continue.',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        role: session.role,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        clearRole: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await _authService.logout();
    state = state.copyWith(
      isLoading: false,
      isAuthenticated: false,
      clearRole: true,
      clearError: true,
    );
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authServiceProvider));
});

final roleProvider = Provider<UserRole?>((ref) {
  return ref.watch(authProvider).role;
});

/// Used by SplashView to bootstrap auth state before first route decision.
final splashDecisionProvider = FutureProvider<String>((ref) async {
  try {
    await ref.read(authProvider.notifier).restoreSession();
  } catch (_) {
    // Defensive fallback: splash should never hard-fail routing.
    return AppRoutes.login;
  }

  final isAuthenticated = ref.read(authProvider).isAuthenticated;
  return isAuthenticated ? AppRoutes.dashboard : AppRoutes.login;
});
