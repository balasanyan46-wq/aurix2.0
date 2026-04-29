import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/models/admin_log_model.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/release_delete_request_model.dart';
import 'package:aurix_flutter/data/models/billing_subscription_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

String humanizeApiError(Object e) {
  final msg = e.toString();
  if (msg.contains('permission denied') ||
      msg.contains('row-level security') ||
      msg.contains('RLS') ||
      msg.contains('401') ||
      msg.contains('403') ||
      msg.contains('JWTExpired') ||
      msg.contains('new row violates row-level security')) {
    return 'Нет доступа. Проверь role в profiles = admin.';
  }
  if (msg.contains('relation') && msg.contains('does not exist')) {
    return 'Таблица не найдена. Выполните SQL-миграцию.';
  }
  if (msg.contains('Failed host lookup') || msg.contains('SocketException') || msg.contains('Connection')) {
    return 'Нет связи с сервером. Проверьте интернет.';
  }
  final short = msg.length > 120 ? '${msg.substring(0, 117)}...' : msg;
  return 'Ошибка: $short';
}

final allProfilesProvider = FutureProvider<List<ProfileModel>>((ref) async {
  try {
    return await ref.read(profileRepositoryProvider).getAllProfiles();
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final allReleasesAdminProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  try {
    return await ref.read(releaseRepositoryProvider).getAllReleases();
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final allReportRowsProvider = FutureProvider<List<ReportRowModel>>((ref) async {
  try {
    return await ref.read(reportRepositoryProvider).getAllReportRows();
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final adminReportsProvider = FutureProvider<List<ReportModel>>((ref) async {
  try {
    return await ref.read(reportRepositoryProvider).getReports();
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final adminLogsProvider = FutureProvider<List<AdminLogModel>>((ref) async {
  try {
    return await ref.read(adminLogRepositoryProvider).getLogs(limit: 100);
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final allTicketsProvider = FutureProvider<List<SupportTicketModel>>((ref) async {
  try {
    return await ref.read(supportTicketRepositoryProvider).getAllTickets();
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final allReleaseDeleteRequestsProvider = FutureProvider<List<ReleaseDeleteRequestModel>>((ref) async {
  try {
    return await ref.read(releaseDeleteRequestRepositoryProvider).getAllRequests();
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final adminBillingSubscriptionsProvider =
    FutureProvider<List<BillingSubscriptionModel>>((ref) async {
  try {
    return await ref.read(billingSubscriptionRepositoryProvider).getAll();
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

/// Shared status filter for AdminReleasesTab.
/// Dashboard sets this before switching to the releases tab.
final adminReleasesFilterProvider = StateProvider<String>((ref) => 'all');

class AdminOpsSnapshot {
  final int deleteRequestsPending;
  final int productionOverdue;
  final int supportOverdue;
  final int reportsNotReady;

  const AdminOpsSnapshot({
    required this.deleteRequestsPending,
    required this.productionOverdue,
    required this.supportOverdue,
    required this.reportsNotReady,
  });
}

final adminOpsSnapshotProvider = FutureProvider<AdminOpsSnapshot>((ref) async {
  try {
    final res = await ApiClient.get('/admin/ops-snapshot');
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final snap = body['snapshot'] is Map ? Map<String, dynamic>.from(body['snapshot'] as Map) : <String, dynamic>{};
    return AdminOpsSnapshot(
      deleteRequestsPending: snap['delete_requests_pending'] as int? ?? 0,
      productionOverdue: snap['production_overdue'] as int? ?? 0,
      supportOverdue: snap['support_overdue'] as int? ?? 0,
      reportsNotReady: snap['reports_not_ready'] as int? ?? 0,
    );
  } catch (_) {
    return const AdminOpsSnapshot(
      deleteRequestsPending: 0,
      productionOverdue: 0,
      supportOverdue: 0,
      reportsNotReady: 0,
    );
  }
});

// ── Enhanced dashboard data ────────────────────────────────

class AdminDashboardData {
  final int totalUsers;
  final int totalReleases;
  final int openTickets;
  final int activeOrders;
  final int newUsers30d;
  final int events24h;
  final List<Map<String, dynamic>> releasesByStatus;
  final List<Map<String, dynamic>> recentUsers;
  final List<Map<String, dynamic>> recentAdminActions;
  final List<Map<String, dynamic>> usersByPlan;
  final List<Map<String, dynamic>> dau7d;

  const AdminDashboardData({
    this.totalUsers = 0,
    this.totalReleases = 0,
    this.openTickets = 0,
    this.activeOrders = 0,
    this.newUsers30d = 0,
    this.events24h = 0,
    this.releasesByStatus = const [],
    this.recentUsers = const [],
    this.recentAdminActions = const [],
    this.usersByPlan = const [],
    this.dau7d = const [],
  });
}

final adminDashboardProvider = FutureProvider<AdminDashboardData>((ref) async {
  try {
    final res = await ApiClient.get('/admin/dashboard');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return AdminDashboardData(
      totalUsers: d['total_users'] as int? ?? 0,
      totalReleases: d['total_releases'] as int? ?? 0,
      openTickets: d['open_tickets'] as int? ?? 0,
      activeOrders: d['active_orders'] as int? ?? 0,
      newUsers30d: d['new_users_30d'] as int? ?? 0,
      events24h: d['events_24h'] as int? ?? 0,
      releasesByStatus: (d['releases_by_status'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      recentUsers: (d['recent_users'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      recentAdminActions: (d['recent_admin_actions'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      usersByPlan: (d['users_by_plan'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      dau7d: (d['dau_7d'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

// ── User events / timeline ────────────────────────────────

final adminUserEventsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/user-events/timeline', query: {'user_id': userId.toString(), 'limit': '100'});
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

final adminUserDetailProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/users/$userId');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (e) {
    throw Exception(humanizeApiError(e));
  }
});

// ── User AI Studio messages (admin) ───────────────────────

final adminUserAiMessagesProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/users/$userId/ai-messages', query: {'limit': '200'});
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

// ── DAU / MAU stats ────────────────────────────────────────

final adminDauProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/stats/dau', query: {'days': '30'});
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

final adminEventsBreakdownProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/stats/events-breakdown', query: {'days': '30'});
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

// ── AI insights ────────────────────────────────────────────

class AiInsightsData {
  final String insights;
  final String stats;
  const AiInsightsData({this.insights = '', this.stats = ''});
}

final adminAiInsightsProvider = FutureProvider<AiInsightsData>((ref) async {
  try {
    final res = await ApiClient.dio.get('/admin/ai-insights',
        options: Options(receiveTimeout: const Duration(seconds: 60)));
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return AiInsightsData(
      insights: d['insights']?.toString() ?? '',
      stats: d['stats']?.toString() ?? '',
    );
  } catch (_) {
    return AiInsightsData(insights: 'AI анализ временно недоступен. Нажмите обновить.');
  }
});

// ── AI actions (operator suggestions) ──────────────────────

class AiActionsData {
  final List<Map<String, dynamic>> actions;
  final String context;
  final String? error;
  const AiActionsData({this.actions = const [], this.context = '', this.error});
}

final adminAiActionsProvider = FutureProvider<AiActionsData>((ref) async {
  try {
    final res = await ApiClient.dio.get('/admin/ai-actions',
        options: Options(receiveTimeout: const Duration(seconds: 60)));
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return AiActionsData(
      actions: (d['actions'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      context: d['context']?.toString() ?? '',
      error: d['error']?.toString(),
    );
  } catch (_) {
    return AiActionsData(error: 'AI оператор временно недоступен');
  }
});

// ── Auto-actions CRUD ──────────────────────────────────────

final adminAutoActionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/auto-actions');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

final adminAutoActionLogProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/auto-actions/log');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

// ── Notifications (admin) ──────────────────────────────────

final adminNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/notifications');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

// ── Sessions (admin) ───────────────────────────────────────

final adminUserSessionsProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/sessions/user/$userId');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

final adminSessionReplayProvider = FutureProvider.family<List<Map<String, dynamic>>, int>((ref, sessionId) async {
  try {
    final res = await ApiClient.get('/admin/sessions/$sessionId/replay');
    // Backend returns { session: {...}, events: [...] }.
    final data = res.data;
    if (data is Map && data['events'] is List) {
      return (data['events'] as List).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  } catch (e) {
    return [];
  }
});

/// Activity summary for a user (admin): totals, top screens, top actions, daily histogram.
final adminUserActivitySummaryProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/users/$userId/activity-summary');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (e) {
    return <String, dynamic>{};
  }
});

/// Last session for a user with all its events — "что делал последний раз".
final adminUserLastSessionProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/users/$userId/last-session');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (e) {
    return <String, dynamic>{};
  }
});

final adminSessionStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/sessions/stats');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (e) {
    return {};
  }
});

// ── Billing admin ──────────────────────────────────────────

final adminBillingStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/billing/stats');
    return res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  } catch (e) {
    return {};
  }
});

final adminBillingTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/billing/transactions');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
  }
});

final adminUserBalanceProvider = FutureProvider.family<int, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/billing/balance/$userId');
    final bd = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return bd['balance'] as int? ?? 0;
  } catch (e) {
    return 0;
  }
});

// ── Dashboard signals (real-time business intelligence) ───

class AdminSignal {
  final String type; // risk, money, growth
  final String message;
  final String? userId;
  final String priority; // high, medium, low

  const AdminSignal({required this.type, required this.message, this.userId, required this.priority});

  factory AdminSignal.fromJson(Map<String, dynamic> json) => AdminSignal(
    type: json['type']?.toString() ?? 'risk',
    message: json['message']?.toString() ?? '',
    userId: json['userId']?.toString(),
    priority: json['priority']?.toString() ?? 'low',
  );
}

class AdminSignalsData {
  final List<AdminSignal> signals;
  final List<Map<String, dynamic>> monetizationTargets;
  final List<Map<String, dynamic>> retentionTargets;
  final List<Map<String, dynamic>> fraudAlerts;

  const AdminSignalsData({
    this.signals = const [],
    this.monetizationTargets = const [],
    this.retentionTargets = const [],
    this.fraudAlerts = const [],
  });
}

final adminSignalsProvider = FutureProvider<AdminSignalsData>((ref) async {
  try {
    final res = await ApiClient.get('/admin/dashboard/signals');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return AdminSignalsData(
      signals: (d['signals'] as List?)?.map((s) => AdminSignal.fromJson(s as Map<String, dynamic>)).toList() ?? [],
      monetizationTargets: (d['monetization_targets'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      retentionTargets: (d['retention_targets'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      fraudAlerts: (d['fraud_alerts'] as List?)?.cast<Map<String, dynamic>>() ?? [],
    );
  } catch (e) {
    return const AdminSignalsData();
  }
});

// ════════════════════════════════════════════════════════════════════════
//  ACTION CENTER — единый "что сделать сегодня"
//  Источник: GET /admin/action-center
// ════════════════════════════════════════════════════════════════════════

class ActionItem {
  final String id;
  final String type;
  final String priority; // critical | high | medium | low
  final String title;
  final String description;
  final int? userId;
  final String suggestedAction;
  // Этап 5: интеграция с next_action и AI sales.
  final String? nextAction;
  final String? suggestedMessage;
  final int possibleRevenue;
  final String? productOffer;
  final String? createdAt;
  final String source;

  const ActionItem({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.suggestedAction,
    required this.source,
    this.userId,
    this.nextAction,
    this.suggestedMessage,
    this.possibleRevenue = 0,
    this.productOffer,
    this.createdAt,
  });

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
        id: j['id']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        priority: j['priority']?.toString() ?? 'low',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        userId: (j['user_id'] as num?)?.toInt(),
        suggestedAction: j['suggested_action']?.toString() ?? '',
        nextAction: j['next_action']?.toString(),
        suggestedMessage: j['suggested_message']?.toString(),
        possibleRevenue: (j['possible_revenue'] as num?)?.toInt() ?? 0,
        productOffer: j['product_offer']?.toString(),
        createdAt: j['created_at']?.toString(),
        source: j['source']?.toString() ?? '',
      );
}

class ActionCenterData {
  final int total;
  final int possibleRevenueTotal;
  final List<ActionItem> items;
  final List<ActionItem> urgent;
  final List<ActionItem> money;
  final List<ActionItem> releases;
  final List<ActionItem> support;
  final List<ActionItem> retention;
  final List<ActionItem> risks;

  const ActionCenterData({
    required this.total,
    required this.items,
    required this.urgent,
    required this.money,
    required this.releases,
    required this.support,
    required this.retention,
    required this.risks,
    this.possibleRevenueTotal = 0,
  });

  static const empty = ActionCenterData(
    total: 0, possibleRevenueTotal: 0, items: [], urgent: [], money: [],
    releases: [], support: [], retention: [], risks: [],
  );
}

final adminActionCenterProvider = FutureProvider<ActionCenterData>((ref) async {
  try {
    final res = await ApiClient.get('/admin/action-center');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    List<ActionItem> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => ActionItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final groups = (d['groups'] as Map?) ?? const {};
    return ActionCenterData(
      total: (d['total'] as num?)?.toInt() ?? 0,
      possibleRevenueTotal: (d['possible_revenue_total'] as num?)?.toInt() ?? 0,
      items: parseList(d['items']),
      urgent: parseList(groups['urgent']),
      money: parseList(groups['money']),
      releases: parseList(groups['releases']),
      support: parseList(groups['support']),
      retention: parseList(groups['retention']),
      risks: parseList(groups['risks']),
    );
  } catch (e) {
    return ActionCenterData.empty;
  }
});

// ════════════════════════════════════════════════════════════════════════
//  LEAD SCORING
//  GET /admin/users/:id/score      — score конкретного юзера
//  GET /admin/leads?bucket=hot     — список по bucket
//  POST /admin/leads/recalculate   — пересчёт всех
// ════════════════════════════════════════════════════════════════════════

class LeadScore {
  final int userId;
  final int score;
  final String bucket; // cold | warm | hot
  final List<Map<String, dynamic>> reasons;
  final String? updatedAt;

  const LeadScore({
    required this.userId,
    required this.score,
    required this.bucket,
    required this.reasons,
    this.updatedAt,
  });

  factory LeadScore.fromJson(Map<String, dynamic> j) => LeadScore(
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toInt() ?? 0,
        bucket: j['bucket']?.toString() ?? 'cold',
        reasons: (j['reasons'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [],
        updatedAt: j['updated_at']?.toString(),
      );
}

final adminUserScoreProvider =
    FutureProvider.family<LeadScore?, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/users/$userId/score');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return LeadScore.fromJson(d);
  } catch (e) {
    return null;
  }
});

final adminLeadsByBucketProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bucket) async {
  try {
    final res = await ApiClient.get('/admin/leads', query: {'bucket': bucket});
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = d['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } catch (e) {
    return const [];
  }
});

// ════════════════════════════════════════════════════════════════════════
//  LEADS PIPELINE (новая таблица leads — этап 1 sales-генерации выручки)
//  GET /admin/leads?status=&bucket=&assigned_to=
//  PATCH /admin/leads/:id
//  POST /admin/leads/:id/contacted
// ════════════════════════════════════════════════════════════════════════

class LeadRow {
  final String id;
  final int userId;
  final String? email;
  final String? displayName;
  final int leadScore;
  final String leadBucket;
  final String status;
  final int? assignedTo;
  final String? lastContactAt;
  final String? nextAction;
  final String source;
  final String createdAt;
  final String updatedAt;

  const LeadRow({
    required this.id,
    required this.userId,
    required this.leadScore,
    required this.leadBucket,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.email,
    this.displayName,
    this.assignedTo,
    this.lastContactAt,
    this.nextAction,
  });

  factory LeadRow.fromJson(Map<String, dynamic> j) => LeadRow(
        id: j['id']?.toString() ?? '',
        userId: (j['user_id'] as num?)?.toInt() ?? 0,
        email: j['email']?.toString(),
        displayName: j['display_name']?.toString(),
        leadScore: (j['lead_score'] as num?)?.toInt() ?? 0,
        leadBucket: j['lead_bucket']?.toString() ?? 'cold',
        status: j['status']?.toString() ?? 'new',
        assignedTo: (j['assigned_to'] as num?)?.toInt(),
        lastContactAt: j['last_contact_at']?.toString(),
        nextAction: j['next_action']?.toString(),
        source: j['source']?.toString() ?? 'system',
        createdAt: j['created_at']?.toString() ?? '',
        updatedAt: j['updated_at']?.toString() ?? '',
      );
}

class LeadsFilter {
  final String? status;
  final String? bucket;
  final int? assignedTo;
  const LeadsFilter({this.status, this.bucket, this.assignedTo});

  @override
  bool operator ==(Object other) =>
      other is LeadsFilter &&
      other.status == status &&
      other.bucket == bucket &&
      other.assignedTo == assignedTo;
  @override
  int get hashCode => Object.hash(status, bucket, assignedTo);
}

final adminLeadsListProvider =
    FutureProvider.family<List<LeadRow>, LeadsFilter>((ref, filter) async {
  final query = <String, dynamic>{};
  if (filter.status != null) query['status'] = filter.status;
  if (filter.bucket != null) query['bucket'] = filter.bucket;
  if (filter.assignedTo != null) query['assigned_to'] = filter.assignedTo;
  try {
    final res = await ApiClient.get('/admin/leads', query: query);
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = d['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => LeadRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (e) {
    return const [];
  }
});

/// Активный lead конкретного юзера (для Lead Info block в user detail).
final adminUserActiveLeadProvider =
    FutureProvider.family<LeadRow?, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/leads', query: {'limit': 500});
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = d['items'];
    if (items is! List) return null;
    for (final raw in items.whereType<Map>()) {
      final lead = LeadRow.fromJson(Map<String, dynamic>.from(raw));
      if (lead.userId == userId &&
          lead.status != 'converted' &&
          lead.status != 'lost') {
        return lead;
      }
    }
    return null;
  } catch (e) {
    return null;
  }
});

// ════════════════════════════════════════════════════════════════════════
//  NEXT ACTION ENGINE
//  GET /admin/users/:id/next-action
// ════════════════════════════════════════════════════════════════════════

class NextActionResult {
  final String? code;
  final String? action;
  final String reason;
  final int possibleRevenue;
  final String? suggestedMessage;

  const NextActionResult({
    required this.reason,
    required this.possibleRevenue,
    this.code,
    this.action,
    this.suggestedMessage,
  });

  factory NextActionResult.fromJson(Map<String, dynamic> j) => NextActionResult(
        code: j['code']?.toString(),
        action: j['action']?.toString(),
        reason: j['reason']?.toString() ?? '',
        possibleRevenue: (j['possible_revenue'] as num?)?.toInt() ?? 0,
        suggestedMessage: j['suggested_message']?.toString(),
      );
}

final adminUserNextActionProvider =
    FutureProvider.family<NextActionResult?, int>((ref, userId) async {
  try {
    final res = await ApiClient.get('/admin/users/$userId/next-action');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return NextActionResult.fromJson(d);
  } catch (e) {
    return null;
  }
});

// ════════════════════════════════════════════════════════════════════════
//  CONVERSION FUNNEL
//  GET /admin/conversion
// ════════════════════════════════════════════════════════════════════════

class ConversionStep {
  final String step;
  final String label;
  final int usersCount;
  final double conversionPct;
  final double dropOffPct;
  final int revenueGeneratedRub;

  const ConversionStep({
    required this.step,
    required this.label,
    required this.usersCount,
    required this.conversionPct,
    required this.dropOffPct,
    required this.revenueGeneratedRub,
  });

  factory ConversionStep.fromJson(Map<String, dynamic> j) => ConversionStep(
        step: j['step']?.toString() ?? '',
        label: j['label']?.toString() ?? '',
        usersCount: (j['users_count'] as num?)?.toInt() ?? 0,
        conversionPct: (j['conversion_pct'] as num?)?.toDouble() ?? 0,
        dropOffPct: (j['drop_off_pct'] as num?)?.toDouble() ?? 0,
        revenueGeneratedRub: (j['revenue_generated_rub'] as num?)?.toInt() ?? 0,
      );
}

class ConversionData {
  final int totalRevenueRub;
  final List<ConversionStep> steps;
  const ConversionData({required this.totalRevenueRub, required this.steps});
  static const empty = ConversionData(totalRevenueRub: 0, steps: []);
}

final adminConversionProvider = FutureProvider<ConversionData>((ref) async {
  try {
    final res = await ApiClient.get('/admin/conversion');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final raw = d['steps'];
    final steps = (raw is List)
        ? raw
            .whereType<Map>()
            .map((e) => ConversionStep.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <ConversionStep>[];
    return ConversionData(
      totalRevenueRub: (d['total_revenue_rub'] as num?)?.toInt() ?? 0,
      steps: steps,
    );
  } catch (e) {
    return ConversionData.empty;
  }
});

// ════════════════════════════════════════════════════════════════════════
//  AI SALES SIGNALS
//  GET /admin/ai-sales-signals
//  POST /admin/ai-sales-signals/refresh
// ════════════════════════════════════════════════════════════════════════

final adminAiSalesSignalsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/ai-sales-signals');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = d['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  } catch (e) {
    return const [];
  }
});

// ════════════════════════════════════════════════════════════════════════
//  STAFF (для назначения leads менеджеру)
//  GET /admin/leads/staff
// ════════════════════════════════════════════════════════════════════════

class StaffMember {
  final int id;
  final String email;
  final String? name;
  final String role;
  const StaffMember({
    required this.id,
    required this.email,
    required this.role,
    this.name,
  });
  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
        id: (j['id'] as num?)?.toInt() ?? 0,
        email: j['email']?.toString() ?? '',
        name: j['name']?.toString(),
        role: j['role']?.toString() ?? 'admin',
      );
  String get displayName => (name?.isNotEmpty ?? false) ? name! : email;
}

final adminStaffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  try {
    final res = await ApiClient.get('/admin/leads/staff');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final items = d['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => StaffMember.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (e) {
    return const [];
  }
});

// ════════════════════════════════════════════════════════════════════════
//  LEAD EXPLAINER
//  GET /admin/leads/:id/explain
// ════════════════════════════════════════════════════════════════════════

class LeadExplain {
  final LeadRow lead;
  final Map<String, dynamic>? profile;
  final int score;
  final String bucket;
  final List<Map<String, dynamic>> reasons;
  final List<Map<String, dynamic>> recentEvents;
  final NextActionResult? nextAction;
  final Map<String, dynamic>? aiSignal;

  const LeadExplain({
    required this.lead,
    required this.score,
    required this.bucket,
    required this.reasons,
    required this.recentEvents,
    this.profile,
    this.nextAction,
    this.aiSignal,
  });
}

final adminLeadExplainProvider =
    FutureProvider.family<LeadExplain?, String>((ref, leadId) async {
  try {
    final res = await ApiClient.get('/admin/leads/$leadId/explain');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    if (d['ok'] != true) return null;
    final lead = LeadRow.fromJson(Map<String, dynamic>.from(d['lead'] as Map));
    final scoring = (d['score_breakdown'] as Map?) ?? const {};
    final reasons = (scoring['reasons'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final events = (d['recent_events'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    final next = (d['next_action'] as Map?) != null
        ? NextActionResult.fromJson(Map<String, dynamic>.from(d['next_action'] as Map))
        : null;
    final aiSignal = (d['ai_signal'] as Map?) != null
        ? Map<String, dynamic>.from(d['ai_signal'] as Map)
        : null;
    final profile = (d['profile'] as Map?) != null
        ? Map<String, dynamic>.from(d['profile'] as Map)
        : null;
    return LeadExplain(
      lead: lead,
      profile: profile,
      score: (scoring['score'] as num?)?.toInt() ?? 0,
      bucket: scoring['bucket']?.toString() ?? 'cold',
      reasons: reasons,
      recentEvents: events,
      nextAction: next,
      aiSignal: aiSignal,
    );
  } catch (e) {
    return null;
  }
});

// ════════════════════════════════════════════════════════════════════════
//  MANAGER DASHBOARD ("Мои продажи сегодня")
//  GET /admin/my-sales-dashboard
// ════════════════════════════════════════════════════════════════════════

class MySalesDashboard {
  final List<Map<String, dynamic>> myNewLeads;
  final List<Map<String, dynamic>> myInProgress;
  final int contacted7d;
  final int converted7d;
  final int lost7d;
  final int estimatedPossibleRevenue;
  final int realRevenue7dRub;

  const MySalesDashboard({
    required this.myNewLeads,
    required this.myInProgress,
    required this.contacted7d,
    required this.converted7d,
    required this.lost7d,
    required this.estimatedPossibleRevenue,
    required this.realRevenue7dRub,
  });

  static const empty = MySalesDashboard(
    myNewLeads: [], myInProgress: [],
    contacted7d: 0, converted7d: 0, lost7d: 0,
    estimatedPossibleRevenue: 0, realRevenue7dRub: 0,
  );
}

final adminMySalesDashboardProvider = FutureProvider<MySalesDashboard>((ref) async {
  try {
    final res = await ApiClient.get('/admin/my-sales-dashboard');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    List<Map<String, dynamic>> parseList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return MySalesDashboard(
      myNewLeads: parseList(d['my_new_leads']),
      myInProgress: parseList(d['my_in_progress']),
      contacted7d: (d['contacted_7d'] as num?)?.toInt() ?? 0,
      converted7d: (d['converted_7d'] as num?)?.toInt() ?? 0,
      lost7d: (d['lost_7d'] as num?)?.toInt() ?? 0,
      estimatedPossibleRevenue: (d['estimated_possible_revenue'] as num?)?.toInt() ?? 0,
      realRevenue7dRub: (d['real_revenue_7d_rub'] as num?)?.toInt() ?? 0,
    );
  } catch (e) {
    return MySalesDashboard.empty;
  }
});

// ════════════════════════════════════════════════════════════════════════
//  REVENUE DASHBOARD — SaaS-метрики (MRR/ARR/ARPU/LTV/Churn/Conversion)
//  GET /admin/revenue
// ════════════════════════════════════════════════════════════════════════

class RevenueMonthly {
  final String month; // YYYY-MM
  final int revenueRub;
  final int payingUsers;
  const RevenueMonthly({
    required this.month,
    required this.revenueRub,
    required this.payingUsers,
  });
  factory RevenueMonthly.fromJson(Map<String, dynamic> j) => RevenueMonthly(
        month: j['month']?.toString() ?? '',
        revenueRub: (j['revenue_rub'] as num?)?.toInt() ?? 0,
        payingUsers: (j['paying_users'] as num?)?.toInt() ?? 0,
      );
}

class RevenueByPlan {
  final String plan;
  final int revenue30dRub;
  final int payingUsers;
  const RevenueByPlan({
    required this.plan,
    required this.revenue30dRub,
    required this.payingUsers,
  });
  factory RevenueByPlan.fromJson(Map<String, dynamic> j) => RevenueByPlan(
        plan: j['plan']?.toString() ?? '',
        revenue30dRub: (j['revenue_30d_rub'] as num?)?.toInt() ?? 0,
        payingUsers: (j['paying_users'] as num?)?.toInt() ?? 0,
      );
}

class RevenueMetrics {
  final int mrrRub;
  final int arrRub;
  final int arpu30dRub;
  final int ltvRub;
  final double churn30dPct;
  final double conversionToPaidPct;
  final double momGrowthPct;
  final int failedPayments30dCount;
  final int failedPayments30dTotalRub;
  final int refunds30dCount;
  final int refunds30dTotalRub;
  final int forecastNextMonthRub;
  final List<RevenueMonthly> monthlyRevenue12m;
  final List<RevenueByPlan> revenueByPlan;
  final String? generatedAt;

  const RevenueMetrics({
    required this.mrrRub,
    required this.arrRub,
    required this.arpu30dRub,
    required this.ltvRub,
    required this.churn30dPct,
    required this.conversionToPaidPct,
    required this.momGrowthPct,
    required this.failedPayments30dCount,
    required this.failedPayments30dTotalRub,
    required this.refunds30dCount,
    required this.refunds30dTotalRub,
    required this.forecastNextMonthRub,
    required this.monthlyRevenue12m,
    required this.revenueByPlan,
    this.generatedAt,
  });

  static const empty = RevenueMetrics(
    mrrRub: 0, arrRub: 0, arpu30dRub: 0, ltvRub: 0,
    churn30dPct: 0, conversionToPaidPct: 0, momGrowthPct: 0,
    failedPayments30dCount: 0, failedPayments30dTotalRub: 0,
    refunds30dCount: 0, refunds30dTotalRub: 0,
    forecastNextMonthRub: 0,
    monthlyRevenue12m: [], revenueByPlan: [],
  );
}

final adminRevenueProvider = FutureProvider<RevenueMetrics>((ref) async {
  try {
    final res = await ApiClient.get('/admin/revenue');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final failed = (d['failed_payments_30d'] as Map?) ?? const {};
    final refunds = (d['refunds_30d'] as Map?) ?? const {};
    final monthlyRaw = d['monthly_revenue_12m'];
    final byPlanRaw = d['revenue_by_plan'];
    return RevenueMetrics(
      mrrRub: (d['mrr_rub'] as num?)?.toInt() ?? 0,
      arrRub: (d['arr_rub'] as num?)?.toInt() ?? 0,
      arpu30dRub: (d['arpu_30d_rub'] as num?)?.toInt() ?? 0,
      ltvRub: (d['ltv_rub'] as num?)?.toInt() ?? 0,
      churn30dPct: (d['churn_30d_pct'] as num?)?.toDouble() ?? 0,
      conversionToPaidPct: (d['conversion_to_paid_pct'] as num?)?.toDouble() ?? 0,
      momGrowthPct: (d['mom_growth_pct'] as num?)?.toDouble() ?? 0,
      failedPayments30dCount: (failed['count'] as num?)?.toInt() ?? 0,
      failedPayments30dTotalRub: (failed['total_rub'] as num?)?.toInt() ?? 0,
      refunds30dCount: (refunds['count'] as num?)?.toInt() ?? 0,
      refunds30dTotalRub: (refunds['total_rub'] as num?)?.toInt() ?? 0,
      forecastNextMonthRub: (d['forecast_next_month_rub'] as num?)?.toInt() ?? 0,
      monthlyRevenue12m: monthlyRaw is List
          ? monthlyRaw
              .whereType<Map>()
              .map((e) => RevenueMonthly.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      revenueByPlan: byPlanRaw is List
          ? byPlanRaw
              .whereType<Map>()
              .map((e) => RevenueByPlan.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      generatedAt: d['generated_at']?.toString(),
    );
  } catch (e) {
    return RevenueMetrics.empty;
  }
});

/// Текущий админ — для фильтра "мои лиды". Источник: GET /users/me возвращает
/// { success, user: { id, ... } }. Кэшируется Riverpod'ом до invalidate.
final adminCurrentIdProvider = FutureProvider<int?>((ref) async {
  try {
    final res = await ApiClient.get('/users/me');
    final d = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    final user = d['user'];
    if (user is Map) return (user['id'] as num?)?.toInt();
    return null;
  } catch (e) {
    return null;
  }
});
