import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/models/admin_log_model.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

String humanizeSupabaseError(Object e) {
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
    return 'Таблица не найдена. Выполните SQL-миграцию в Supabase.';
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
    throw Exception(humanizeSupabaseError(e));
  }
});

final allReleasesAdminProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  try {
    return await ref.read(releaseRepositoryProvider).getAllReleases();
  } catch (e) {
    throw Exception(humanizeSupabaseError(e));
  }
});

final allReportRowsProvider = FutureProvider<List<ReportRowModel>>((ref) async {
  try {
    return await ref.read(reportRepositoryProvider).getAllReportRows();
  } catch (e) {
    throw Exception(humanizeSupabaseError(e));
  }
});

final adminReportsProvider = FutureProvider<List<ReportModel>>((ref) async {
  try {
    return await ref.read(reportRepositoryProvider).getReports();
  } catch (e) {
    throw Exception(humanizeSupabaseError(e));
  }
});

final adminLogsProvider = FutureProvider<List<AdminLogModel>>((ref) async {
  try {
    return await ref.read(adminLogRepositoryProvider).getLogs(limit: 100);
  } catch (e) {
    throw Exception(humanizeSupabaseError(e));
  }
});

final allTicketsProvider = FutureProvider<List<SupportTicketModel>>((ref) async {
  try {
    return await ref.read(supportTicketRepositoryProvider).getAllTickets();
  } catch (e) {
    throw Exception(humanizeSupabaseError(e));
  }
});

/// Shared status filter for AdminReleasesTab.
/// Dashboard sets this before switching to the releases tab.
final adminReleasesFilterProvider = StateProvider<String>((ref) => 'all');
