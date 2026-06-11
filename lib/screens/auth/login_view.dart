import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/providers/auth_providers.dart';
import 'package:erp/core/supabase_config.dart';

class LoginView extends ConsumerStatefulWidget {
  const LoginView({super.key});

  @override
  ConsumerState<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends ConsumerState<LoginView> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await ref
        .read(authProvider.notifier)
        .login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (ref.read(authProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _signUp() async {
    await ref
        .read(authProvider.notifier)
        .signUp(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) {
      return;
    }

    if (ref.read(authProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ERP Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!SupabaseConfig.isConfigured)
                    const Text(
                      'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env or --dart-define.',
                      style: TextStyle(color: Colors.red),
                    ),
                  if (!SupabaseConfig.isConfigured) const SizedBox(height: 12),
                  const Text(
                    'Sign in with your Supabase account',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _identifierController,
                    keyboardType: TextInputType.text,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      helperText: 'Use your email address.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: authState.isLoading ? null : _signUp,
                          child: const Text('Sign Up'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: authState.isLoading ? null : _login,
                          child: const Text('Sign In'),
                        ),
                      ),
                    ],
                  ),
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      authState.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (authState.isLoading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
