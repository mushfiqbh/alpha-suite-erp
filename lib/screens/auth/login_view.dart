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
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isSignUp = false;
  bool _obscurePassword = true;

  // Focus tracking for styling
  bool _nameFocused = false;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  // Inline validation errors
  String? _emailError;
  String? _passwordError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(
      () => setState(() => _nameFocused = _nameFocusNode.hasFocus),
    );
    _emailFocusNode.addListener(
      () => setState(() => _emailFocused = _emailFocusNode.hasFocus),
    );
    _passwordFocusNode.addListener(
      () => setState(() => _passwordFocused = _passwordFocusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _clearAllErrors() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _nameError = null;
    });
  }

  bool _validateForm() {
    _clearAllErrors();
    bool isValid = true;

    // --- Email validation ---
    final email = _identifierController.text.trim();
    if (email.isEmpty) {
      _emailError = 'Email is required.';
      isValid = false;
    } else if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      _emailError = 'Please enter a valid email address.';
      isValid = false;
    }

    // --- Password validation ---
    final password = _passwordController.text;
    if (password.isEmpty) {
      _passwordError = 'Password is required.';
      isValid = false;
    } else if (password.length < 6) {
      _passwordError = 'Password must be at least 6 characters.';
      isValid = false;
    } else if (!RegExp(r'[a-zA-Z]').hasMatch(password)) {
      _passwordError = 'Password must contain at least one letter.';
      isValid = false;
    } else if (!RegExp(r'[0-9]').hasMatch(password)) {
      _passwordError = 'Password must contain at least one number.';
      isValid = false;
    }

    // --- Name validation (only for sign up) ---
    if (_isSignUp) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        _nameError = 'Name is required.';
        isValid = false;
      } else if (name.length < 2) {
        _nameError = 'Name must be at least 2 characters.';
        isValid = false;
      }
    }

    if (!isValid) {
      setState(() {});
    }
    return isValid;
  }

  Future<void> _submit() async {
    if (!_validateForm()) return;

    if (_isSignUp) {
      await ref
          .read(authProvider.notifier)
          .signUp(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
          );
    } else {
      await ref
          .read(authProvider.notifier)
          .login(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
          );
    }

    if (!mounted) return;

    if (ref.read(authProvider).isAuthenticated) {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surfaceContainerHighest,
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 36.0,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // App branding/title
                  Text(
                    'ERP System',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? 'Create your account'
                        : 'Sign in with your account',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Sign In / Sign Up Toggle
                  Center(
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('Sign In'),
                          icon: Icon(Icons.login),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('Sign Up'),
                          icon: Icon(Icons.person_add),
                        ),
                      ],
                      selected: {_isSignUp},
                      onSelectionChanged: (selected) {
                        setState(() {
                          _isSignUp = selected.first;
                          _clearAllErrors();
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor:
                            theme.colorScheme.primaryContainer,
                        selectedForegroundColor:
                            theme.colorScheme.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        visualDensity: VisualDensity.comfortable,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!SupabaseConfig.isConfigured) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Supabase is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in .env or --dart-define.',
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Name Input Field (only for sign up)
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        errorText: _nameError,
                        filled: true,
                        fillColor: _nameFocused
                            ? theme.colorScheme.primaryContainer.withOpacity(
                                0.5,
                              )
                            : theme.colorScheme.surface.withOpacity(0.7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (_nameError != null)
                          setState(() => _nameError = null);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Input Field
                  TextField(
                    controller: _identifierController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      errorText: _emailError,
                      filled: true,
                      fillColor: _emailFocused
                          ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                          : theme.colorScheme.surface.withOpacity(0.7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.error,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (_emailError != null)
                        setState(() => _emailError = null);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Input Field
                  TextField(
                    controller: _passwordController,
                    focusNode: _passwordFocusNode,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      filled: true,
                      fillColor: _passwordFocused
                          ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                          : theme.colorScheme.surface.withOpacity(0.7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.error,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (_passwordError != null) {
                        setState(() => _passwordError = null);
                      }
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: authState.isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                    ),
                  ),

                  // Server / auth error message
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (authState.isLoading) ...[
                    const SizedBox(height: 24),
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
