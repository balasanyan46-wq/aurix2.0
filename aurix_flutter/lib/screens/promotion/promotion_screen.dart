import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/reports_provider.dart';
import 'package:aurix_flutter/app/auth/auth_store_provider.dart';

enum _CampaignStage { preSave, releaseWeek, postRelease }

extension _CampaignStageX on _CampaignStage {
  String get label => switch (this) { _CampaignStage.preSave => 'Pre-save', _CampaignStage.releaseWeek => 'Release week', _CampaignStage.postRelease => 'Post-release' };
  String get hint => switch (this) {
        _CampaignStage.preSave => 'До выхода релиза — собираем pre-save',
        _CampaignStage.releaseWeek => 'Релиз и первая неделя — максимум внимания',
        _CampaignStage.postRelease => 'После выхода — поддерживаем и анализируем',
      };
}

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  _CampaignStage _stage = _CampaignStage.releaseWeek;
  Set<String> _doneTasks = {};

  String? _uid() => ref.read(authStoreProvider).userId;

  String _prefsKeyFor(String uid) => 'promo_done_tasks:$uid';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid();
    if (uid == null || uid.isEmpty) return;
    final saved = prefs.getStringList(_prefsKeyFor(uid)) ?? [];
    if (mounted) setState(() => _doneTasks = saved.toSet());
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = _uid();
    if (uid == null || uid.isEmpty) return;
    await prefs.setStringList(_prefsKeyFor(uid), _doneTasks.toList());
  }

  List<({String day, String title, String? tip})> _tasksForStage() => switch (_stage) {
        _CampaignStage.preSave => [
            (day: 'D-14', title: 'Создать Smartlink и Pre-save', tip: 'Одна ссылка для всех платформ'),
            (day: 'D-12', title: 'Обложка и превью готовы', tip: null),
            (day: 'D-10', title: 'Тизер в сторис', tip: '15 сек — интрига без спойлеров'),
            (day: 'D-7', title: 'Анонс в соцсетях', tip: 'Пост + сторис + Reels/TikTok'),
            (day: 'D-5', title: 'Email база: превью трека', tip: null),
            (day: 'D-3', title: 'Финальный анонс', tip: '«Осталось 3 дня»'),
            (day: 'D-1', title: 'Countdown в профиле', tip: 'Обнови link-in-bio'),
          ],
        _CampaignStage.releaseWeek => [
            (day: 'D-Day', title: 'Релиз + плейлисты', tip: 'Отправь в плейлисты в первые часы'),
            (day: 'D+1', title: 'Пост «Вышло» во всех соцсетях', tip: null),
            (day: 'D+2', title: 'Stories с реакцией на первый день', tip: null),
            (day: 'D+3', title: 'Поддержка постов, ответы в комментах', tip: null),
            (day: 'D+5', title: 'Reels/TikTok с фрагментом трека', tip: null),
            (day: 'D+7', title: 'Итоги первой недели', tip: 'Цифры + благодарность фолловерам'),
          ],
        _CampaignStage.postRelease => [
            (day: 'D+7', title: 'Анализ первой недели', tip: 'Стримы, сохранения, охваты'),
            (day: 'D+10', title: 'Повторный пост для тех, кто пропустил', tip: null),
            (day: 'D+14', title: 'План следующего релиза', tip: 'Что улучшить, новая дата'),
            (day: 'D+21', title: 'UGC и репосты фанатов', tip: 'Собери и размести'),
          ],
      };

  String _taskKey(String day) => '${_stage.name}:$day';

  double _progress() {
    final tasks = _tasksForStage();
    if (tasks.isEmpty) return 0;
    return tasks.where((t) => _doneTasks.contains(_taskKey(t.day))).length / tasks.length;
  }

  void _toggleTask(String day) {
    final key = _taskKey(day);
    setState(() {
      if (_doneTasks.contains(key)) {
        _doneTasks.remove(key);
      } else {
        _doneTasks.add(key);
      }
    });
    _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final rows = ref.watch(userReportRowsProvider).valueOrNull ?? [];
    final releases = ref.watch(releasesProvider).valueOrNull ?? [];
    final totalStreams = rows.fold<int>(0, (s, r) => s + r.streams);
    final totalRevenue = rows.fold<double>(0, (s, r) => s + r.revenue);
    final liveReleases = releases.where((r) => r.status == 'approved').length;
    final fmt = NumberFormat('#,##0', 'en_US');
    final revFmt = NumberFormat('#,##0.00', 'en_US');

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStageSelector(),
              const SizedBox(height: 20),
              _buildKpiBlock(totalStreams, totalRevenue, liveReleases, fmt, revFmt),
              const SizedBox(height: 20),
              _buildProgressBar(),
              const SizedBox(height: 24),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildRoadmapCard()),
                    const SizedBox(width: 24),
                    SizedBox(width: 320, child: _buildTipsCard()),
                  ],
                )
              else ...[
                _buildRoadmapCard(),
                const SizedBox(height: 20),
                _buildTipsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageSelector() {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Этап кампании', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AurixTokens.text)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _CampaignStage.values.map((s) {
              final isActive = _stage == s;
              return ChoiceChip(
                label: Text(s.label),
                selected: isActive,
                onSelected: (_) => setState(() => _stage = s),
                selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
                backgroundColor: AurixTokens.glass(0.06),
                labelStyle: TextStyle(
                  color: isActive ? AurixTokens.orange : AurixTokens.muted,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
                side: BorderSide(color: isActive ? AurixTokens.orange : AurixTokens.stroke(0.12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(_stage.hint, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKpiBlock(int totalStreams, double totalRevenue, int liveReleases, NumberFormat fmt, NumberFormat revFmt) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _KpiItem(label: 'Стримы', value: fmt.format(totalStreams), hasData: totalStreams > 0)),
          Container(width: 1, height: 40, color: AurixTokens.stroke(0.15)),
          Expanded(child: _KpiItem(label: 'Доход', value: '\$${revFmt.format(totalRevenue)}', hasData: totalRevenue > 0)),
          Container(width: 1, height: 40, color: AurixTokens.stroke(0.15)),
          Expanded(child: _KpiItem(label: 'Релизы Live', value: '$liveReleases', hasData: liveReleases > 0)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final p = _progress();
    return AurixGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Прогресс этапа', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14)),
              Text('${(p * 100).round()}%', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: p, minHeight: 8, backgroundColor: AurixTokens.glass(0.15), valueColor: const AlwaysStoppedAnimation(AurixTokens.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoadmapCard() {
    final tasks = _tasksForStage();
    return AurixGlassCard(
      padding: EdgeInsets.all(horizontalPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: AurixTokens.orange, size: 24),
              const SizedBox(width: 12),
              Text('Чеклист', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AurixTokens.text)),
            ],
          ),
          const SizedBox(height: 20),
          ...tasks.asMap().entries.map((e) {
            final t = e.value;
            final isDone = _doneTasks.contains(_taskKey(t.day));
            return InkWell(
              onTap: () => _toggleTask(t.day),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(isDone ? Icons.check_circle : Icons.circle_outlined, color: isDone ? AurixTokens.orange : AurixTokens.muted, size: 22),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: TextStyle(
                              color: isDone ? AurixTokens.muted : AurixTokens.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (t.tip != null && !isDone)
                            Text(t.tip!, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(t.day, style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = switch (_stage) {
      _CampaignStage.preSave => ['Pre-save увеличивает вероятность попадания в алгоритмы.', 'Публикуй тизеры за 7–14 дней.', 'Используй countdown в Stories.'],
      _CampaignStage.releaseWeek => ['Отправляй в плейлисты в первые 24 часа.', 'Отвечай на каждый комментарий в день выхода.', 'Reels с фрагментом трека дают максимум охвата.'],
      _CampaignStage.postRelease => ['Собери цифры первой недели.', 'Репосты фанатов ценнее обычных постов.', 'Планируй следующий релиз, пока интерес высок.'],
    };

    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline_rounded, color: AurixTokens.orange, size: 20),
            const SizedBox(width: 8),
            Text('Советы', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AurixTokens.text)),
          ]),
          const SizedBox(height: 14),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: AurixTokens.orange, fontSize: 14)),
                    Expanded(child: Text(t, style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.45))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String label;
  final String value;
  final bool hasData;
  const _KpiItem({required this.label, required this.value, required this.hasData});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            hasData ? value : '—',
            style: TextStyle(color: hasData ? AurixTokens.text : AurixTokens.muted, fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
