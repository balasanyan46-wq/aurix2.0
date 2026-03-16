import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/services/chat_api_contract.dart';

void main() {
  group('ChatApiContract.parseMessageFromBody', () {
    test('parses legacy reply format', () {
      const raw = '{"reply":"legacy answer"}';
      final result = ChatApiContract.parseMessageFromBody(raw);
      expect(result, 'legacy answer');
    });

    test('parses envelope ok format', () {
      const raw =
          '{"status":"ok","version":"2","data":{"message":"envelope answer"},"meta":{"request_id":"r-1"}}';
      final result = ChatApiContract.parseMessageFromBody(raw);
      expect(result, 'envelope answer');
    });

    test('throws ApiException for envelope error', () {
      const raw =
          '{"status":"error","code":"INVALID_MODEL_OUTPUT","message":"AI failed","meta":{"request_id":"r-2"}}';
      expect(
        () => ChatApiContract.parseMessageFromBody(raw),
        throwsA(isA<ApiException>()),
      );
    });
  });
}

