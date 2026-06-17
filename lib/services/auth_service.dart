import 'dart:io';
import 'dart:typed_data';

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
      final avatarUrl = profile['avatar_url']?.toString();

      return AuthSession(userId: user.id, role: role, avatarUrl: avatarUrl);
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
    final avatarUrl = profile['avatar_url']?.toString();

    return AuthSession(userId: user.id, role: role, avatarUrl: avatarUrl);
  }

  Future<AuthSession?> signUp({
    required String identifier,
    required String password,
    String? name,
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

    final displayName = name?.trim().isNotEmpty == true
        ? name!.trim()
        : normalizedIdentifier.split('@').first;

    final response = _looksLikeEmail(normalizedIdentifier)
        ? await _client.auth.signUp(
            email: normalizedIdentifier,
            password: password,
            data: {'full_name': displayName},
          )
        : await _client.auth.signUp(
            phone: _normalizePhone(normalizedIdentifier),
            password: password,
            data: {
              'full_name': displayName,
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

  /// Update the current user's profile (full_name and phone in the profiles table
  /// and auth user_metadata).
  Future<void> updateProfile({required String fullName, String? phone}) async {
    if (!_isConfigured) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    final profileUpdate = <String, dynamic>{'full_name': fullName};
    if (phone != null) {
      profileUpdate['phone'] = _normalizePhone(phone);
    }

    await _client.from('profiles').update(profileUpdate).eq('id', user.id);

    final metadata = <String, dynamic>{'full_name': fullName};
    if (phone != null) {
      metadata['phone'] = _normalizePhone(phone);
    }

    await _client.auth.updateUser(UserAttributes(data: metadata));
  }

  /// Upload an avatar image to Supabase Storage and update the profile.
  /// Returns the public URL of the uploaded avatar.
  Future<String> uploadAvatar(Uint8List bytes) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    // Write bytes to a temp file so we can pass a File to Supabase storage.
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}${Platform.pathSeparator}avatar_${user.id}.jpg',
    );
    await tempFile.writeAsBytes(bytes);

    await _client.storage
        .from('avatars')
        .upload(
          '${user.id}/avatar.jpg',
          tempFile,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    // Clean up the temp file.
    try {
      await tempFile.delete();
    } catch (_) {}

    final publicUrl = _client.storage
        .from('avatars')
        .getPublicUrl('${user.id}/avatar.jpg');

    // Update the profiles table with the new avatar URL
    await _client
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', user.id);

    // Also update auth user_metadata so it's available via currentUser
    await _client.auth.updateUser(
      UserAttributes(data: {'avatar_url': publicUrl}),
    );

    return publicUrl;
  }
}
