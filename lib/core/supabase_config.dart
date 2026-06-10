class SupabaseConfig {
  static const _urlFromDefine = String.fromEnvironment('SUPABASE_URL');
  static const _anonKeyFromDefine = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String get url {
    final fromEnv = 'https://aneeclnbitccdrxuknij.supabase.co';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    return _urlFromDefine;
  }

  static String get anonKey {
    final fromEnv =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFuZWVjbG5iaXRjY2RyeHVrbmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1NjA4NDYsImV4cCI6MjA5NjEzNjg0Nn0.p2hxBthArsXStapUZWf5KE9rnMVY4EwOqJIgBXdlXMs';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }

    return _anonKeyFromDefine;
  }

  static bool get isConfigured {
    return true;
  }
}
