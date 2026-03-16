class CrmLeadModel {
  const CrmLeadModel({
    required this.id,
    required this.userId,
    this.releaseId,
    required this.source,
    this.type,
    required this.pipelineStage,
    required this.priority,
    this.assignedTo,
    this.dueAt,
    this.title,
    this.description,
    this.promoRequestId,
    this.supportTicketId,
    this.productionOrderId,
    this.productionItemId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? releaseId;
  final String source;
  final String? type;
  final String pipelineStage;
  final String priority;
  final String? assignedTo;
  final DateTime? dueAt;
  final String? title;
  final String? description;
  final String? promoRequestId;
  final String? supportTicketId;
  final String? productionOrderId;
  final String? productionItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CrmLeadModel.fromJson(Map<String, dynamic> json) {
    return CrmLeadModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      releaseId: (json['release_id'])?.toString(),
      source: (json['source'] ?? '').toString(),
      type: (json['type'])?.toString(),
      pipelineStage: (json['pipeline_stage'] ?? 'new').toString(),
      priority: (json['priority'] ?? 'normal').toString(),
      assignedTo: (json['assigned_to'])?.toString(),
      dueAt: DateTime.tryParse((json['due_at'] ?? '').toString()),
      title: (json['title'])?.toString(),
      description: (json['description'])?.toString(),
      promoRequestId: (json['promo_request_id'])?.toString(),
      supportTicketId: (json['support_ticket_id'])?.toString(),
      productionOrderId: (json['production_order_id'])?.toString(),
      productionItemId: (json['production_item_id'])?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class CrmDealModel {
  const CrmDealModel({
    required this.id,
    required this.userId,
    this.releaseId,
    this.leadId,
    required this.status,
    this.amount,
    required this.currency,
    this.packageTitle,
    this.startedAt,
    this.deadlineAt,
    this.productionOrderId,
    this.productionItemId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? releaseId;
  final String? leadId;
  final String status;
  final double? amount;
  final String currency;
  final String? packageTitle;
  final DateTime? startedAt;
  final DateTime? deadlineAt;
  final String? productionOrderId;
  final String? productionItemId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CrmDealModel.fromJson(Map<String, dynamic> json) {
    final amountValue = json['amount'];
    return CrmDealModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      releaseId: (json['release_id'])?.toString(),
      leadId: (json['lead_id'])?.toString(),
      status: (json['status'] ?? 'draft').toString(),
      amount: amountValue == null ? null : double.tryParse('$amountValue'),
      currency: (json['currency'] ?? 'RUB').toString(),
      packageTitle: (json['package_title'])?.toString(),
      startedAt: DateTime.tryParse((json['started_at'] ?? '').toString()),
      deadlineAt: DateTime.tryParse((json['deadline_at'] ?? '').toString()),
      productionOrderId: (json['production_order_id'])?.toString(),
      productionItemId: (json['production_item_id'])?.toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class CrmTaskModel {
  const CrmTaskModel({
    required this.id,
    this.leadId,
    this.dealId,
    this.assignedTo,
    required this.title,
    required this.status,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? leadId;
  final String? dealId;
  final String? assignedTo;
  final String title;
  final String status;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CrmTaskModel.fromJson(Map<String, dynamic> json) {
    return CrmTaskModel(
      id: (json['id'] ?? '').toString(),
      leadId: (json['lead_id'])?.toString(),
      dealId: (json['deal_id'])?.toString(),
      assignedTo: (json['assigned_to'])?.toString(),
      title: (json['title'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      dueAt: DateTime.tryParse((json['due_at'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class CrmNoteModel {
  const CrmNoteModel({
    required this.id,
    required this.userId,
    this.leadId,
    this.dealId,
    required this.authorId,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String? leadId;
  final String? dealId;
  final String authorId;
  final String message;
  final DateTime createdAt;

  factory CrmNoteModel.fromJson(Map<String, dynamic> json) {
    return CrmNoteModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      leadId: (json['lead_id'])?.toString(),
      dealId: (json['deal_id'])?.toString(),
      authorId: (json['author_id'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class CrmEventModel {
  const CrmEventModel({
    required this.id,
    this.leadId,
    this.dealId,
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String? leadId;
  final String? dealId;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory CrmEventModel.fromJson(Map<String, dynamic> json) {
    return CrmEventModel(
      id: (json['id'] ?? '').toString(),
      leadId: (json['lead_id'])?.toString(),
      dealId: (json['deal_id'])?.toString(),
      eventType: (json['event_type'] ?? '').toString(),
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class CrmInvoiceModel {
  const CrmInvoiceModel({
    required this.id,
    required this.dealId,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.status,
    this.dueAt,
    this.paidAt,
    this.externalRef,
    required this.meta,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String dealId;
  final String userId;
  final double amount;
  final String currency;
  final String status;
  final DateTime? dueAt;
  final DateTime? paidAt;
  final String? externalRef;
  final Map<String, dynamic> meta;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CrmInvoiceModel.fromJson(Map<String, dynamic> json) {
    return CrmInvoiceModel(
      id: (json['id'] ?? '').toString(),
      dealId: (json['deal_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      currency: (json['currency'] ?? 'RUB').toString(),
      status: (json['status'] ?? 'draft').toString(),
      dueAt: DateTime.tryParse((json['due_at'] ?? '').toString()),
      paidAt: DateTime.tryParse((json['paid_at'] ?? '').toString()),
      externalRef: (json['external_ref'])?.toString(),
      meta: (json['meta'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class CrmTransactionModel {
  const CrmTransactionModel({
    required this.id,
    required this.invoiceId,
    required this.userId,
    required this.amount,
    required this.provider,
    required this.status,
    this.paidAt,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String invoiceId;
  final String userId;
  final double amount;
  final String provider;
  final String status;
  final DateTime? paidAt;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory CrmTransactionModel.fromJson(Map<String, dynamic> json) {
    return CrmTransactionModel(
      id: (json['id'] ?? '').toString(),
      invoiceId: (json['invoice_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      provider: (json['provider'] ?? 'manual').toString(),
      status: (json['status'] ?? 'pending').toString(),
      paidAt: DateTime.tryParse((json['paid_at'] ?? '').toString()),
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class CrmArtistProfileSnapshot {
  const CrmArtistProfileSnapshot({
    required this.userId,
    required this.leads,
    required this.deals,
    required this.tasks,
    required this.notes,
    required this.events,
    required this.invoices,
    required this.transactions,
  });

  final String userId;
  final List<CrmLeadModel> leads;
  final List<CrmDealModel> deals;
  final List<CrmTaskModel> tasks;
  final List<CrmNoteModel> notes;
  final List<CrmEventModel> events;
  final List<CrmInvoiceModel> invoices;
  final List<CrmTransactionModel> transactions;

  double get totalInvoiced =>
      invoices.fold(0, (sum, row) => sum + row.amount);
  double get totalPaid => invoices
      .where((row) => row.status == 'paid')
      .fold(0, (sum, row) => sum + row.amount);
}
