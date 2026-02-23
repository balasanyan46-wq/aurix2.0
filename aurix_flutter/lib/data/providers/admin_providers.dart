import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/models/admin_log_model.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

final allProfilesProvider = FutureProvider.autoDispose<List<ProfileModel>>((ref) async {
  return ref.read(profileRepositoryProvider).getAllProfiles();
});

final allReleasesAdminProvider = FutureProvider.autoDispose<List<ReleaseModel>>((ref) async {
  return ref.read(releaseRepositoryProvider).getAllReleases();
});

final allReportRowsProvider = FutureProvider.autoDispose<List<ReportRowModel>>((ref) async {
  return ref.read(reportRepositoryProvider).getAllReportRows();
});

final adminReportsProvider = FutureProvider.autoDispose<List<ReportModel>>((ref) async {
  return ref.read(reportRepositoryProvider).getReports();
});

final adminLogsProvider = FutureProvider.autoDispose<List<AdminLogModel>>((ref) async {
  return ref.read(adminLogRepositoryProvider).getLogs(limit: 100);
});

final allTicketsProvider = FutureProvider.autoDispose<List<SupportTicketModel>>((ref) async {
  return ref.read(supportTicketRepositoryProvider).getAllTickets();
});
