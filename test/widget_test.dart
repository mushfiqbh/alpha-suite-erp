import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:erp/core/app_routes.dart';
import 'package:erp/main.dart';
import 'package:erp/providers/auth_providers.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appBootstrapProvider.overrideWith((ref) async {}),
          splashDecisionProvider.overrideWith((ref) async => AppRoutes.login),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the splash loading view is rendered initially.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
