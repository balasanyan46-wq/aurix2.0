import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/features/production/data/production_models.dart';
import 'package:aurix_flutter/features/production/presentation/production_item_detail.dart';
import 'package:aurix_flutter/data/models/crm_models.dart';
import 'package:aurix_flutter/data/providers/crm_providers.dart';

enum _Filter { all, inProgress, waitingArtist, done }

class ProductionPage extends ConsumerStatefulWidget {
  const ProductionPage({super.key});

  @override
  ConsumerState<ProductionPage> createState() => _ProductionPageState();
}

class _ProductionPageState extends ConsumerState<ProductionPage> {
  _Filter _filter = _Filter.all;
  Future<ProductionDashboard>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final uid = ref.read(currentUserProvider)?.id;
    if (uid == null) return;
    _future = ref.read(productionServiceProvider).getArtistDashboard(uid);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final myLeadsAsync = ref.watch(myCrmLeadsProvider);
    if (user == null) {
      return const Center(
        child: Text('Нужна авторизация',
            style: TextStyle(color: AurixTokens.muted)),
      );
    }
    final future = _future ??
        ref.read(productionServiceProvider).getArtistDashboard(user.id);

    return FutureBuilder<ProductionDashboard>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _ProductionLoadingSkeleton();
        }
        if (snap.hasError) {
          final msg = snap.error.toString();
          if (msg.contains('PGRST205') || msg.contains('production_orders')) {
            return Center(
              child: SizedBox(
                width: 760,
                child: PremiumSectionCard(
                  padding: const EdgeInsets.all(20),
                  child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AurixTokens.accent, size: 42),
                    SizedBox(height: 10),
                    Text(
                      'Нужно применить миграцию Продакшн',
                      style: TextStyle(
                          color: AurixTokens.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Выполни миграцию продакшн-модуля в backend и затем перезапусти приложение.',
                      style: TextStyle(
                          color: AurixTokens.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  ),
                ),
              ),
            );
          }
          return Center(
            child: Text('Ошибка: ${snap.error}',
                style: const TextStyle(color: AurixTokens.negative)),
          );
        }
        final data = snap.data!;
        final filtered = _applyFilter(data.items);
        final waiting =
            data.items.where((x) => x.status == 'waiting_artist').toList();

        if (data.orders.isEmpty) {
          return _onboarding();
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _myRequestsFromPromo(myLeadsAsync),
            const SizedBox(height: 12),
            _onYou(waiting),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _chip('Все', _Filter.all),
                _chip('В работе', _Filter.inProgress),
                _chip('Ожидает от меня', _Filter.waitingArtist),
                _chip('Готово', _Filter.done),
              ],
            ),
            const SizedBox(height: 14),
            ...data.orders.map((o) => _orderCard(
                o,
                filtered.where((i) => i.orderId == o.id).toList(),
                data,
                user.id)),
          ],
        );
      },
    );
  }

  Widget _onboarding() {
    return Center(
      child: SizedBox(
        width: 720,
        child: PremiumSectionCard(
          padding: const EdgeInsets.all(24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: AurixTokens.accent, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Здесь появятся твои услуги и прогресс работы.',
              style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Выбери, что нужно для релиза — и мы соберём процесс.',
              style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => context.go('/services'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: const Text('Выбрать услуги'),
              style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.accent,
                  foregroundColor: Colors.white),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _myRequestsFromPromo(AsyncValue<List<CrmLeadModel>> leadsAsync) {
    return PremiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            title: 'Мои заявки',
            subtitle: 'Заявки из Промо теперь отображаются в Продакшн.',
          ),
          const SizedBox(height: 10),
          leadsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: CircularProgressIndicator(color: AurixTokens.orange),
              ),
            ),
            error: (_, __) => const Text(
              'Не удалось загрузить заявки',
              style: TextStyle(color: AurixTokens.muted),
            ),
            data: (leads) {
              if (leads.isEmpty) {
                return const Text(
                  'Пока нет активных заявок.',
                  style: TextStyle(color: AurixTokens.muted),
                );
              }
              return Column(
                children: leads.take(6).map((lead) {
                  final progress = switch (lead.pipelineStage) {
                    'new' => 0.15,
                    'in_work' => 0.45,
                    'need_info' => 0.5,
                    'offer_sent' => 0.65,
                    'paid' => 0.75,
                    'production' => 0.85,
                    'done' => 1.0,
                    _ => 0.25,
                  };
                  final status = switch (lead.pipelineStage) {
                    'done' => 'completed',
                    'rejected' => 'rejected',
                    _ => 'in_progress',
                  };
                  final statusLabel = switch (lead.pipelineStage) {
                    'new' => 'Отправлено',
                    'in_work' => 'На рассмотрении',
                    'need_info' => 'Нужны данные',
                    'offer_sent' => 'Оффер',
                    'paid' => 'Оплачено',
                    'production' => 'В работе',
                    'done' => 'Завершено',
                    _ => lead.pipelineStage,
                  };

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AurixTokens.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AurixTokens.stroke(0.16)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lead.title?.trim().isNotEmpty == true
                                    ? lead.title!
                                    : (lead.type ?? lead.source),
                                style: const TextStyle(
                                  color: AurixTokens.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            PremiumStatusPill(label: statusLabel, status: status),
                          ],
                        ),
                        if (lead.dueAt != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Дедлайн: ${DateFormat('dd.MM.yyyy').format(lead.dueAt!)}',
                            style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                          ),
                        ],
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
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _onYou(List<ProductionOrderItem> waiting) {
    if (waiting.isEmpty) return const SizedBox.shrink();
    final top = waiting.take(2).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x16F97316),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33F97316)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сейчас от тебя нужно',
              style: TextStyle(
                  color: AurixTokens.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...top.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${i.service?.title ?? 'Услуга'}: ${(i.brief['what_needed_from_artist'] ?? 'Загрузить исходники').toString()}',
                  style: const TextStyle(color: AurixTokens.textSecondary),
                ),
              )),
        ],
      ),
    );
  }

  Widget _orderCard(
    ProductionOrder order,
    List<ProductionOrderItem> items,
    ProductionDashboard data,
    String userId,
  ) {
    final releaseTitle = (order.releaseId != null)
        ? data.releaseTitleById[order.releaseId!]
        : null;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return PremiumHoverLift(
      enabled: isDesktop,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order.title.isNotEmpty
                  ? order.title
                  : (releaseTitle ?? 'Текущий релиз'),
              style: const TextStyle(
                  color: AurixTokens.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              const Text('По этому процессу пока нет услуг',
                  style: TextStyle(color: AurixTokens.muted))
            else
              ...items.map((i) => _itemRow(i, userId)),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(ProductionOrderItem i, String userId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.service?.title ?? 'Услуга',
                    style: const TextStyle(
                        color: AurixTokens.text, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  productionStatusLabel(i.status),
                  style: const TextStyle(
                      color: AurixTokens.textSecondary, fontSize: 12),
                ),
                if (i.deadlineAt != null)
                  Text(
                    'Дедлайн: ${i.deadlineAt!.day.toString().padLeft(2, '0')}.${i.deadlineAt!.month.toString().padLeft(2, '0')}',
                    style:
                        const TextStyle(color: AurixTokens.muted, fontSize: 12),
                  ),
                if (i.assignee?.fullName.isNotEmpty == true)
                  Text('Исполнитель: ${i.assignee!.fullName}',
                      style: const TextStyle(
                          color: AurixTokens.muted, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              const role = 'artist';
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ProductionItemDetailSheet(
                  item: i,
                  currentUserId: userId,
                  currentUserRole: role,
                  service: ref.read(productionServiceProvider),
                  onChanged: () {
                    setState(_reload);
                  },
                ),
              );
            },
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  List<ProductionOrderItem> _applyFilter(List<ProductionOrderItem> items) {
    switch (_filter) {
      case _Filter.all:
        return items;
      case _Filter.inProgress:
        return items
            .where((i) => i.status == 'in_progress' || i.status == 'review')
            .toList();
      case _Filter.waitingArtist:
        return items.where((i) => i.status == 'waiting_artist').toList();
      case _Filter.done:
        return items.where((i) => i.status == 'done').toList();
    }
  }

  Widget _chip(String label, _Filter f) => ChoiceChip(
        label: Text(label),
        selected: _filter == f,
        onSelected: (_) => setState(() => _filter = f),
        selectedColor: AurixTokens.accent.withValues(alpha: 0.22),
        labelStyle: TextStyle(
            color: _filter == f ? AurixTokens.text : AurixTokens.muted),
      );
}

class _ProductionLoadingSkeleton extends StatelessWidget {
  const _ProductionLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 16, width: 180),
              SizedBox(height: 10),
              PremiumSkeletonBox(height: 12, width: 280),
            ],
          ),
        ),
        SizedBox(height: 12),
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 16, width: 220),
              SizedBox(height: 10),
              PremiumSkeletonBox(height: 52),
              SizedBox(height: 8),
              PremiumSkeletonBox(height: 52),
            ],
          ),
        ),
        SizedBox(height: 12),
        PremiumSectionCard(child: PremiumSkeletonBox(height: 120)),
      ],
    );
  }
}
