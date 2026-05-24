import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:alpha_suite_erp/providers/auth_providers.dart';

class SplashView extends ConsumerWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final splashDecision = ref.watch(splashDecisionProvider);

    return Scaffold(
      body: Center(
        child: splashDecision.when(
          data: (route) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go(route);
              }
            });

            return const CircularProgressIndicator();
          },
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => const Text('Unable to initialize session'),
        ),
      ),
    );
  }
}
