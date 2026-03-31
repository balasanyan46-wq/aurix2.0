import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/core/api/api_error.dart';

void main() {
  group('formatApiError', () {
    test('should strip "Exception: " prefix', () {
      final result = formatApiError(Exception('Something went wrong'));
      expect(result, 'Something went wrong');
    });

    test('should trim whitespace', () {
      final result = formatApiError(Exception('  spaced  '));
      expect(result, 'spaced');
    });

    test('should handle plain string error', () {
      final result = formatApiError('raw error text');
      expect(result, 'raw error text');
    });

    test('should handle error with no Exception prefix', () {
      final result = formatApiError(42);
      expect(result, '42');
    });

    test('should handle empty exception message', () {
      final result = formatApiError(Exception(''));
      expect(result, isEmpty);
    });
  });
}
