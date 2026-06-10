import 'package:erp/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:erp/core/supabase_config.dart';

/// Supabase auth abstraction for sign-in, sign-up and session restoration.
class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  bool get _isConfigured => SupabaseConfig.isConfigured;

  bool _looksLikeEmail(String identifier) {
    return identifier.contains('@');
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s()-]'), '').trim();
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

      // Fetch profile to verify role and is_active status
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single()
          .timeout(const Duration(seconds: 3));

      final isActive = profile['is_active'] as bool? ?? true;
      if (!isActive) {
        await logout();
        return null;
      }

      final rawRole = (profile['role']?.toString() ?? 'viewer').toLowerCase();
      final role = UserRole.values.firstWhere(
        (r) => r.name == rawRole,
        orElse: () => UserRole.viewer,
      );

      return AuthSession(userId: user.id, role: role);
    } catch (_) {
      // If fetching the profile fails, fallback to a safe logged-out state
      return null;
    }
  }

  Future<AuthSession> login({
    required String identifier,
    required String password,
  }) async {
    if (!_isConfigured) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env or --dart-define.',
      );
    }

    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.isEmpty) {
      throw StateError('Email is required.');
    }

    final response = _looksLikeEmail(normalizedIdentifier)
        ? await _client.auth.signInWithPassword(
            email: normalizedIdentifier,
            password: password,
          )
        : await _client.auth.signInWithPassword(
            phone: _normalizePhone(normalizedIdentifier),
            password: password,
          );

    final user = response.user;
    if (user == null) {
      throw StateError('Sign-in failed. User session was not created.');
    }

    // Fetch profile to verify role and is_active status
    final profile = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    final isActive = profile['is_active'] as bool? ?? true;
    if (!isActive) {
      await logout();
      throw StateError(
        'Your account has been deactivated. Please contact an administrator.',
      );
    }

    final rawRole = (profile['role']?.toString() ?? 'viewer').toLowerCase();
    final role = UserRole.values.firstWhere(
      (r) => r.name == rawRole,
      orElse: () => UserRole.viewer,
    );

    return AuthSession(userId: user.id, role: role);
  }

  Future<AuthSession?> signUp({
    required String identifier,
    required String password,
  }) async {
    if (!_isConfigured) {
      throw StateError(
        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env or --dart-define.',
      );
    }

    final normalizedIdentifier = identifier.trim();
    if (normalizedIdentifier.isEmpty) {
      throw StateError('Email is required for sign-up.');
    }

    final response = _looksLikeEmail(normalizedIdentifier)
        ? await _client.auth.signUp(
            email: normalizedIdentifier,
            password: password,
            data: {'full_name': normalizedIdentifier.split('@').first},
          )
        : await _client.auth.signUp(
            phone: _normalizePhone(normalizedIdentifier),
            password: password,
            data: {
              'full_name': normalizedIdentifier,
              'phone': _normalizePhone(normalizedIdentifier),
            },
          );

    final user = response.user;
    if (user == null) {
      // When email confirmation is enabled, user may need to confirm first.
      return null;
    }

    final session = response.session;
    if (session != null) {
      return AuthSession(userId: user.id, role: UserRole.viewer);
    }

    return null;
  }

  Future<void> logout() async {
    if (!_isConfigured) {
      return;
    }

    await _client.auth.signOut();
  }
}
