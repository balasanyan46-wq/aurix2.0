import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/release_delete_request_model.dart';

class ReleaseDeleteRequestRepository {
  Future<List<ReleaseDeleteRequestModel>> getMyRequests(String requesterId) async {
    final res = await ApiClient.get('/release-delete-requests', query: {
      'requester_id': requesterId,
      'order': 'created_at.desc',
    });
    final list = res.data as List;
    return list
        .map((e) => ReleaseDeleteRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReleaseDeleteRequestModel>> getAllRequests() async {
    final res = await ApiClient.get('/release-delete-requests', query: {
      'order': 'created_at.desc',
    });
    final list = res.data as List;
    return list
        .map((e) => ReleaseDeleteRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> requestDelete({
    required String releaseId,
    required String requesterId,
    String? reason,
  }) async {
    await ApiClient.post('/release-delete-requests', data: {
      'release_id': releaseId,
      'requester_id': requesterId,
      'status': 'pending',
      'reason': reason?.trim().isEmpty ?? true ? null : reason!.trim(),
    });
  }

  Future<void> approve({
    required String requestId,
    required String adminId,
    String? comment,
  }) async {
    await ApiClient.put('/release-delete-requests/$requestId', data: {
      'status': 'approved',
      'processed_by': adminId,
      'processed_at': DateTime.now().toIso8601String(),
      'admin_comment': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
    });
  }

  Future<void> reject({
    required String requestId,
    required String adminId,
    String? comment,
  }) async {
    await ApiClient.put('/release-delete-requests/$requestId', data: {
      'status': 'rejected',
      'processed_by': adminId,
      'processed_at': DateTime.now().toIso8601String(),
      'admin_comment': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
    });
  }

  Future<void> processByAdmin({
    required String requestId,
    required String decision, // approve / reject
    String? comment,
  }) async {
    final mode = decision == 'approve' ? 'approve' : 'reject';
    try {
      await ApiClient.post('/rpc/admin_process_release_delete_request', data: {
        'p_request_id': requestId,
        'p_decision': mode,
        'p_comment': comment,
      });
      return;
    } catch (e) {
      debugPrint('[ReleaseDeleteRequestRepository] RPC fallback failed: $e');
      // Backward compatibility fallback — caller must supply adminId via JWT.
      if (mode == 'approve') {
        await ApiClient.put('/release-delete-requests/$requestId', data: {
          'status': 'approved',
          'processed_at': DateTime.now().toIso8601String(),
          'admin_comment': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
        });
      } else {
        await ApiClient.put('/release-delete-requests/$requestId', data: {
          'status': 'rejected',
          'processed_at': DateTime.now().toIso8601String(),
          'admin_comment': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
        });
      }
    }
  }
}
