import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'production_models.dart';

class ProductionService {
  Future<ProductionDashboard> getArtistDashboard(String userId) async {
    final ordersRes = await ApiClient.get('/production-orders', query: {
      'user_id': userId,
    });
    final orders = ((ordersRes.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionOrder.fromJson)
        .toList();
    if (orders.isEmpty) {
      return const ProductionDashboard(
        orders: [],
        items: [],
        releaseTitleById: {},
        releaseCoverById: {},
      );
    }

    final orderIds = orders.map((e) => e.id).toList();
    final itemsRes = await ApiClient.get('/production-order-items', query: {
      'order_ids': orderIds.join(','),
    });
    final items = ((itemsRes.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionOrderItem.fromJson)
        .toList();

    final releaseIds = orders.map((o) => o.releaseId).whereType<String>().toSet().toList();
    final titles = <String, String>{};
    final covers = <String, String?>{};
    if (releaseIds.isNotEmpty) {
      final releasesRes = await ApiClient.get('/releases', query: {
        'ids': releaseIds.join(','),
      });
      for (final r in ((releasesRes.data as List?) ?? const []).whereType<Map<String, dynamic>>()) {
        final id = (r['id'] ?? '').toString();
        if (id.isEmpty) continue;
        titles[id] = (r['title'] ?? 'Релиз').toString();
        covers[id] = r['cover_url']?.toString();
      }
    }

    return ProductionDashboard(
      orders: orders,
      items: items,
      releaseTitleById: titles,
      releaseCoverById: covers,
    );
  }

  Future<List<ProductionServiceCatalog>> getCatalog({bool includeInactive = false}) async {
    final res = await ApiClient.get('/service-catalog', query: {
      if (!includeInactive) 'is_active': true,
    });
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionServiceCatalog.fromJson)
        .toList();
  }

  Future<List<ProductionAssignee>> getAssignees({bool includeInactive = true}) async {
    final res = await ApiClient.get('/production-assignees', query: {
      if (!includeInactive) 'is_active': true,
    });
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionAssignee.fromJson)
        .toList();
  }

