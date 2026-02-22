import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

enum _CampaignStage {
  preSave,
  releaseWeek,
  postRelease,
}

extension _CampaignStageX on _CampaignStage {
  String get label {
    switch (this) {
      case _CampaignStage.preSave:
        return 'Pre-save';
      case _CampaignStage.releaseWeek:
        return 'Release week';
      case _CampaignStage.postRelease:
        return 'Post-release';
    }
  }

  String get hint {
    switch (this) {
      case _CampaignStage.preSave:
        return 'До выхода релиза — собираем pre-save';
      case _CampaignStage.releaseWeek:
        return 'Релиз и первая неделя — максимум внимания';
      case _CampaignStage.postRelease:
        return 'После выхода — поддерживаем и анализируем';
    }
  }
}

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  _CampaignStage _stage = _CampaignStage.releaseWeek;
  final Set<String> _doneTasks = {'D-14', 'D-7', 'D-3', 'D-1', 'D-Day'};

  List<({String day, String title, String? tip})> _tasksForStage() {
    switch (_stage) {
      case _CampaignStage.preSave:
        return [
          (day: 'D-14', title: 'Создать Smartlink и Pre-save', tip: 'Одна ссылка для всех платформ'),
          (day: 'D-12', title: 'Обложка и превью готовы', tip: null),
          (day: 'D-10', title: 'Тизер в сторис', tip: '15 сек — интрига без спойлеров'),
          (day: 'D-7', title: 'Анонс в соцсетях', tip: 'Пост + сторис + Reels/TikTok'),
          (day: 'D-5', title: 'Email база: превью трека', tip: null),
          (day: 'D-3', title: 'Финальный анонс', tip: '«Осталось 3 дня»'),
          (day: 'D-1', title: 'Countdown в профиле', tip: 'Обнови link-in-bio'),
        ];
      case _CampaignStage.releaseWeek:
        return [
          (day: 'D-Day', title: 'Релиз + плейлисты', tip: 'Отправь в плейлисты в первые часы'),
          (day: 'D+1', title: 'Пост «Вышло» во всех соцсетях', tip: null),
          (day: 'D+2', title: 'Stories с реакцией на первый день', tip: null),
          (day: 'D+3', title: 'Поддержка постов, ответы в комментах', tip: null),
          (day: 'D+5', title: 'Reels/TikTok с фрагментом трека', tip: null),
          (day: 'D+7', title: 'Итоги первой недели', tip: 'Цифры + благодарность фолловерам'),
        ];
      case _CampaignStage.postRelease:
        return [
          (day: 'D+7', title: 'Анализ первой недели', tip: 'Стримы, сохранения, охваты'),
          (day: 'D+10', title: 'Повторный пост для тех, кто пропустил', tip: null),
          (day: 'D+14', title: 'План следующего релиза', tip: 'Что улучшить, новая дата'),
          (day: 'D+21', title: 'UGC и репосты фанатов', tip: 'Собери и размести'),
        ];
    }
  }

  ({String title, String body})? _todayTask() {
    final tasks = _tasksForStage();
    if (tasks.isEmpty) return null;
    final idx = tasks.length ~/ 2;
    return (title: tasks[idx].title, body: tasks[idx].tip ?? tasks[idx].title);
  }

  double _progress() {
    final tasks = _tasksForStage();
    if (tasks.isEmpty) return 0;
    final done = tasks.where((t) => _doneTasks.contains(t.day)).length;
    return done / tasks.length;
  }

  void _toggleTask(String day) {
    setState(() {
      if (_doneTasks.contains(day)) {
        _doneTasks.remove(day);
      } else {
        _doneTasks.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStageSelector(),
              const SizedBox(height: 20),
              _buildKpiBlock(),
              const SizedBox(height: 20),
              _buildProgressBar(),
              const SizedBox(height: 24),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _buildTodayCard(),
                          const SizedBox(height: 20),
                          _buildRoadmapCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 320,
                      child: Column(
                        children: [
                          _buildAiAssistantCard(),
                          const SizedBox(height: 20),
                          _buildQuickToolsCard(),
                          const SizedBox(height: 20),
                          _buildTipsCard(),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildTodayCard(),
                    const SizedBox(height: 20),
                    _buildRoadmapCard(),
                    const SizedBox(height: 20),
                    _buildAiAssistantCard(),
                    const SizedBox(height: 20),
                    _buildQuickToolsCard(),
                    const SizedBox(height: 20),
                    _buildTipsCard(),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L10n.t(context, 'promo'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AurixTokens.text,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'План продвижения релиза — чек-лист и инструменты',
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildStageSelector() {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Этап кампании',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AurixTokens.text,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _CampaignStage.values.map((s) {
              final isActive = _stage == s;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _stage = s),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AurixTokens.orange.withValues(alpha: 0.2)
                            : AurixTokens.glass(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? AurixTokens.orange : AurixTokens.stroke(0.12),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        s.label,
                        style: TextStyle(
                          color: isActive ? AurixTokens.orange : AurixTokens.muted,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            _stage.hint,
            style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBlock() {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _KpiItem(
              label: 'Pre-save',
              value: '124',
              target: '200',
              unit: '',
            ),
          ),
          Container(width: 1, height: 40, color: AurixTokens.stroke(0.15)),
          Expanded(
            child: _KpiItem(
              label: 'Охват D+1',
              value: '2.4k',
              target: '5k',
              unit: '',
            ),
          ),
          Container(width: 1, height: 40, color: AurixTokens.stroke(0.15)),
          Expanded(
            child: _KpiItem(
              label: 'Saves',
              value: '89',
              target: '150',
              unit: '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantCard() {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AurixTokens.orange, size: 22),
              const SizedBox(width: 10),
              Text(
                'AI‑помощник',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.text,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Следующий шаг: опубликуй пост «Вышло» с ссылкой на релиз. Добавь короткое видео или GIF с треком — охват вырастет на 40%.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _showSnack('AI‑совет принят'),
            child: Text('Сгенерировать текст поста', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final p = _progress();
    return AurixGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Прогресс этапа',
                      style: TextStyle(
                        color: AurixTokens.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${(p * 100).round()}%',
                      style: TextStyle(
                        color: AurixTokens.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 8,
                    backgroundColor: AurixTokens.glass(0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(AurixTokens.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard() {
    final today = _todayTask();
    if (today == null) return const SizedBox.shrink();
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.today_rounded, color: AurixTokens.orange, size: 22),
              ),
              const SizedBox(width: 14),
              Text(
                'Сделать сегодня',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.orange,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            today.title,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (today.body != today.title) ...[
            const SizedBox(height: 8),
            Text(
              today.body,
              style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoadmapCard() {
    final tasks = _tasksForStage();
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: AurixTokens.orange, size: 24),
              const SizedBox(width: 12),
              Text(
                'Таймлайн кампании',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.text,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _progress() >= 1 ? AurixTokens.orange.withValues(alpha: 0.15) : AurixTokens.glass(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _progress() >= 1 ? AurixTokens.orange : AurixTokens.stroke(0.12)),
                ),
                child: Text(
                  _progress() >= 1 ? 'Завершено' : 'В работе',
                  style: TextStyle(
                    color: _progress() >= 1 ? AurixTokens.orange : AurixTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...tasks.asMap().entries.map((e) {
            final i = e.key;
            final t = e.value;
            final isDone = _doneTasks.contains(t.day);
            return _RoadmapRow(
              day: t.day,
              title: t.title,
              tip: t.tip,
              isDone: isDone,
              showConnector: i < tasks.length - 1,
              onTap: () => _toggleTask(t.day),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickToolsCard() {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Быстрые действия',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AurixTokens.text,
                ),
          ),
          const SizedBox(height: 16),
          _QuickActionTile(
            icon: Icons.link_rounded,
            label: L10n.t(context, 'smartlink'),
            subtitle: 'Одна ссылка для всех платформ',
            onTap: () => _showSnack('${L10n.t(context, 'smartlink')} — ${L10n.t(context, 'soon')}'),
          ),
          _QuickActionTile(
            icon: Icons.save_rounded,
            label: L10n.t(context, 'preSave'),
            subtitle: 'Собери сохранения до выхода',
            onTap: () => _showSnack('${L10n.t(context, 'preSave')} — ${L10n.t(context, 'soon')}'),
          ),
          _QuickActionTile(
            icon: Icons.schedule_rounded,
            label: L10n.t(context, 'countdownTimer'),
            subtitle: 'Таймер до релиза',
            value: '12д',
            onTap: () {},
          ),
          _QuickActionTile(
            icon: Icons.description_rounded,
            label: L10n.t(context, 'contentKitShort'),
            subtitle: 'Посты, подписи, пресс-релиз',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = _tipsForStage();
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: AurixTokens.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Советы',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.text,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tips.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: AurixTokens.orange, fontSize: 14)),
                  Expanded(
                    child: Text(
                      t,
                      style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _tipsForStage() {
    switch (_stage) {
      case _CampaignStage.preSave:
        return [
          'Pre-save увеличивает вероятность попадания в алгоритмы в день релиза.',
          'Публикуй тизеры за 7–14 дней — не раньше, иначе интерес угаснет.',
          'Используй countdown в Stories и bio для напоминания.',
        ];
      case _CampaignStage.releaseWeek:
        return [
          'Отправляй релиз в плейлисты в первые 24 часа — алгоритмы это любят.',
          'Отвечай на каждый комментарий в день выхода — это усиливает охват.',
          'Reels/TikTok с фрагментом трека в D+1–D+3 дают максимум.',
        ];
      case _CampaignStage.postRelease:
        return [
          'Собери цифры первой недели — пригодится для следующих релизов.',
          'Репосты фанатов и UGC ценнее обычных постов.',
          'Планируй следующий релиз, пока интерес ещё высок.',
        ];
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AurixTokens.bg2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

String _shortDay(String day) {
  if (day == 'D-Day') return '0';
  return day.replaceFirst('D', '').replaceFirst('-', '-');
}

class _RoadmapRow extends StatelessWidget {
  final String day;
  final String title;
  final String? tip;
  final bool isDone;
  final bool showConnector;
  final VoidCallback onTap;

  const _RoadmapRow({
    required this.day,
    required this.title,
    this.tip,
    required this.isDone,
    required this.showConnector,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDone
                        ? AurixTokens.orange.withValues(alpha: 0.25)
                        : AurixTokens.glass(0.08),
                    border: Border.all(
                      color: isDone ? AurixTokens.orange : AurixTokens.stroke(0.12),
                    ),
                  ),
                  child: Center(
                    child: isDone
                        ? Icon(Icons.check_rounded, color: AurixTokens.orange, size: 20)
                        : Text(
                            _shortDay(day),
                            style: TextStyle(
                              color: AurixTokens.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                  ),
                ),
                if (showConnector)
                  Container(
                    width: 2,
                    height: 28,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: AurixTokens.stroke(0.12),
                  ),
              ],
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day,
                      style: TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        color: isDone ? AurixTokens.muted : AurixTokens.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (tip != null && !isDone) ...[
                      const SizedBox(height: 4),
                      Text(
                        tip!,
                        style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String label;
  final String value;
  final String target;
  final String unit;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w700)),
              Text(' / $target', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String? value;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AurixTokens.stroke(0.08)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AurixTokens.orange),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: AurixTokens.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AurixTokens.muted,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (value != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AurixTokens.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      value!,
                      style: TextStyle(
                        color: AurixTokens.orange,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
