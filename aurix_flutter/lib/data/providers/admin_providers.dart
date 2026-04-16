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
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (e) {
    return [];
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
