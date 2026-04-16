import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/repositories/auth_repository.dart';
import 'package:aurix_flutter/data/repositories/profile_repository.dart';
import 'package:aurix_flutter/data/repositories/release_repository.dart';
import 'package:aurix_flutter/data/repositories/file_repository.dart';
import 'package:aurix_flutter/data/repositories/track_repository.dart';
import 'package:aurix_flutter/data/repositories/report_repository.dart';
import 'package:aurix_flutter/data/repositories/admin_log_repository.dart';
import 'package:aurix_flutter/data/repositories/support_ticket_repository.dart';
import 'package:aurix_flutter/data/repositories/account_deletion_request_repository.dart';
import 'package:aurix_flutter/data/repositories/legal_compliance_repository.dart';
import 'package:aurix_flutter/data/repositories/release_delete_request_repository.dart';
import 'package:aurix_flutter/data/repositories/release_aai_repository.dart';
import 'package:aurix_flutter/data/repositories/promo_repository.dart';
import 'package:aurix_flutter/data/repositories/crm_repository.dart';
import 'package:aurix_flutter/data/repositories/billing_subscription_repository.dart';
import 'package:aurix_flutter/data/repositories/team_repository.dart';
import 'package:aurix_flutter/features/legal/data/legal_repository.dart';
import 'package:aurix_flutter/features/index/data/repositories/index_repository.dart';
import 'package:aurix_flutter/features/index/data/repositories/mock_index_repository.dart';
import 'package:aurix_flutter/features/index_engine/adapters/engine_backed_index_repository.dart';
import 'package:aurix_flutter/features/index_engine/adapters/index_engine_to_legacy_adapter.dart';
import 'package:aurix_flutter/features/index_engine/data/repositories/mock_index_repository.dart' as engine;
import 'package:aurix_flutter/features/index_engine/index_engine_service.dart';
import 'package:aurix_flutter/data/services/auth_service.dart';
import 'package:aurix_flutter/data/services/release_export_service.dart';
import 'package:aurix_flutter/data/services/growth_plan_service.dart';
import 'package:aurix_flutter/data/services/budget_plan_service.dart';
import 'package:aurix_flutter/data/services/billing_service.dart';
import 'package:aurix_flutter/data/services/tool_service.dart';
import 'package:aurix_flutter/ai/ai_studio_history_repository.dart';
import 'package:aurix_flutter/ai/ai_tool_results_repository.dart';
import 'package:aurix_flutter/features/production/data/production_service.dart';
import 'package:aurix_flutter/data/repositories/beat_repository.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final growthPlanServiceProvider = Provider<GrowthPlanService>((ref) => GrowthPlanService());
final budgetPlanServiceProvider = Provider<BudgetPlanService>((ref) => BudgetPlanService());
final billingServiceProvider = Provider<BillingService>((ref) => BillingService());
final toolServiceProvider = Provider<ToolService>((ref) => ToolService());

final releaseExportServiceProvider = Provider<ReleaseExportService>((ref) =>
    ReleaseExportService(
      releaseRepository: ref.watch(releaseRepositoryProvider),
      trackRepository: ref.watch(trackRepositoryProvider),
    ));

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository());
final releaseRepositoryProvider = Provider<ReleaseRepository>((ref) => ReleaseRepository());
final fileRepositoryProvider = Provider<FileRepository>((ref) => FileRepository());
final trackRepositoryProvider = Provider<TrackRepository>((ref) => TrackRepository());
final reportRepositoryProvider = Provider<ReportRepository>((ref) => ReportRepository());
final adminLogRepositoryProvider = Provider<AdminLogRepository>((ref) => AdminLogRepository());
final supportTicketRepositoryProvider = Provider<SupportTicketRepository>((ref) => SupportTicketRepository());
final accountDeletionRequestRepositoryProvider =
    Provider<AccountDeletionRequestRepository>((ref) => AccountDeletionRequestRepository());
final legalComplianceRepositoryProvider =
    Provider<LegalComplianceRepository>((ref) => LegalComplianceRepository());
final releaseDeleteRequestRepositoryProvider =
    Provider<ReleaseDeleteRequestRepository>((ref) => ReleaseDeleteRequestRepository());
final releaseAaiRepositoryProvider = Provider<ReleaseAaiRepository>((ref) => ReleaseAaiRepository());
final promoRepositoryProvider = Provider<PromoRepository>((ref) => PromoRepository());
final crmRepositoryProvider = Provider<CrmRepository>((ref) => CrmRepository());
final billingSubscriptionRepositoryProvider =
    Provider<BillingSubscriptionRepository>((ref) => BillingSubscriptionRepository());
final teamRepositoryProvider = Provider<TeamRepository>((ref) => TeamRepository());
final legalRepositoryProvider = Provider<LegalRepository>((ref) => LegalRepository());
final aiStudioHistoryRepositoryProvider = Provider<AiStudioHistoryRepository>((ref) => AiStudioHistoryRepository());
final aiToolResultsRepositoryProvider = Provider<AiToolResultsRepository>((ref) => AiToolResultsRepository());
final productionServiceProvider = Provider<ProductionService>((ref) => ProductionService());
final beatRepositoryProvider = Provider<BeatRepository>((ref) => BeatRepository());

final indexEngineRepositoryProvider = Provider<engine.MockIndexEngineRepository>((ref) =>
    engine.MockIndexEngineRepository());

final indexEngineServiceProvider = Provider<IndexEngineService>((ref) =>
    IndexEngineService(ref.watch(indexEngineRepositoryProvider)));

final indexEngineAdapterProvider = Provider<IndexEngineToLegacyAdapter>((ref) =>
    IndexEngineToLegacyAdapter(ref.watch(indexEngineServiceProvider)));

final indexRepositoryProvider = Provider<IndexRepository>((ref) =>
    EngineBackedIndexRepository(
      service: ref.watch(indexEngineServiceProvider),
      engineRepo: ref.watch(indexEngineRepositoryProvider),
      adapter: ref.watch(indexEngineAdapterProvider),
      awardsFallback: MockIndexRepository(),
    ));

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
