import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/data/models/promo_request_model.dart';
import 'package:aurix_flutter/data/models/crm_models.dart';
import 'package:aurix_flutter/data/models/release_aai_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/crm_providers.dart';
import 'package:aurix_flutter/data/providers/promo_providers.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/features/production/data/production_models.dart';
import 'package:aurix_flutter/services/ai_chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final _releaseAaiByIdProvider =
    FutureProvider.family<ReleaseAaiModel?, String>((ref, releaseId) async {
  return ref.read(releaseAaiRepositoryProvider).getReleaseAai(releaseId);
});

final _myProductionDashboardProvider =
    FutureProvider.family<ProductionDashboard?, String?>((ref, userId) async {
  if (userId == null || userId.isEmpty) return null;
  return ref.read(productionServiceProvider).getArtistDashboard(userId);
});

enum _PromoStage { preRelease, releaseWeek, postRelease }

extension _PromoStageX on _PromoStage {
  String get label => switch (this) {
        _PromoStage.preRelease => 'Pre-release',
        _PromoStage.releaseWeek => 'Release week',
        _PromoStage.postRelease => 'Post-release',
      };
}

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  final _aiService = AiChatService();
  String? _releaseId;
  bool _loadingAiPitch = false;
  bool _submittingDsp = false;
  bool _submittingAurix = false;
  bool _submittingInfluencer = false;
  bool _submittingAds = false;
  String? _aiPitchText;

  final _dspDescriptionCtrl = TextEditingController();
  final _dspMoodCtrl = TextEditingController();

  final _aurixGenreCtrl = TextEditingController();
  final _aurixMoodCtrl = TextEditingController();
  final _aurixCountriesCtrl = TextEditingController();
  final _aurixAudienceCtrl = TextEditingController();
  final _aurixBudgetCtrl = TextEditingController();
  final _aurixCommentCtrl = TextEditingController();

  final _influencerBudgetCtrl = TextEditingController();
  final _influencerCommentCtrl = TextEditingController();
  final _influencerAudienceCtrl = TextEditingController();

  final _adsBudgetCtrl = TextEditingController();
  final _adsGoalCtrl = TextEditingController(text: 'streams');
  final _adsCommentCtrl = TextEditingController();

  @override
  void dispose() {
    _dspDescriptionCtrl.dispose();
    _dspMoodCtrl.dispose();
    _aurixGenreCtrl.dispose();
    _aurixMoodCtrl.dispose();
    _aurixCountriesCtrl.dispose();
    _aurixAudienceCtrl.dispose();
    _aurixBudgetCtrl.dispose();
    _aurixCommentCtrl.dispose();
    _influencerBudgetCtrl.dispose();
    _influencerCommentCtrl.dispose();
    _influencerAudienceCtrl.dispose();
    _adsBudgetCtrl.dispose();
    _adsGoalCtrl.dispose();
    _adsCommentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final releasesAsync = ref.watch(releasesProvider);
    final releases = releasesAsync.valueOrNull ?? [];
    final loading = releasesAsync.isLoading && releases.isEmpty;

    if (loading) {
      return SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
        child: const _PromotionLoadingSkeleton(),
      );
    }

    if (_releaseId == null && releases.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _releaseId = releases.first.id);
      });
    }

    final selectedRelease = releases.cast<ReleaseModel?>().firstWhere(
          (r) => r?.id == _releaseId,
          orElse: () => releases.isNotEmpty ? releases.first : null,
        );
    final releaseId = selectedRelease?.id;
    final requestsAsync = ref.watch(myPromoRequestsProvider(releaseId));
    final crmDealsAsync = ref.watch(myCrmDealsProvider);
    final crmInvoicesAsync = ref.watch(myCrmInvoicesProvider);
    final myUserId = ref.watch(currentUserIdProvider);
    final productionAsync = ref.watch(_myProductionDashboardProvider(myUserId));
    final aaiAsync = releaseId == null
        ? const AsyncValue<ReleaseAaiModel?>.data(null)
        : ref.watch(_releaseAaiByIdProvider(releaseId));

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeInSlide(
                child: _CampaignOverviewBlock(
                  releases: releases,
                  selectedReleaseId: _releaseId,
                  onSelectRelease: (id) => setState(() => _releaseId = id),
                  selectedRelease: selectedRelease,
                  aaiAsync: aaiAsync,
                ),
              ),
              const SizedBox(height: 20),
              FadeInSlide(
                delayMs: 50,
                child: PremiumSectionCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AurixTokens.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Заявки и их статусы перенесены в раздел Продакшн.',
                          style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                delayMs: 100,
                child: _MyServicesOverview(
                  productionAsync: productionAsync,
                  dealsAsync: crmDealsAsync,
                  invoicesAsync: crmInvoicesAsync,
                ),
              ),
              const SizedBox(height: 20),
              FadeInSlide(
                delayMs: 150,
                child: _DspPitchBlock(
                release: selectedRelease,
                aiPitchText: _aiPitchText,
                descriptionCtrl: _dspDescriptionCtrl,
                moodCtrl: _dspMoodCtrl,
                loadingAiPitch: _loadingAiPitch,
                submittingDsp: _submittingDsp,
                onGenerate: () => _generateDspPitch(selectedRelease),
                onMarkSubmitted: () => _submitDspPitch(selectedRelease),
                ),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                delayMs: 200,
                child: _AurixPitchBlock(
                hasRelease: selectedRelease != null,
                genreCtrl: _aurixGenreCtrl,
                moodCtrl: _aurixMoodCtrl,
                countriesCtrl: _aurixCountriesCtrl,
                audienceCtrl: _aurixAudienceCtrl,
                budgetCtrl: _aurixBudgetCtrl,
                commentCtrl: _aurixCommentCtrl,
                submitting: _submittingAurix,
                onSubmit: () => _submitAurixPitch(selectedRelease),
                ),
              ),
              const SizedBox(height: 16),
              FadeInSlide(
                delayMs: 250,
                child: _InfluencerBlock(
                hasRelease: selectedRelease != null,
                audienceCtrl: _influencerAudienceCtrl,
                budgetCtrl: _influencerBudgetCtrl,
                commentCtrl: _influencerCommentCtrl,
                submitting: _submittingInfluencer,
                onSubmit: () => _submitInfluencer(selectedRelease),
                ),
              ),
              if (isDesktop) ...[
                const SizedBox(height: 16),
                FadeInSlide(
                  delayMs: 300,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _AdsBlock(
                          hasRelease: selectedRelease != null,
                          goalCtrl: _adsGoalCtrl,
                          budgetCtrl: _adsBudgetCtrl,
                          commentCtrl: _adsCommentCtrl,
                          submitting: _submittingAds,
                          onSubmit: () => _submitAds(selectedRelease),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                FadeInSlide(
                  delayMs: 300,
                  child: _AdsBlock(
                    hasRelease: selectedRelease != null,
                    goalCtrl: _adsGoalCtrl,
                    budgetCtrl: _adsBudgetCtrl,
                    commentCtrl: _adsCommentCtrl,
                    submitting: _submittingAds,
                    onSubmit: () => _submitAds(selectedRelease),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FadeInSlide(
                delayMs: 350,
                child: _NoCampaignTips(requestsAsync: requestsAsync),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generateDspPitch(ReleaseModel? release) async {
    if (release == null) {
      _snack('Сначала создай релиз, затем можно запускать промо');
      return;
    }
    if (_dspDescriptionCtrl.text.trim().isEmpty ||
        _dspMoodCtrl.text.trim().isEmpty) {
      _snack('Заполни описание и настроение для AI-питча');
      return;
    }
    setState(() => _loadingAiPitch = true);
    try {
      final prompt = '''
Сгенерируй короткий pitch (до 900 символов) для редакторского питчинга DSP.
Язык: русский.
Релиз: ${release.title}
Артист: ${release.artist ?? 'Не указан'}
Жанр: ${release.genre ?? 'Не указан'}
Тип: ${release.releaseType}
Дата релиза: ${release.releaseDate?.toIso8601String() ?? 'не указана'}
Описание: ${_dspDescriptionCtrl.text.trim()}
Настроение: ${_dspMoodCtrl.text.trim()}

Нужна структура:
1) Кто артист и контекст релиза
2) В чем уникальность трека/релиза
3) Для какой аудитории и где лучше сработает
''';
      final text = await _aiService.send(message: prompt);
      if (!mounted) return;
      setState(() => _aiPitchText = text.trim());
    } catch (e) {
      _snack('Не удалось сгенерировать AI-питч: $e');
    } finally {
      if (mounted) setState(() => _loadingAiPitch = false);
    }
  }

  Future<void> _submitDspPitch(ReleaseModel? release) async {
    if (release == null) {
      _snack('Сначала создай релиз, затем можно отправлять заявки');
      return;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return _snack('Нужна авторизация');
    if (_aiPitchText == null || _aiPitchText!.isEmpty) {
      return _snack('Сначала сгенерируй текст питча');
    }
    setState(() => _submittingDsp = true);
    try {
      await ref.read(promoRepositoryProvider).upsertByType(
        userId: uid,
        releaseId: release.id,
        type: 'dsp_pitch',
        status: 'submitted',
        formData: {
          'description': _dspDescriptionCtrl.text.trim(),
          'mood': _dspMoodCtrl.text.trim(),
          'generated_pitch': _aiPitchText,
          'submitted_at': DateTime.now().toIso8601String(),
        },
      );
      ref.invalidate(myPromoRequestsProvider(release.id));
      _snack('DSP-питч отмечен как поданный');
    } catch (e) {
      _snack(_humanizePromoError(e));
    } finally {
      if (mounted) setState(() => _submittingDsp = false);
    }
  }

  Future<void> _submitAurixPitch(ReleaseModel? release) async {
    if (release == null) {
      _snack('Сначала создай релиз, затем можно отправлять заявки');
      return;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return _snack('Нужна авторизация');
    if (_aurixGenreCtrl.text.trim().isEmpty ||
        _aurixMoodCtrl.text.trim().isEmpty) {
      return _snack('Заполни жанр и настроение');
    }
    setState(() => _submittingAurix = true);
    try {
      await ref.read(promoRepositoryProvider).upsertByType(
        userId: uid,
        releaseId: release.id,
        type: 'aurix_pitch',
        formData: {
          'genre': _aurixGenreCtrl.text.trim(),
          'mood': _aurixMoodCtrl.text.trim(),
          'countries': _aurixCountriesCtrl.text.trim(),
          'target_audience': _aurixAudienceCtrl.text.trim(),
          'budget': _aurixBudgetCtrl.text.trim(),
          'comment': _aurixCommentCtrl.text.trim(),
        },
      );
      ref.invalidate(myPromoRequestsProvider(release.id));
      _snack('Заявка на кураторский питчинг отправлена');
    } catch (e) {
      _snack(_humanizePromoError(e));
    } finally {
      if (mounted) setState(() => _submittingAurix = false);
    }
  }

  Future<void> _submitInfluencer(ReleaseModel? release) async {
    if (release == null) {
      _snack('Сначала создай релиз, затем можно отправлять заявки');
      return;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return _snack('Нужна авторизация');
    setState(() => _submittingInfluencer = true);
    try {
      await ref.read(promoRepositoryProvider).upsertByType(
        userId: uid,
        releaseId: release.id,
        type: 'influencer',
        formData: {
          'target_audience': _influencerAudienceCtrl.text.trim(),
          'budget': _influencerBudgetCtrl.text.trim(),
          'comment': _influencerCommentCtrl.text.trim(),
        },
      );
      ref.invalidate(myPromoRequestsProvider(release.id));
      _snack('Influencer-заявка отправлена');
    } catch (e) {
      _snack(_humanizePromoError(e));
    } finally {
      if (mounted) setState(() => _submittingInfluencer = false);
    }
  }

  Future<void> _submitAds(ReleaseModel? release) async {
    if (release == null) {
      _snack('Сначала создай релиз, затем можно отправлять заявки');
      return;
    }
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return _snack('Нужна авторизация');
    if (_adsBudgetCtrl.text.trim().isEmpty) return _snack('Укажи бюджет');
    setState(() => _submittingAds = true);
    try {
      await ref.read(promoRepositoryProvider).upsertByType(
        userId: uid,
        releaseId: release.id,
        type: 'ads',
        formData: {
          'goal': _adsGoalCtrl.text.trim(),
          'budget': _adsBudgetCtrl.text.trim(),
          'comment': _adsCommentCtrl.text.trim(),
        },
      );
      ref.invalidate(myPromoRequestsProvider(release.id));
      _snack('Рекламная заявка отправлена');
    } catch (e) {
      _snack(_humanizePromoError(e));
    } finally {
      if (mounted) setState(() => _submittingAds = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AurixTokens.bg2,
      behavior: SnackBarBehavior.floating,
    ));
  }
}

class _CampaignOverviewBlock extends StatelessWidget {
  const _CampaignOverviewBlock({
    required this.releases,
    required this.selectedReleaseId,
    required this.onSelectRelease,
    required this.selectedRelease,
    required this.aaiAsync,
  });

  final List<ReleaseModel> releases;
  final String? selectedReleaseId;
  final void Function(String?) onSelectRelease;
  final ReleaseModel? selectedRelease;
  final AsyncValue<ReleaseAaiModel?> aaiAsync;

  @override
  Widget build(BuildContext context) {
    final stage = _stageFor(selectedRelease);
    return PremiumSectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Кампания релиза',
            subtitle: 'Статус релиза, smart link аналитика и старт кампаний.',
          ),
          const SizedBox(height: 12),
          if (releases.isEmpty)
            Text(
              'Нет релизов для промо-кампаний. Сначала создай релиз.',
              style: TextStyle(color: AurixTokens.muted, fontSize: 13),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: selectedReleaseId ?? selectedRelease?.id,
              decoration: InputDecoration(
                labelText: 'Текущий релиз',
                labelStyle: const TextStyle(color: AurixTokens.muted),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AurixTokens.stroke(0.2)),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              dropdownColor: AurixTokens.bg1,
              items: releases
                  .map(
                    (r) => DropdownMenuItem<String>(
                      value: r.id,
                      child: Text(
                        r.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AurixTokens.text),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onSelectRelease,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Статус:',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                ),
                PremiumStatusPill(label: stage.label, status: 'in_progress'),
              ],
            ),
            const SizedBox(height: 12),
            aaiAsync.when(
              data: (aai) => _SmartLinkStats(aai: aai),
              loading: () => const SizedBox(
                height: 64,
                child: Center(
                    child:
                        CircularProgressIndicator(color: AurixTokens.accent)),
              ),
              error: (_, __) => Text(
                'Smart link аналитика пока недоступна',
                style: TextStyle(color: AurixTokens.muted, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ignore: unused_element
class _ArtistRequestsOverview extends ConsumerWidget {
  const _ArtistRequestsOverview({
    required this.requestsAsync,
    required this.crmLeadsAsync,
  });
  final AsyncValue<List<PromoRequestModel>> requestsAsync;
  final AsyncValue<List<CrmLeadModel>> crmLeadsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Мои заявки',
            subtitle: 'Статусы, дедлайны и то, что требуется от тебя.',
          ),
          const SizedBox(height: 10),
          crmLeadsAsync.when(
            data: (leads) => leads.isEmpty
                ? _buildPromoFallback()
                : Column(
                    children: leads.map((lead) {
                      final progress = _leadProgress(lead.pipelineStage);
                      final artistStatus =
                          _crmArtistStatusLabel(lead.pipelineStage);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AurixTokens.bg2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AurixTokens.stroke(0.18)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lead.title ??
                                          _promoTypeLabel(
                                              lead.type ?? lead.source),
                                      style: const TextStyle(
                                        color: AurixTokens.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  PremiumStatusPill(
                                    label: artistStatus,
                                    status: _crmStatusStyle(lead.pipelineStage),
                                  ),
                                ],
                              ),
                              if (lead.assignedTo != null &&
                                  lead.assignedTo!.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                const Text(
                                  'Ведёт менеджер AURIX',
                                  style: TextStyle(
                                      color: AurixTokens.muted, fontSize: 12),
                                ),
                              ],
                              if (lead.dueAt != null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'Дедлайн: ${DateFormat('dd.MM.yyyy').format(lead.dueAt!)}',
                                  style: const TextStyle(
                                      color: AurixTokens.warning, fontSize: 12),
                                ),
                              ],
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 7,
                                  backgroundColor: AurixTokens.glass(0.1),
                                  valueColor: const AlwaysStoppedAnimation(
                                      AurixTokens.accent),
                                ),
                              ),
                              if (lead.pipelineStage == 'need_info') ...[
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _openNeedInfoDialog(context, ref, lead),
                                    icon: const Icon(Icons.upload_file_rounded,
                                        size: 16),
                                    label: const Text('Добавить данные'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(color: AurixTokens.accent)),
            ),
            error: (e, _) {
              final msg = e.toString().toLowerCase();
              final isAccess =
                  msg.contains('permission') || msg.contains('row-level');
              if (isAccess) return _buildPromoFallback();
              return Text(
                _humanizePromoError(e),
                style: const TextStyle(
                    color: AurixTokens.danger, fontSize: 13, height: 1.35),
              );
            },
          ),
          const SizedBox(height: 8),
          const Text(
            'Если статус "Нужны данные" — дополни заявку в полях ниже и отправь снова.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoFallback() {
    return requestsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return Text(
            'Пока нет активных кампаний.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13),
          );
        }
        return Column(
          children: items.map((r) {
            final progress = _statusProgress(r.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AurixTokens.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.stroke(0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _promoTypeLabel(r.type),
                            style: const TextStyle(
                              color: AurixTokens.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        PremiumStatusPill(
                          label: _promoArtistStatusLabel(r.status),
                          status: r.status,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: AurixTokens.glass(0.1),
                        valueColor:
                            const AlwaysStoppedAnimation(AurixTokens.orange),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child:
            Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
      ),
      error: (e, _) => Text(
        _humanizePromoError(e),
        style: const TextStyle(
            color: AurixTokens.danger, fontSize: 13, height: 1.35),
      ),
    );
  }
}

class _DspPitchBlock extends StatelessWidget {
  const _DspPitchBlock({
    required this.release,
    required this.aiPitchText,
    required this.descriptionCtrl,
    required this.moodCtrl,
    required this.loadingAiPitch,
    required this.submittingDsp,
    required this.onGenerate,
    required this.onMarkSubmitted,
  });

  final ReleaseModel? release;
  final String? aiPitchText;
  final TextEditingController descriptionCtrl;
  final TextEditingController moodCtrl;
  final bool loadingAiPitch;
  final bool submittingDsp;
  final VoidCallback onGenerate;
  final VoidCallback onMarkSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasRelease = release != null;
    final now = DateTime.now();
    final releaseDate = release?.releaseDate;
    final daysLeft =
        releaseDate == null ? null : releaseDate.difference(now).inDays;
    final isBeforeRelease = releaseDate != null && releaseDate.isAfter(now);
    final available = isBeforeRelease && (daysLeft ?? -1) > 7;

    return PremiumSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle(
              icon: Icons.headphones_rounded, title: 'Питчинг · DSP Pitch'),
          const SizedBox(height: 8),
          Text(
            !hasRelease
                ? 'Сначала создай релиз, чтобы активировать этот блок.'
                : available
                    ? 'Доступно для подачи. До релиза: $daysLeft дн.'
                    : 'DSP-питч доступен только до релиза и минимум за 7 дней.',
            style: TextStyle(
              color: available ? AurixTokens.positive : AurixTokens.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _SimpleField(ctrl: descriptionCtrl, label: 'Описание релиза'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: moodCtrl, label: 'Mood / настроение'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 560;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: (!hasRelease || loadingAiPitch) ? null : onGenerate,
                      icon: loadingAiPitch
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      style: FilledButton.styleFrom(
                        backgroundColor: AurixTokens.accent,
                        foregroundColor: Colors.white,
                      ),
                      label: const Text('Сгенерировать текст питча'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: (!hasRelease || !available || submittingDsp)
                          ? null
                          : onMarkSubmitted,
                      child: submittingDsp
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Отметить как подано'),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  FilledButton.icon(
                    onPressed: (!hasRelease || loadingAiPitch) ? null : onGenerate,
                    icon: loadingAiPitch
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    style: FilledButton.styleFrom(
                      backgroundColor: AurixTokens.accent,
                      foregroundColor: Colors.white,
                    ),
                    label: const Text('Сгенерировать текст питча'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: (!hasRelease || !available || submittingDsp)
                        ? null
                        : onMarkSubmitted,
                    child: submittingDsp
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Отметить как подано'),
                  ),
                ],
              );
            },
          ),
          if (aiPitchText != null && aiPitchText!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AurixTokens.bg2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AurixTokens.stroke(0.16)),
              ),
              child: SelectableText(
                aiPitchText!,
                style: const TextStyle(
                    color: AurixTokens.text, fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ],
      ),
    );
  }

}

class _AurixPitchBlock extends StatelessWidget {
  const _AurixPitchBlock({
    required this.hasRelease,
    required this.genreCtrl,
    required this.moodCtrl,
    required this.countriesCtrl,
    required this.audienceCtrl,
    required this.budgetCtrl,
    required this.commentCtrl,
    required this.submitting,
    required this.onSubmit,
  });

  final bool hasRelease;
  final TextEditingController genreCtrl;
  final TextEditingController moodCtrl;
  final TextEditingController countriesCtrl;
  final TextEditingController audienceCtrl;
  final TextEditingController budgetCtrl;
  final TextEditingController commentCtrl;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle(
              icon: Icons.local_fire_department_rounded,
              title: 'Питчинг · Aurix Pitch'),
          if (!hasRelease) ...[
            const SizedBox(height: 8),
            const Text(
              'Сначала создай релиз, чтобы отправить заявку.',
              style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          _SimpleField(ctrl: genreCtrl, label: 'Жанр'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: moodCtrl, label: 'Настроение'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: countriesCtrl, label: 'Страны (через запятую)'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: audienceCtrl, label: 'Целевая аудитория'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: budgetCtrl, label: 'Бюджет (опционально)'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: commentCtrl, label: 'Комментарий'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: (!hasRelease || submitting) ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.accent,
              foregroundColor: Colors.white,
            ),
            label: const Text('Подать на кураторский питчинг'),
          ),
        ],
      ),
    );
  }
}

class _InfluencerBlock extends StatelessWidget {
  const _InfluencerBlock({
    required this.hasRelease,
    required this.audienceCtrl,
    required this.budgetCtrl,
    required this.commentCtrl,
    required this.submitting,
    required this.onSubmit,
  });

  final bool hasRelease;
  final TextEditingController audienceCtrl;
  final TextEditingController budgetCtrl;
  final TextEditingController commentCtrl;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle(
              icon: Icons.video_collection_rounded,
              title: 'Influencer / Reels / TikTok'),
          if (!hasRelease) ...[
            const SizedBox(height: 8),
            const Text(
              'Сначала создай релиз, чтобы отправить заявку.',
              style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          _SimpleField(ctrl: audienceCtrl, label: 'Целевая аудитория'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: budgetCtrl, label: 'Бюджет'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: commentCtrl, label: 'Комментарий'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: (!hasRelease || submitting) ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.accent,
              foregroundColor: Colors.white,
            ),
            label: const Text('Подать на influencer продвижение'),
          ),
        ],
      ),
    );
  }
}

class _AdsBlock extends StatelessWidget {
  const _AdsBlock({
    required this.hasRelease,
    required this.goalCtrl,
    required this.budgetCtrl,
    required this.commentCtrl,
    required this.submitting,
    required this.onSubmit,
  });

  final bool hasRelease;
  final TextEditingController goalCtrl;
  final TextEditingController budgetCtrl;
  final TextEditingController commentCtrl;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle(icon: Icons.campaign_rounded, title: 'Реклама'),
          if (!hasRelease) ...[
            const SizedBox(height: 8),
            const Text(
              'Сначала создай релиз, чтобы отправить заявку.',
              style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          _SimpleField(
              ctrl: goalCtrl, label: 'Цель (streams / followers / reach)'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: budgetCtrl, label: 'Бюджет'),
          const SizedBox(height: 8),
          _SimpleField(ctrl: commentCtrl, label: 'Комментарий'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: (!hasRelease || submitting) ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.accent,
              foregroundColor: Colors.white,
            ),
            label: const Text('Отправить рекламную заявку'),
          ),
        ],
      ),
    );
  }
}

class _MyServicesOverview extends StatelessWidget {
  const _MyServicesOverview({
    required this.productionAsync,
    required this.dealsAsync,
    required this.invoicesAsync,
  });

  final AsyncValue<ProductionDashboard?> productionAsync;
  final AsyncValue<List<CrmDealModel>> dealsAsync;
  final AsyncValue<List<CrmInvoiceModel>> invoicesAsync;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Мои услуги',
            subtitle: 'Текущие задачи продакшна, дедлайны и статусы.',
          ),
          const SizedBox(height: 10),
          productionAsync.when(
            data: (dashboard) {
              final rows = dashboard?.items
                      .where((x) => x.status != 'done' && x.status != 'canceled')
                      .toList() ??
                  const <ProductionOrderItem>[];
              final deals = dealsAsync.valueOrNull ?? const <CrmDealModel>[];
              final invoices =
                  invoicesAsync.valueOrNull ?? const <CrmInvoiceModel>[];
              if (rows.isEmpty) {
                return const Text(
                  'Пока нет активных услуг. Когда менеджер запустит продакшн-задачи, они появятся здесь.',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                );
              }
              return Column(
                children: rows.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AurixTokens.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AurixTokens.stroke(0.18)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.service?.title ?? 'Услуга',
                                style: const TextStyle(
                                  color: AurixTokens.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (item.deadlineAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Дедлайн: ${DateFormat('dd.MM.yyyy').format(item.deadlineAt!)}',
                                  style: const TextStyle(
                                      color: AurixTokens.warning, fontSize: 12),
                                ),
                              ],
                              Builder(
                                builder: (_) {
                                  final deal = deals
                                      .where((d) =>
                                          d.productionOrderId == item.orderId)
                                      .cast<CrmDealModel?>()
                                      .firstWhere(
                                        (v) => v != null,
                                        orElse: () => null,
                                      );
                                  if (deal == null) return const SizedBox.shrink();
                                  final dealInvoices =
                                      invoices.where((x) => x.dealId == deal.id);
                                  final total = dealInvoices.fold<double>(
                                      0, (s, row) => s + row.amount);
                                  final paid = dealInvoices
                                      .where((x) => x.status == 'paid')
                                      .fold<double>(0, (s, row) => s + row.amount);
                                  if (total <= 0) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Оплата: ${paid.toStringAsFixed(0)}/${total.toStringAsFixed(0)} RUB',
                                      style: const TextStyle(
                                        color: AurixTokens.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        PremiumStatusPill(
                          label: productionStatusLabel(item.status),
                          status: _productionStatusStyle(item.status),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: CircularProgressIndicator(color: AurixTokens.accent),
              ),
            ),
            error: (e, _) => Text(
              'Не удалось загрузить услуги: $e',
              style: const TextStyle(color: AurixTokens.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCampaignTips extends StatelessWidget {
  const _NoCampaignTips({required this.requestsAsync});
  final AsyncValue<List<PromoRequestModel>> requestsAsync;

  @override
  Widget build(BuildContext context) {
    final items = requestsAsync.valueOrNull ?? const <PromoRequestModel>[];
    final hasActive =
        items.any((i) => i.status != 'completed' && i.status != 'rejected');
    if (hasActive) return const SizedBox.shrink();
    return PremiumSectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Рекомендации для старта',
            style:
                TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Начни с Aurix Pitch и заявки на influencer-продвижение. Это даст первые сигналы для роста релиза.',
            style:
                TextStyle(color: AurixTokens.textSecondary, fontSize: 14, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SimpleField extends StatelessWidget {
  const _SimpleField({required this.ctrl, required this.label});
  final TextEditingController ctrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13),
      ),
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AurixTokens.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AurixTokens.accent, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 16,
              fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _SmartLinkStats extends StatelessWidget {
  const _SmartLinkStats({required this.aai});
  final ReleaseAaiModel? aai;

  @override
  Widget build(BuildContext context) {
    if (aai == null) {
      return Text(
        'Нет данных smart link по выбранному релизу.',
        style: TextStyle(color: AurixTokens.muted, fontSize: 12),
      );
    }
    final topCountries = aai!.countries.take(3).map((e) => e.key).join(', ');
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child:
                    _MetricTile(label: 'Переходы', value: '${aai!.views48h}')),
            const SizedBox(width: 8),
            Expanded(
                child: _MetricTile(label: 'Клики', value: '${aai!.clicks48h}')),
            const SizedBox(width: 8),
            Expanded(
                child: _MetricTile(
                    label: 'ТОП страны',
                    value: topCountries.isEmpty ? '—' : topCountries)),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
            height: 58,
            child: _TrendLine(
                points: aai!.trend.map((e) => e.value.toDouble()).toList())),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumMetricTile(
      label: label,
      value: value,
      compact: true,
    );
  }
}

class _TrendLine extends StatelessWidget {
  const _TrendLine({required this.points});
  final List<double> points;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 58),
      painter: _TrendPainter(points),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.points);
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final max = points.reduce((a, b) => a > b ? a : b);
    final safeMax = max <= 0 ? 1.0 : max;
    final step = size.width / (points.length - 1);
    final p = Path();
    for (var i = 0; i < points.length; i++) {
      final x = step * i;
      final y = size.height - ((points[i] / safeMax) * (size.height - 8)) - 4;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = AurixTokens.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points;
}

_PromoStage _stageFor(ReleaseModel? release) {
  if (release == null || release.releaseDate == null) {
    return _PromoStage.preRelease;
  }
  final now = DateTime.now();
  final releaseDate = release.releaseDate!;
  if (releaseDate.isAfter(now)) return _PromoStage.preRelease;
  if (now.difference(releaseDate).inDays <= 7) return _PromoStage.releaseWeek;
  return _PromoStage.postRelease;
}

double _statusProgress(String status) {
  const steps = [
    'submitted',
    'under_review',
    'approved',
    'in_progress',
    'completed'
  ];
  final idx = steps.indexOf(status);
  if (status == 'rejected') return 1.0;
  if (idx <= 0) return 0.16;
  return (idx + 1) / steps.length;
}

String _promoArtistStatusLabel(String status) => switch (status) {
      'submitted' => 'Отправлено',
      'under_review' => 'На рассмотрении',
      'approved' => 'На рассмотрении',
      'rejected' => 'Отклонено',
      'in_progress' => 'В работе',
      'completed' => 'Завершено',
      _ => status,
    };

double _leadProgress(String stage) => switch (stage) {
      'new' => 0.16,
      'in_work' => 0.32,
      'need_info' => 0.42,
      'offer_sent' => 0.58,
      'paid' => 0.72,
      'production' => 0.86,
      'done' => 1.0,
      'archived' => 1.0,
      _ => 0.16,
    };

String _crmArtistStatusLabel(String stage) => switch (stage) {
      'new' => 'Отправлено',
      'in_work' => 'На рассмотрении',
      'need_info' => 'Нужны данные',
      'offer_sent' => 'На рассмотрении',
      'paid' => 'В работе',
      'production' => 'В работе',
      'done' => 'Завершено',
      'archived' => 'Завершено',
      _ => 'Отправлено',
    };

String _crmStatusStyle(String stage) => switch (stage) {
      'need_info' => 'under_review',
      'done' => 'completed',
      'archived' => 'completed',
      'production' => 'in_progress',
      'paid' => 'approved',
      _ => 'submitted',
    };

String _productionStatusStyle(String status) => switch (status) {
      'waiting_artist' => 'under_review',
      'in_progress' => 'in_progress',
      'review' => 'approved',
      'done' => 'completed',
      'canceled' => 'rejected',
      _ => 'submitted',
    };

Future<void> _openNeedInfoDialog(
  BuildContext context,
  WidgetRef ref,
  CrmLeadModel lead,
) async {
  final ctrl = TextEditingController();
  var saving = false;
  final uid = ref.read(crmCurrentUserIdProvider);
  if (uid == null) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (dialogContext, setStateDialog) {
          return AlertDialog(
            backgroundColor: AurixTokens.bg1,
            title: const Text(
              'Добавить данные',
              style: TextStyle(color: AurixTokens.text),
            ),
            content: TextField(
              controller: ctrl,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(color: AurixTokens.text),
              decoration: const InputDecoration(
                hintText: 'Опиши, что отправляешь менеджеру',
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) return;
                        setStateDialog(() => saving = true);
                        try {
                          await ref.read(crmRepositoryProvider).addNote(
                                userId: lead.userId,
                                authorId: uid,
                                leadId: lead.id,
                                message: '[artist_data] $text',
                              );
                          ref.invalidate(myCrmLeadsProvider);
                          if (dialogContext.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Данные отправлены')),
                            );
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Ошибка: $e')),
                            );
                          }
                        } finally {
                          if (dialogContext.mounted) {
                            setStateDialog(() => saving = false);
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text('Отправить'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _promoTypeLabel(String type) => switch (type) {
      'dsp_pitch' => '🎧 DSP Pitch',
      'aurix_pitch' => '🔥 Aurix Pitch',
      'influencer' => '🎬 Influencer',
      'ads' => '📣 Реклама',
      _ => type,
    };

String _humanizePromoError(Object error) {
  final text = error.toString();
  final lower = text.toLowerCase();
  final missingPromoTable =
      (text.contains('PGRST205') || lower.contains('not found')) &&
          (lower.contains('promo_requests') || lower.contains('promo_events'));
  if (missingPromoTable) {
    return 'Модуль Промо ещё не подключён в базе. Примени миграцию `047_promo_requests_module.sql` в Supabase SQL Editor и перезапусти приложение.';
  }
  return 'Ошибка промо: $error';
}

class _PromotionLoadingSkeleton extends StatelessWidget {
  const _PromotionLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 18, width: 200),
              SizedBox(height: 8),
              PremiumSkeletonBox(height: 12, width: 280),
              SizedBox(height: 12),
              PremiumSkeletonBox(height: 44),
            ],
          ),
        ),
        SizedBox(height: 16),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 100)),
        SizedBox(height: 16),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 220)),
      ],
    );
  }
}