  Future<(List<ProductionComment>, List<ProductionFile>, List<ProductionEvent>)> getItemDetails(
    String orderItemId,
  ) async {
    final commentsRes = await ApiClient.get('/production-comments', query: {'order_item_id': orderItemId});
    final filesRes = await ApiClient.get('/production-files', query: {'order_item_id': orderItemId});
    final eventsRes = await ApiClient.get('/production-events', query: {'order_item_id': orderItemId});

    final comments = ((commentsRes.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionComment.fromJson)
        .toList();
    final files = ((filesRes.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionFile.fromJson)
        .toList();
    final events = ((eventsRes.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionEvent.fromJson)
        .toList();
    return (comments, files, events);
  }

  Future<void> addComment({
    required String orderItemId,
    required String authorUserId,
    required String authorRole,
    required String message,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return;
    await ApiClient.post('/production-comments', data: {
      'order_item_id': orderItemId,
      'author_user_id': authorUserId,
      'author_role': authorRole,
      'message': text,
    });
    await ApiClient.post('/production-events', data: {
      'order_item_id': orderItemId,
      'event_type': 'comment_added',
      'payload': {'text': text, 'role': authorRole},
    });
  }

  Future<void> updateItem({
    required String itemId,
    String? status,
    String? assigneeId,
    DateTime? deadlineAt,
    Map<String, dynamic>? brief,
  }) async {
    final payload = <String, dynamic>{};
    if (status != null) payload['status'] = status;
    if (assigneeId != null) payload['assignee_id'] = assigneeId.isEmpty ? null : assigneeId;
    if (deadlineAt != null) payload['deadline_at'] = deadlineAt.toIso8601String();
    if (brief != null) payload['brief'] = brief;
    if (payload.isEmpty) return;

    await ApiClient.put('/production-order-items/$itemId', data: payload);
    if (status != null) {
      await ApiClient.post('/production-events', data: {
        'order_item_id': itemId,
        'event_type': 'status_changed',
        'payload': {'status': status},
      });
    }
    if (assigneeId != null) {
      await ApiClient.post('/production-events', data: {
        'order_item_id': itemId,
        'event_type': 'assigned',
        'payload': {'assignee_id': assigneeId},
      });
    }
    if (deadlineAt != null) {
      await ApiClient.post('/production-events', data: {
        'order_item_id': itemId,
        'event_type': 'deadline_changed',
        'payload': {'deadline_at': deadlineAt.toIso8601String()},
      });
    }
  }

  Future<String> uploadOrderFile({
    required String orderItemId,
    required String uploadedBy,
    required String kind, // input/output
    required PlatformFile file,
  }) async {
    final bytes = file.bytes;
    if (bytes == null) throw StateError('Файл пустой');
    final uploadRes = await ApiClient.uploadFile('/upload/audio', bytes, _safe(file.name));
    final body = (uploadRes.data as Map).cast<String, dynamic>();
    final path = (body['path'] ?? '').toString();

    await ApiClient.post('/production-files', data: {
      'order_item_id': orderItemId,
      'uploaded_by': uploadedBy,
      'kind': kind,
      'file_name': file.name,
      'mime_type': file.extension ?? '',
      'storage_bucket': 'production',
      'storage_path': path,
      'size_bytes': file.size,
    });
    await ApiClient.post('/production-events', data: {
      'order_item_id': orderItemId,
      'event_type': 'file_uploaded',
      'payload': {'kind': kind, 'file_name': file.name},
    });
    return path;
  }

  Future<String> getSignedDownloadUrl(String path) async {
    final res = await ApiClient.get('/production-files/signed-url', query: {'path': path});
    return ((res.data as Map<String, dynamic>)['url'] ?? '').toString();
  }

  Future<void> createOrder({
    required String userId,
    String? releaseId,
    String? title,
    required List<String> serviceIds,
  }) async {
    final uniqServiceIds = serviceIds.where((x) => x.trim().isNotEmpty).toSet().toList();
    if (uniqServiceIds.isEmpty) {
      throw StateError('Нужно выбрать хотя бы одну услугу');
    }
    final orderRes = await ApiClient.post('/production-orders', data: {
      'user_id': userId,
      'release_id': releaseId,
      'title': title,
      'status': 'active',
    });
    final orderId = ((orderRes.data as Map<String, dynamic>)['id'] ?? '').toString();
    final items = uniqServiceIds
        .map((s) => {
              'order_id': orderId,
              'service_id': s,
              'status': 'not_started',
            })
        .toList();
    final insertedItemsRes = await ApiClient.post('/production-order-items/batch', data: items);
    final itemIds = ((insertedItemsRes.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((x) => (x['id'] ?? '').toString())
        .where((x) => x.isNotEmpty)
        .toList();
    if (itemIds.isNotEmpty) {
      await ApiClient.post(
        '/production-events/batch',
        data: itemIds
            .map((id) => {
                  'order_item_id': id,
                  'event_type': 'created',
                  'payload': {'source': 'order_created'},
                })
            .toList(),
      );
    }
  }

  Future<void> upsertService(ProductionServiceCatalog s) async {
    await ApiClient.put('/service-catalog', data: {
      'id': s.id.isEmpty ? null : s.id,
      'title': s.title,
      'description': s.description,
      'category': s.category,
      'default_price': s.defaultPrice,
      'sla_days': s.slaDays,
      'required_inputs': s.requiredInputs,
      'deliverables': s.deliverables,
      'is_active': s.isActive,
    });
  }

  Future<void> upsertAssignee(ProductionAssignee a) async {
    await ApiClient.put('/production-assignees', data: {
      'id': a.id.isEmpty ? null : a.id,
      'user_id': a.userId,
      'full_name': a.fullName,
      'specialization': a.specialization,
      'contacts': a.contacts,
      'is_active': a.isActive,
    });
  }

  Future<List<ProductionOrder>> getAllOrders() async {
    final res = await ApiClient.get('/production-orders');
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionOrder.fromJson)
        .toList();
  }

  Future<List<ProductionOrderItem>> getItemsForOrders(List<String> orderIds) async {
    if (orderIds.isEmpty) return const [];
    final res = await ApiClient.get('/production-order-items', query: {
      'order_ids': orderIds.join(','),
    });
    return ((res.data as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProductionOrderItem.fromJson)
        .toList();
  }

  String _safe(String input) => input.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
}
