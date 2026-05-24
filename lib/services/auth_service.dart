import 'package:alpha_suite_erp/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alpha_suite_erp/core/constants/supabase_config.dart';

/// Supabase auth abstraction for sign-in, sign-up and session restoration.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  bool get _isConfigured => SupabaseConfig.isConfigured;

  UserRole _resolveRole(User user) {
    final appMetadataRole = user.appMetadata['role']?.toString();
    final userMetadataRole = user.userMetadata?['role']?.toString();
    final rawRole = (appMetadataRole ?? userMetadataRole ?? 'viewer')
        .toLowerCase();

    return UserRole.values.firstWhere(
      (role) => role.name == rawRole,
      orElse: () => UserRole.viewer,
    );
  }

  AuthSession _toAuthSession(User user) {
    return AuthSession(userId: user.id, role: _resolveRole(user));
  }

  Future<AuthSession?> getPersistedSession() async {
    if (!_isConfigured) {
      return null;
    }

    try {
      final session = _client.auth.currentSession;
      final user = session?.user;

      if (user == null) {
        return null;
      }

      return _toAuthSession(user);
    } catch (_) {
      // Any initialization/token issue should fall back to a safe logged-out state.
      return null;
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (!_isConfigured) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env or --dart-define.',
      );
    }

    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw StateError('Sign-in failed. User session was not created.');
    }

    return _toAuthSession(user);
  }

  Future<AuthSession?> signUp({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (!_isConfigured) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env or --dart-define.',
      );
    }

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': role.name},
    );

    final user = response.user;
    if (user == null) {
      // When email confirmation is enabled, user may need to confirm first.
      return null;
    }

    return _toAuthSession(user);
  }

  Future<void> logout() async {
    if (!_isConfigured) {
      return;
    }

    await _client.auth.signOut();
  }
}
