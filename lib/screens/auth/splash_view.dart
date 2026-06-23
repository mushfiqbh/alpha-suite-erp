import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:erp/providers/auth_providers.dart';
import 'package:erp/core/app_routes.dart';

class SplashView extends ConsumerStatefulWidget {
  const SplashView({super.key});

  @override
  ConsumerState<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends ConsumerState<SplashView> {
  static const Duration _minDisplay = Duration(seconds: 3);

  bool _hasNavigated = false;
  final DateTime _startTime = DateTime.now();

  Future<void> _navigate(String route) async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    // Ensure the splash is visible for at least 3 seconds.
    final elapsed = DateTime.now().difference(_startTime);
    final remaining = _minDisplay - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    // Only use ref.listen for navigation — never ref.watch(splashDecisionProvider)
    // here, because watching a FutureProvider that calls ref.read(authProvider.notifier)
    // inside build causes state-mutation-during-build errors.
    ref.listen<AsyncValue<String>>(splashDecisionProvider, (previous, next) {
      next.when(
        data: _navigate,
        error: (_, __) => _navigate(AppRoutes.login),
        loading: () {},
      );
    });

    // Derive loading state from bootstrap only — no extra watch on splashDecisionProvider.
    final bootstrapState = ref.watch(appBootstrapProvider);
    final isBusy = bootstrapState.isLoading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF334155)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Alpha Suite ERP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isBusy
                          ? 'Preparing your workspace...'
                          : 'Loading complete',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    if (bootstrapState.hasError) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Startup error: ${bootstrapState.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
