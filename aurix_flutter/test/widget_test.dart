// Basic Flutter widget test for Design Mode app.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/presentation/design/design_app.dart';

void main() {
  testWidgets('Design app loads and shows dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: DesignApp()));

    // Verify design shell renders.
    expect(find.text('Releases'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
  });
}
