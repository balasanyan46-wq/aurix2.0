import 'package:aurix_flutter/core/api/api_client.dart';

class AccountDeletionRequestRepository {
  Future<void> createRequest({
    required String reason,
  }) async {
    await ApiClient.post('/account-deletion-requests', data: {
      'reason': reason.trim().isEmpty ? null : reason.trim(),
      'status': 'pending',
    });
  }

  Future<String?> latestStatus() async {
    try {
      final res = await ApiClient.get('/account-deletion-requests/latest-status');
      final body = res.data;
      if (body is Map<String, dynamic>) {
        return body['status'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
