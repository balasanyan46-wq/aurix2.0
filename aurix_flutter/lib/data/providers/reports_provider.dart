import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Report rows for the current user. Shared by Analytics, Finances, Promotion screens.
/// Kept without autoDispose so data is cached when navigating between tabs.
final userReportRowsProvider = FutureProvider<List<ReportRowModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(reportRepositoryProvider).getRowsByUser(user.id);
});
