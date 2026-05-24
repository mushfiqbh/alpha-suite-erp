import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Supported sources:
  // 1) .env via flutter_dotenv
  // 2) compile-time flags via --dart-define
  static const _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url {
    final fromEnv =
        dotenv.env['SUPABASE_URL'] ??
        dotenv.env['NEXT_PUBLIC_SUPABASE_URL'] ??
        dotenv.env['VITE_SUPABASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }

    return _urlFromDefine;
  }

  static String get anonKey {
    final fromEnv =
        dotenv.env['SUPABASE_ANON_KEY'] ??
        dotenv.env['NEXT_PUBLIC_SUPABASE_ANON_KEY'] ??
        dotenv.env['VITE_SUPABASE_ANON_KEY'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }

    return _anonKeyFromDefine;
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
