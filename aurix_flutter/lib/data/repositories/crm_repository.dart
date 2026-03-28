import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/data/models/crm_models.dart';

class CrmLeadsFilter {
  const CrmLeadsFilter({
    this.stage = 'all',
    this.assignedTo = 'all',
    this.source = 'all',
    this.priority = 'all',
    this.search = '',
  });

  final String stage;
  final String assignedTo;
  final String source;
  final String priority;
  final String search;
}

class CrmRepository {
  Future<List<CrmLeadModel>> _parseLeads(List data) async {
    return data
        .cast<Map<String, dynamic>>()
        .map(CrmLeadModel.fromJson)
        .toList();
  }

  Future<List<CrmLeadModel>> getLeads({
    CrmLeadsFilter filter = const CrmLeadsFilter(),
  }) async {
    final res = await ApiClient.get('/crm-leads', query: {
      'order': 'created_at.desc',
    });
    var rows = await _parseLeads(asList(res.data));

    if (filter.stage != 'all') {
      rows = rows.where((r) => r.pipelineStage == filter.stage).toList();
    }
    if (filter.assignedTo != 'all') {
      rows = rows.where((r) => r.assignedTo == filter.assignedTo).toList();
    }
    if (filter.source != 'all') {
      rows = rows.where((r) => r.source == filter.source).toList();
    }
    if (filter.priority != 'all') {
      rows = rows.where((r) => r.priority == filter.priority).toList();
    }
    final q = filter.search.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where((r) =>
              (r.title ?? '').toLowerCase().contains(q) ||
              (r.description ?? '').toLowerCase().contains(q) ||
              (r.type ?? '').toLowerCase().contains(q))
          .toList();
    }
    return rows;
  }

  Future<List<CrmLeadModel>> getMyLeads() async {
    final res = await ApiClient.get('/crm-leads', query: {
      'order': 'created_at.desc',
    });
    return _parseLeads(asList(res.data));
  }

  Future<List<CrmLeadModel>> getLeadsByUser(String userId) async {
    if (userId.isEmpty) return const [];
    final res = await ApiClient.get('/crm-leads', query: {
      'user_id': userId,
      'order': 'created_at.desc',
    });
    return _parseLeads(asList(res.data));
  }

  Future<void> updateLead({
    required String leadId,
    String? stage,
    String? assignedTo,
    String? priority,
    DateTime? dueAt,
    String? title,
    String? description,
  }) async {
    final payload = <String, dynamic>{};
    if (stage != null) payload['pipeline_stage'] = stage;
    if (assignedTo != null) {
      payload['assigned_to'] = assignedTo.isEmpty ? null : assignedTo;
    }
    if (priority != null) payload['priority'] = priority;
    if (title != null) payload['title'] = title;
    if (description != null) payload['description'] = description;
    if (dueAt != null) payload['due_at'] = dueAt.toIso8601String();
    if (payload.isEmpty) return;
    await ApiClient.put('/crm-leads/$leadId', data: payload);
    await addEvent(
      leadId: leadId,
      eventType: 'lead_updated',
      payload: payload,
    );
  }

  Future<CrmDealModel> createDealFromLead({
    required CrmLeadModel lead,
    String status = 'draft',
  }) async {
    final payload = {
      'user_id': lead.userId,
      'release_id': lead.releaseId,
      'lead_id': lead.id,
      'status': status,
      'package_title': lead.title ?? lead.type ?? 'Сделка по лиду',
    };
    final res = await ApiClient.post('/crm-deals', data: payload);
    final row = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    await addEvent(
      leadId: lead.id,
      dealId: (row['id'] ?? '').toString(),
      eventType: 'deal_created',
      payload: {'status': status},
    );
    return CrmDealModel.fromJson(row);
  }

  Future<List<CrmDealModel>> getDeals() async {
    final res = await ApiClient.get('/crm-deals', query: {
      'order': 'created_at.desc',
    });
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmDealModel.fromJson)
        .toList();
  }

  Future<List<CrmDealModel>> getDealsByUser(String userId) async {
    if (userId.isEmpty) return const [];
    final res = await ApiClient.get('/crm-deals', query: {
      'user_id': userId,
      'order': 'created_at.desc',
    });
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmDealModel.fromJson)
        .toList();
  }

  Future<void> updateDealStatus({
    required String dealId,
    required String status,
  }) async {
    await ApiClient.put('/crm-deals/$dealId', data: {'status': status});
    await addEvent(
      dealId: dealId,
      eventType: 'deal_status_changed',
      payload: {'status': status},
    );
  }

  Future<List<CrmTaskModel>> getTasks() async {
    final res = await ApiClient.get('/crm-tasks', query: {
      'order': 'due_at.asc,created_at.desc',
    });
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmTaskModel.fromJson)
        .toList();
  }

  Future<List<CrmTaskModel>> getTasksForUser(String userId) async {
    if (userId.isEmpty) return const [];
    final leadIdsRes = await ApiClient.get('/crm-leads', query: {
      'user_id': userId,
      'select': 'id',
    });
    final dealIdsRes = await ApiClient.get('/crm-deals', query: {
      'user_id': userId,
      'select': 'id',
    });
    final leadIdValues = asList(leadIdsRes.data)
        .cast<Map<String, dynamic>>()
        .map((x) => (x['id'] ?? '').toString())
        .where((x) => x.isNotEmpty)
        .toList();
    final dealIdValues = asList(dealIdsRes.data)
        .cast<Map<String, dynamic>>()
        .map((x) => (x['id'] ?? '').toString())
        .where((x) => x.isNotEmpty)
        .toList();
    if (leadIdValues.isEmpty && dealIdValues.isEmpty) return const [];

    final rows = <Map<String, dynamic>>[];
    if (leadIdValues.isNotEmpty) {
      final byLead = await ApiClient.get('/crm-tasks', query: {
        'lead_id_in': leadIdValues.join(','),
      });
      rows.addAll(asList(byLead.data).cast<Map<String, dynamic>>());
    }
    if (dealIdValues.isNotEmpty) {
      final byDeal = await ApiClient.get('/crm-tasks', query: {
        'deal_id_in': dealIdValues.join(','),
      });
      rows.addAll(asList(byDeal.data).cast<Map<String, dynamic>>());
    }
    final uniq = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;
      uniq[id] = row;
    }
    return uniq.values.map(CrmTaskModel.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> createTask({
    String? leadId,
    String? dealId,
    required String title,
    required String assignedTo,
    DateTime? dueAt,
  }) async {
    await ApiClient.post('/crm-tasks', data: {
      'lead_id': leadId,
      'deal_id': dealId,
      'title': title,
      'assigned_to': assignedTo,
      'status': 'open',
      if (dueAt != null) 'due_at': dueAt.toIso8601String(),
    });
  }

  Future<void> setTaskStatus({
    required String taskId,
    required String status,
  }) async {
    await ApiClient.put('/crm-tasks/$taskId', data: {'status': status});
  }

  Future<List<CrmNoteModel>> getNotes({
    String? leadId,
    String? dealId,
  }) async {
    if ((leadId == null || leadId.isEmpty) &&
        (dealId == null || dealId.isEmpty)) {
      return const [];
    }
    final query = <String, dynamic>{
      'order': 'created_at.desc',
    };
    if (leadId != null && leadId.isNotEmpty) {
      query['lead_id'] = leadId;
    } else {
      query['deal_id'] = dealId ?? '';
    }
    final res = await ApiClient.get('/crm-notes', query: query);
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmNoteModel.fromJson)
        .toList();
  }

  Future<List<CrmNoteModel>> getNotesByUser(String userId) async {
    if (userId.isEmpty) return const [];
    final res = await ApiClient.get('/crm-notes', query: {
      'user_id': userId,
      'order': 'created_at.desc',
    });
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmNoteModel.fromJson)
        .toList();
  }

  Future<void> addNote({
    required String userId,
    required String authorId,
    String? leadId,
    String? dealId,
    required String message,
  }) async {
    await ApiClient.post('/crm-notes', data: {
      'user_id': userId,
      'author_id': authorId,
      'lead_id': leadId,
      'deal_id': dealId,
      'message': message,
    });
    await addEvent(
      leadId: leadId,
      dealId: dealId,
      eventType: 'note_added',
      payload: {'message': message},
    );
  }

  Future<List<CrmEventModel>> getEvents({
    String? leadId,
    String? dealId,
  }) async {
    if ((leadId == null || leadId.isEmpty) &&
        (dealId == null || dealId.isEmpty)) {
      return const [];
    }
    final query = <String, dynamic>{
      'order': 'created_at.desc',
    };
    if (leadId != null && leadId.isNotEmpty) {
      query['lead_id'] = leadId;
    } else {
      query['deal_id'] = dealId ?? '';
    }
    final res = await ApiClient.get('/crm-events', query: query);
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmEventModel.fromJson)
        .toList();
  }

  Future<List<CrmEventModel>> getEventsByUser(String userId) async {
    if (userId.isEmpty) return const [];
    final leads = await getLeadsByUser(userId);
    final deals = await getDealsByUser(userId);
    final leadIds = leads.map((x) => x.id).toList();
    final dealIds = deals.map((x) => x.id).toList();
    if (leadIds.isEmpty && dealIds.isEmpty) return const [];
    final rows = <Map<String, dynamic>>[];
    if (leadIds.isNotEmpty) {
      final byLead = await ApiClient.get('/crm-events', query: {
        'lead_id_in': leadIds.join(','),
      });
      rows.addAll(asList(byLead.data).cast<Map<String, dynamic>>());
    }
    if (dealIds.isNotEmpty) {
      final byDeal = await ApiClient.get('/crm-events', query: {
        'deal_id_in': dealIds.join(','),
      });
      rows.addAll(asList(byDeal.data).cast<Map<String, dynamic>>());
    }
    final uniq = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;
      uniq[id] = row;
    }
    return uniq.values.map(CrmEventModel.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> addEvent({
    String? leadId,
    String? dealId,
    required String eventType,
    Map<String, dynamic> payload = const {},
  }) async {
    await ApiClient.post('/crm-events', data: {
      'lead_id': leadId,
      'deal_id': dealId,
      'event_type': eventType,
      'payload': payload,
    });
  }

  Future<List<CrmInvoiceModel>> getInvoices({String? dealId}) async {
    final query = <String, dynamic>{
      'order': 'created_at.desc',
    };
    if (dealId != null && dealId.isNotEmpty) {
      query['deal_id'] = dealId;
    }
    final res = await ApiClient.get('/crm-invoices', query: query);
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmInvoiceModel.fromJson)
        .toList();
  }

  Future<List<CrmInvoiceModel>> getInvoicesByUser(String userId) async {
    if (userId.isEmpty) return const [];
    final res = await ApiClient.get('/crm-invoices', query: {
      'user_id': userId,
      'order': 'created_at.desc',
    });
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmInvoiceModel.fromJson)
        .toList();
  }

  Future<CrmInvoiceModel> upsertInvoice({
    String? id,
    required String dealId,
    required String userId,
    required double amount,
    String currency = 'RUB',
    String status = 'draft',
    DateTime? dueAt,
    DateTime? paidAt,
    String? externalRef,
    Map<String, dynamic> meta = const {},
  }) async {
    final payload = <String, dynamic>{
      if (id != null && id.isNotEmpty) 'id': id,
      'deal_id': dealId,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'due_at': dueAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'external_ref': externalRef,
      'meta': meta,
    };
    final res = await ApiClient.put('/crm-invoices', data: payload);
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return CrmInvoiceModel.fromJson(body);
  }

  Future<List<CrmTransactionModel>> getTransactions({
    String? invoiceId,
  }) async {
    final query = <String, dynamic>{
      'order': 'created_at.desc',
    };
    if (invoiceId != null && invoiceId.isNotEmpty) {
      query['invoice_id'] = invoiceId;
    }
    final res = await ApiClient.get('/crm-transactions', query: query);
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmTransactionModel.fromJson)
        .toList();
  }

  Future<List<CrmTransactionModel>> getTransactionsByUser(String userId) async {
    if (userId.isEmpty) return const [];
    final res = await ApiClient.get('/crm-transactions', query: {
      'user_id': userId,
      'order': 'created_at.desc',
    });
    return asList(res.data)
        .cast<Map<String, dynamic>>()
        .map(CrmTransactionModel.fromJson)
        .toList();
  }

  Future<CrmTransactionModel> addTransaction({
    required String invoiceId,
    required String userId,
    required double amount,
    String provider = 'manual',
    String status = 'pending',
    DateTime? paidAt,
    Map<String, dynamic> payload = const {},
  }) async {
    final res = await ApiClient.post('/crm-transactions', data: {
      'invoice_id': invoiceId,
      'user_id': userId,
      'amount': amount,
      'provider': provider,
      'status': status,
      'paid_at': paidAt?.toIso8601String(),
      'payload': payload,
    });
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return CrmTransactionModel.fromJson(body);
  }

  Future<CrmArtistProfileSnapshot> getArtistSnapshot(String userId) async {
    final leads = await getLeadsByUser(userId);
    final deals = await getDealsByUser(userId);
    final tasks = await getTasksForUser(userId);
    final notes = await getNotesByUser(userId);
    final events = await getEventsByUser(userId);
    final invoices = await getInvoicesByUser(userId);
    final tx = await getTransactionsByUser(userId);
    return CrmArtistProfileSnapshot(
      userId: userId,
      leads: leads,
      deals: deals,
      tasks: tasks,
      notes: notes,
      events: events,
      invoices: invoices,
      transactions: tx,
    );
  }
}
