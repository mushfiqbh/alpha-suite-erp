import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:erp/core/app_router.dart';
import 'package:erp/core/app_theme.dart';
import 'package:erp/core/supabase_config.dart';
import 'package:erp/services/update_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow google_fonts to download fonts at runtime so it doesn't
  // depend on AssetManifest.bin.json being present in the build output.
  GoogleFonts.config.allowRuntimeFetching = true;

  if (true) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
    } catch (error) {
      // ignore: avoid_print
      print('[main] Supabase.initialize failed: $error');
    }
  }

  // Automatically check for updates on app launch
  UpdateService().checkForUpdates();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Alpha Suite ERP',
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
