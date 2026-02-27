// Basic Flutter widget test for Design Mode app.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/presentation/design/design_app.dart';
import 'package:aurix_flutter/presentation/design/design_shell.dart';
import 'package:aurix_flutter/presentation/landing/landing_page.dart';

void main() {
  testWidgets('Design app loads and shows dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DesignApp()));

    // DesignApp может показать DesignShell (без Supabase) или landing/auth flow (с Supabase).
    final hasShell = find.byType(DesignShell).evaluate().isNotEmpty;
    final hasLanding = find.byType(LandingPage).evaluate().isNotEmpty;
    expect(hasShell || hasLanding, isTrue);
  });
}
