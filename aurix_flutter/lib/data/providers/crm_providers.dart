import 'package:aurix_flutter/data/models/crm_models.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/repositories/crm_repository.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final crmLeadStageFilterProvider = StateProvider<String>((ref) => 'all');
final crmLeadAssigneeFilterProvider = StateProvider<String>((ref) => 'all');
final crmLeadSourceFilterProvider = StateProvider<String>((ref) => 'all');
final crmLeadPriorityFilterProvider = StateProvider<String>((ref) => 'all');
final crmLeadSearchProvider = StateProvider<String>((ref) => '');

final adminCrmLeadsProvider = FutureProvider<List<CrmLeadModel>>((ref) async {
  final filter = CrmLeadsFilter(
    stage: ref.watch(crmLeadStageFilterProvider),
    assignedTo: ref.watch(crmLeadAssigneeFilterProvider),
    source: ref.watch(crmLeadSourceFilterProvider),
    priority: ref.watch(crmLeadPriorityFilterProvider),
    search: ref.watch(crmLeadSearchProvider),
  );
  return ref.read(crmRepositoryProvider).getLeads(filter: filter);
});

final adminCrmDealsProvider = FutureProvider<List<CrmDealModel>>((ref) async {
  return ref.read(crmRepositoryProvider).getDeals();
});

final adminCrmInvoicesProvider =
    FutureProvider<List<CrmInvoiceModel>>((ref) async {
  return ref.read(crmRepositoryProvider).getInvoices();
});

final adminCrmTasksProvider = FutureProvider<List<CrmTaskModel>>((ref) async {
  return ref.read(crmRepositoryProvider).getTasks();
});

final myCrmLeadsProvider = FutureProvider<List<CrmLeadModel>>((ref) async {
  return ref.read(crmRepositoryProvider).getMyLeads();
});

final myCrmDealsProvider = FutureProvider<List<CrmDealModel>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null || uid.isEmpty) return const [];
  return ref.read(crmRepositoryProvider).getDealsByUser(uid);
});

final myCrmInvoicesProvider = FutureProvider<List<CrmInvoiceModel>>((ref) async {
  final uid = ref.watch(currentUserProvider)?.id;
  if (uid == null || uid.isEmpty) return const [];
  return ref.read(crmRepositoryProvider).getInvoicesByUser(uid);
});

final crmLeadNotesProvider =
    FutureProvider.family<List<CrmNoteModel>, String>((ref, leadId) async {
  if (leadId.isEmpty) return const [];
  return ref.read(crmRepositoryProvider).getNotes(leadId: leadId);
});

final crmLeadEventsProvider =
    FutureProvider.family<List<CrmEventModel>, String>((ref, leadId) async {
  if (leadId.isEmpty) return const [];
  return ref.read(crmRepositoryProvider).getEvents(leadId: leadId);
});

final crmCurrentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider)?.id;
});

final crmArtistSnapshotProvider =
    FutureProvider.family<CrmArtistProfileSnapshot?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  return ref.read(crmRepositoryProvider).getArtistSnapshot(userId);
});
