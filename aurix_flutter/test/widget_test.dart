// Basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/app.dart';

void main() {
  testWidgets('App loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AurixApp()));
    expect(find.byType(AurixApp), findsOneWidget);
  });
}
