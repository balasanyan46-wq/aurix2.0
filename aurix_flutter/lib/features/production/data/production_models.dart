class ProductionServiceCatalog {
  final String id;
  final String title;
  final String description;
  final String category;
  final double? defaultPrice;
  final int? slaDays;
  final Map<String, dynamic> requiredInputs;
  final Map<String, dynamic> deliverables;
  final bool isActive;

  const ProductionServiceCatalog({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.defaultPrice,
    required this.slaDays,
    required this.requiredInputs,
    required this.deliverables,
    required this.isActive,
  });

  factory ProductionServiceCatalog.fromJson(Map<String, dynamic> j) => ProductionServiceCatalog(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        category: (j['category'] ?? 'other').toString(),
        defaultPrice: j['default_price'] is num ? (j['default_price'] as num).toDouble() : null,
        slaDays: j['sla_days'] is num ? (j['sla_days'] as num).toInt() : null,
        requiredInputs: (j['required_inputs'] is Map<String, dynamic>)
            ? (j['required_inputs'] as Map<String, dynamic>)
            : const {},
        deliverables: (j['deliverables'] is Map<String, dynamic>)
            ? (j['deliverables'] as Map<String, dynamic>)
            : const {},
        isActive: j['is_active'] != false,
      );
}

class ProductionAssignee {
  final String id;
  final String? userId;
  final String fullName;
  final String specialization;
  final String contacts;
  final bool isActive;

  const ProductionAssignee({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.specialization,
    required this.contacts,
    required this.isActive,
  });

  factory ProductionAssignee.fromJson(Map<String, dynamic> j) => ProductionAssignee(
        id: (j['id'] ?? '').toString(),
        userId: j['user_id']?.toString(),
        fullName: (j['full_name'] ?? '').toString(),
        specialization: (j['specialization'] ?? '').toString(),
        contacts: (j['contacts'] ?? '').toString(),
        isActive: j['is_active'] != false,
      );
}

class ProductionOrder {
  final String id;
  final String userId;
  final String? releaseId;
  final String status;
  final String title;
  final DateTime? createdAt;

  const ProductionOrder({
    required this.id,
    required this.userId,
    required this.releaseId,
    required this.status,
    required this.title,
    required this.createdAt,
  });

  factory ProductionOrder.fromJson(Map<String, dynamic> j) => ProductionOrder(
        id: (j['id'] ?? '').toString(),
        userId: (j['user_id'] ?? '').toString(),
        releaseId: j['release_id']?.toString(),
        status: (j['status'] ?? 'active').toString(),
        title: (j['title'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

class ProductionOrderItem {
  final String id;
  final String orderId;
  final String serviceId;
  final String status;
  final String? assigneeId;
  final DateTime? deadlineAt;
  final Map<String, dynamic> brief;
  final DateTime? createdAt;
  final ProductionServiceCatalog? service;
  final ProductionAssignee? assignee;

  const ProductionOrderItem({
    required this.id,
    required this.orderId,
    required this.serviceId,
    required this.status,
    required this.assigneeId,
    required this.deadlineAt,
    required this.brief,
    required this.createdAt,
    required this.service,
    required this.assignee,
  });

  factory ProductionOrderItem.fromJson(Map<String, dynamic> j) => ProductionOrderItem(
        id: (j['id'] ?? '').toString(),
        orderId: (j['order_id'] ?? '').toString(),
        serviceId: (j['service_id'] ?? '').toString(),
        status: (j['status'] ?? 'not_started').toString(),
        assigneeId: j['assignee_id']?.toString(),
        deadlineAt: DateTime.tryParse((j['deadline_at'] ?? '').toString()),
        brief: (j['brief'] is Map<String, dynamic>) ? (j['brief'] as Map<String, dynamic>) : const {},
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
        service: (j['service'] is Map<String, dynamic>)
            ? ProductionServiceCatalog.fromJson(j['service'] as Map<String, dynamic>)
            : null,
        assignee: (j['assignee'] is Map<String, dynamic>)
            ? ProductionAssignee.fromJson(j['assignee'] as Map<String, dynamic>)
            : null,
      );
}

class ProductionComment {
  final String id;
  final String orderItemId;
  final String authorUserId;
  final String authorRole;
  final String message;
  final DateTime? createdAt;

  const ProductionComment({
    required this.id,
    required this.orderItemId,
    required this.authorUserId,
    required this.authorRole,
    required this.message,
    required this.createdAt,
  });

  factory ProductionComment.fromJson(Map<String, dynamic> j) => ProductionComment(
        id: (j['id'] ?? '').toString(),
        orderItemId: (j['order_item_id'] ?? '').toString(),
        authorUserId: (j['author_user_id'] ?? '').toString(),
        authorRole: (j['author_role'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

class ProductionFile {
  final String id;
  final String orderItemId;
  final String uploadedBy;
  final String kind;
  final String fileName;
  final String mimeType;
  final String bucket;
  final String path;
  final int? sizeBytes;
  final DateTime? createdAt;

  const ProductionFile({
    required this.id,
    required this.orderItemId,
    required this.uploadedBy,
    required this.kind,
    required this.fileName,
    required this.mimeType,
    required this.bucket,
    required this.path,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory ProductionFile.fromJson(Map<String, dynamic> j) => ProductionFile(
        id: (j['id'] ?? '').toString(),
        orderItemId: (j['order_item_id'] ?? '').toString(),
        uploadedBy: (j['uploaded_by'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString(),
        fileName: (j['file_name'] ?? '').toString(),
        mimeType: (j['mime_type'] ?? '').toString(),
        bucket: (j['storage_bucket'] ?? 'production').toString(),
        path: (j['storage_path'] ?? '').toString(),
        sizeBytes: j['size_bytes'] is num ? (j['size_bytes'] as num).toInt() : null,
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

class ProductionEvent {
  final String id;
  final String orderItemId;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  const ProductionEvent({
    required this.id,
    required this.orderItemId,
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  factory ProductionEvent.fromJson(Map<String, dynamic> j) => ProductionEvent(
        id: (j['id'] ?? '').toString(),
        orderItemId: (j['order_item_id'] ?? '').toString(),
        eventType: (j['event_type'] ?? '').toString(),
        payload: (j['payload'] is Map<String, dynamic>) ? (j['payload'] as Map<String, dynamic>) : const {},
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

class ProductionDashboard {
  final List<ProductionOrder> orders;
  final List<ProductionOrderItem> items;
  final Map<String, String> releaseTitleById;
  final Map<String, String?> releaseCoverById;

  const ProductionDashboard({
    required this.orders,
    required this.items,
    required this.releaseTitleById,
    required this.releaseCoverById,
  });
}

String productionStatusLabel(String status) {
  switch (status) {
    case 'not_started':
      return 'Не начато';
    case 'waiting_artist':
      return 'Ожидает от тебя';
    case 'in_progress':
      return 'В работе';
    case 'review':
      return 'На проверке';
    case 'done':
      return 'Готово';
    case 'canceled':
      return 'Отменено';
    default:
      return status;
  }
}
