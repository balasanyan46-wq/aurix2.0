import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/promo_request_model.dart';

class PromoRepository {
  Future<List<PromoRequestModel>> getMyRequests({String? releaseId}) async {
    final query = <String, dynamic>{
      'order': 'created_at.desc',
    };
    if (releaseId != null && releaseId.isNotEmpty) {
      query['release_id'] = releaseId;
    }
    final res = await ApiClient.get('/promo-requests', query: query);
    final list = res.data as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(PromoRequestModel.fromJson)
        .toList();
  }

  Future<List<PromoRequestModel>> getAllRequests() async {
    final res = await ApiClient.get('/promo-requests', query: {
      'order': 'created_at.desc',
    });
    final list = res.data as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(PromoRequestModel.fromJson)
        .toList();
  }

  Future<List<PromoEventModel>> getEvents(String promoRequestId) async {
    final res = await ApiClient.get('/promo-events', query: {
      'promo_request_id': promoRequestId,
      'order': 'created_at.desc',
    });
    final list = res.data as List;
    return list
        .cast<Map<String, dynamic>>()
        .map(PromoEventModel.fromJson)
        .toList();
  }

  Future<PromoRequestModel> createRequest({
    required String userId,
    required String releaseId,
    required String type,
    required Map<String, dynamic> formData,
    String status = 'submitted',
  }) async {
    final payload = {
      'user_id': userId,
      'release_id': releaseId,
      'type': type,
      'status': status,
      'form_data': formData,
    };
    final res = await ApiClient.post('/promo-requests', data: payload);
    final body = res.data as Map<String, dynamic>;
    final req = PromoRequestModel.fromJson(body);
    await addEvent(
      promoRequestId: req.id,
      eventType: 'status_changed',
      payload: {'to': status, 'source': 'artist_create'},
    );
    return req;
  }

  Future<PromoRequestModel> upsertByType({
    required String userId,
    required String releaseId,
    required String type,
    required Map<String, dynamic> formData,
    String status = 'submitted',
  }) async {
    // Check for existing active request
    try {
      final existingRes = await ApiClient.get('/promo-requests', query: {
        'user_id': userId,
        'release_id': releaseId,
        'type': type,
        'status_in': 'submitted,under_review,approved,in_progress',
        'order': 'created_at.desc',
        'limit': '1',
      });
      final existingList = existingRes.data as List;
      if (existingList.isNotEmpty) {
        final existing = existingList.first as Map<String, dynamic>;
        final existingId = existing['id'] as String;
        final updatedRes = await ApiClient.put('/promo-requests/$existingId', data: {
          'form_data': formData,
          'status': status,
        });
        final updatedBody = updatedRes.data as Map<String, dynamic>;
        await addEvent(
          promoRequestId: existingId,
          eventType: 'status_changed',
          payload: {'to': status, 'source': 'artist_update'},
        );
        return PromoRequestModel.fromJson(updatedBody);
      }
    } catch (_) {}
    return createRequest(
      userId: userId,
      releaseId: releaseId,
      type: type,
      formData: formData,
      status: status,
    );
  }

  Future<void> updateStatus({
    required String requestId,
    required String status,
  }) async {
    await ApiClient.put('/promo-requests/$requestId', data: {'status': status});
    await addEvent(
      promoRequestId: requestId,
      eventType: 'status_changed',
      payload: {'to': status, 'source': 'admin'},
    );
  }

  Future<void> updateAdminFields({
    required String requestId,
    String? adminNotes,
    String? assignedManager,
  }) async {
    final payload = <String, dynamic>{};
    if (adminNotes != null) payload['admin_notes'] = adminNotes;
    if (assignedManager != null) payload['assigned_manager'] = assignedManager;
    if (payload.isEmpty) return;
    await ApiClient.put('/promo-requests/$requestId', data: payload);
    if (adminNotes != null && adminNotes.trim().isNotEmpty) {
      await addEvent(
        promoRequestId: requestId,
        eventType: 'comment_added',
        payload: {'note': adminNotes},
      );
    }
    if (assignedManager != null && assignedManager.trim().isNotEmpty) {
      await addEvent(
        promoRequestId: requestId,
        eventType: 'assigned',
        payload: {'manager': assignedManager},
      );
    }
  }

  Future<void> addEvent({
    required String promoRequestId,
    required String eventType,
    Map<String, dynamic> payload = const {},
  }) async {
    await ApiClient.post('/promo-events', data: {
      'promo_request_id': promoRequestId,
      'event_type': eventType,
      'payload': payload,
    });
  }
}
