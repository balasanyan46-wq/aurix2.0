import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/core/admin_config.dart';

void main() {
  group('adminEmails', () {
    test('should not be empty', () {
      expect(adminEmails, isNotEmpty);
    });

    test('should contain known admin emails', () {
      expect(adminEmails, contains('admin@aurix.io'));
    });

    test('should contain valid email-like strings', () {
      for (final email in adminEmails) {
        expect(email, contains('@'));
        expect(email, contains('.'));
      }
    });
  });
}
