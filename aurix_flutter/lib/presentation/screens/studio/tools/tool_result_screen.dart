import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

class ToolResultScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  final String toolKey;
  final Map<String, dynamic> data;
  final bool isDemo;

  const ToolResultScreen({
    super.key,
    required this.release,
    required this.toolKey,
    required this.data,
    required this.isDemo,
  });

  @override
  ConsumerState<ToolResultScreen> createState() => _ToolResultScreenState();
}

class _ToolResultScreenState extends ConsumerState<ToolResultScreen> {
  bool _regenerating = false;

  String get _title => switch (widget.toolKey) {
    'growth-plan' => 'Карта роста',
    'budget-plan' => 'Бюджет-план',
    'release-packaging' => 'AI-Упаковка',
    'content-plan-14' => 'Контент-план',
    'playlist-pitch-pack' => 'Питч-пакет',
    _ => 'Результат',
  };

  Map<String, dynamic> get data => widget.data;

  Future<void> _regenerate() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пересоздать?'),
        content: const Text('Текущий результат будет удалён. AI сгенерирует новый, персональный ответ.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Пересоздать')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _regenerating = true);
    await ref.read(toolServiceProvider).deleteSaved(widget.release.id, widget.toolKey);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_regenerating) {
      return Scaffold(
        appBar: AppBar(title: Text('$_title: ${widget.release.title}')),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Удаляем старый результат...'),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$_title: ${widget.release.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Сгенерировать заново',
            onPressed: _regenerate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isDemo) _demoBanner(context),
          ...switch (widget.toolKey) {
            'growth-plan' => _buildGrowthPlan(context),
            'budget-plan' => _buildBudgetPlan(context),
            'release-packaging' => _buildPackaging(context),
            'content-plan-14' => _buildContentPlan(context),
            'playlist-pitch-pack' => _buildPitchPack(context),
            _ => [Text('Неизвестный инструмент: ${widget.toolKey}')],
          },
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _regenerate,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Пересоздать результат'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─── GROWTH PLAN ────────────────────────────────────────────────────

  List<Widget> _buildGrowthPlan(BuildContext context) {
    final summary = data['summary'] as String? ?? '';
    final pos = data['positioning'] as Map<String, dynamic>? ?? {};
    final risks = _strList('risks');
    final levers = _strList('levers');
    final angles = _strList('content_angles');
    final quickWins = _strList('quick_wins_48h');
    final weekly = _mapList('weekly_focus');
    final days = _mapList('days');
    final checkpoints = _mapList('checkpoints');

    return [
      if (summary.isNotEmpty) ...[_card(context, Icons.summarize_rounded, 'Резюме', Text(summary)), const SizedBox(height: 12)],
      if (pos.isNotEmpty) ...[
        _card(context, Icons.gps_fixed_rounded, 'Позиционирование', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pos['one_liner'] != null) _labelValue(context, 'One-liner', pos['one_liner'].toString()),
            if (pos['angle'] != null) _labelValue(context, 'Угол', pos['angle'].toString()),
            if (pos['audience'] != null) _labelValue(context, 'Аудитория', pos['audience'].toString()),
          ],
        )),
        const SizedBox(height: 12),
      ],
      if (quickWins.isNotEmpty) ...[_card(context, Icons.bolt_rounded, 'Быстрые победы (48ч)', _bulletList(context, quickWins, Icons.flash_on_rounded, const Color(0xFFF59E0B))), const SizedBox(height: 12)],
      if (risks.isNotEmpty) ...[_card(context, Icons.warning_amber_rounded, 'Риски', _bulletList(context, risks, Icons.warning_rounded, const Color(0xFFEF4444))), const SizedBox(height: 12)],
      if (levers.isNotEmpty) ...[_card(context, Icons.rocket_launch_rounded, 'Рычаги роста', _bulletList(context, levers, Icons.trending_up_rounded, const Color(0xFF22C55E))), const SizedBox(height: 12)],
      if (angles.isNotEmpty) ...[_card(context, Icons.lightbulb_rounded, 'Контент-углы', _bulletList(context, angles, Icons.lightbulb_outline_rounded, const Color(0xFF8B5CF6))), const SizedBox(height: 12)],
      if (weekly.isNotEmpty) ...[
        _card(context, Icons.calendar_view_week_rounded, 'Фокус по неделям', Column(
          children: weekly.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _numBadge(context, '${w['week'] ?? '?'}'),
                const SizedBox(width: 12),
                Expanded(child: Text(w['focus']?.toString() ?? '', style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          )).toList(),
        )),
        const SizedBox(height: 12),
      ],
      if (checkpoints.isNotEmpty) ...[
        _card(context, Icons.flag_rounded, 'Контрольные точки', Column(
          children: checkpoints.map((cp) {
            final kpi = (cp['kpi'] as List?)?.cast<String>() ?? [];
            final actions = (cp['actions'] as List?)?.cast<String>() ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('День ${cp['day'] ?? '?'}', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  ...kpi.map((k) => _iconText(context, Icons.check_circle_outline, k, const Color(0xFF22C55E))),
                  ...actions.map((a) => _iconText(context, Icons.arrow_forward_rounded, a, Theme.of(context).colorScheme.primary)),
                ],
              ),
            );
          }).toList(),
        )),
        const SizedBox(height: 12),
      ],
      if (days.isNotEmpty) _card(context, Icons.view_day_rounded, 'План по дням (${days.length})', _DaysExpansion(days: days)),
    ];
  }

  // ─── BUDGET PLAN ────────────────────────────────────────────────────

  List<Widget> _buildBudgetPlan(BuildContext context) {
    final summary = data['summary'] as String? ?? '';
    final allocation = _mapList('allocation');
    final risks = _strList('risks');
    final mustDo = _strList('must_do');
    final antiWaste = _strList('anti_waste');
    final cheapest = data['cheapest_strategy'] as String? ?? '';
    final dontSpend = _strList('dont_spend_on');
    final mustSpend = _strList('must_spend_on');
    final nextSteps = _strList('next_steps');

    return [
      if (summary.isNotEmpty) ...[_card(context, Icons.summarize_rounded, 'Резюме', Text(summary)), const SizedBox(height: 12)],
      if (allocation.isNotEmpty) ...[_card(context, Icons.pie_chart_rounded, 'Распределение', _AllocationChart(allocation: allocation)), const SizedBox(height: 12)],
      if (risks.isNotEmpty) ...[_card(context, Icons.warning_amber_rounded, 'Куда сольётся бюджет', _bulletList(context, risks, Icons.money_off_rounded, const Color(0xFFEF4444))), const SizedBox(height: 12)],
      if (mustDo.isNotEmpty) ...[_card(context, Icons.priority_high_rounded, 'Обязательно сделать', _bulletList(context, mustDo, Icons.check_circle_rounded, const Color(0xFF22C55E))), const SizedBox(height: 12)],
      if (antiWaste.isNotEmpty) ...[_card(context, Icons.block_rounded, 'Анти-слив', _bulletList(context, antiWaste, Icons.do_not_disturb_rounded, const Color(0xFFEF4444))), const SizedBox(height: 12)],
      if (cheapest.isNotEmpty) ...[_card(context, Icons.savings_rounded, 'Стратегия мин. бюджета', Text(cheapest)), const SizedBox(height: 12)],
      if (mustSpend.isNotEmpty) ...[_card(context, Icons.check_circle_rounded, 'Обязательно потратить на', _bulletList(context, mustSpend, Icons.check_rounded, const Color(0xFF22C55E))), const SizedBox(height: 12)],
      if (dontSpend.isNotEmpty) ...[_card(context, Icons.block_rounded, 'Не тратить на', _bulletList(context, dontSpend, Icons.close_rounded, const Color(0xFFEF4444))), const SizedBox(height: 12)],
      if (nextSteps.isNotEmpty) ...[_card(context, Icons.checklist_rounded, 'Следующие шаги', _numberedList(context, nextSteps)), const SizedBox(height: 12)],
    ];
  }

  // ─── PACKAGING ──────────────────────────────────────────────────────

  List<Widget> _buildPackaging(BuildContext context) {
    final titles = _strList('title_variants');
    final descs = data['description_platforms'] as Map<String, dynamic>? ?? {};
    final story = data['storytelling'] as String? ?? '';
    final hooks = _strList('hooks');
    final ctas = _strList('cta_variants');

    return [
      if (titles.isNotEmpty) ...[
        _card(context, Icons.title_rounded, 'Варианты названий', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: titles.asMap().entries.map((e) => _copyableRow(context, '${e.key + 1}. ${e.value}')).toList(),
        )),
        const SizedBox(height: 12),
      ],
      if (story.isNotEmpty) ...[_card(context, Icons.auto_stories_rounded, 'Сторителлинг', _copyableText(context, story)), const SizedBox(height: 12)],
      if (descs.isNotEmpty) ...[
        _card(context, Icons.description_rounded, 'Описания для платформ', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: descs.entries.map((e) => _platformBlock(context, e.key, e.value.toString())).toList(),
        )),
        const SizedBox(height: 12),
      ],
      if (hooks.isNotEmpty) ...[
        _card(context, Icons.videocam_rounded, 'Хуки для видео (${hooks.length})', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: hooks.map((h) => _copyableRow(context, h)).toList(),
        )),
        const SizedBox(height: 12),
      ],
      if (ctas.isNotEmpty) ...[
        _card(context, Icons.touch_app_rounded, 'Призывы к действию', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ctas.map((c) => _copyableRow(context, c)).toList(),
        )),
        const SizedBox(height: 12),
      ],
    ];
  }

  // ─── CONTENT PLAN ───────────────────────────────────────────────────

  List<Widget> _buildContentPlan(BuildContext context) {
    final strategy = data['strategy'] as String? ?? '';
    final days = _mapList('days');

    return [
      if (strategy.isNotEmpty) ...[_card(context, Icons.lightbulb_rounded, 'Стратегия', Text(strategy)), const SizedBox(height: 12)],
      if (days.isNotEmpty) _card(context, Icons.calendar_month_rounded, 'План на 14 дней', Column(
        children: days.map((d) {
          final day = d['day'] ?? '?';
          final format = d['format'] ?? '';
          final hook = d['hook'] as String? ?? '';
          final script = d['script'] as String? ?? '';
          final shotlist = (d['shotlist'] as List?)?.cast<String>() ?? [];
          final cta = d['cta'] as String? ?? '';

          return ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            leading: _numBadge(context, '$day'),
            title: Text('$format', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            subtitle: Text(hook, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            children: [
              if (hook.isNotEmpty) ...[
                _label(context, 'Хук'), _copyableText(context, hook), const SizedBox(height: 8),
              ],
              if (script.isNotEmpty) ...[
                _label(context, 'Сценарий'), _copyableText(context, script), const SizedBox(height: 8),
              ],
              if (shotlist.isNotEmpty) ...[
                _label(context, 'Шотлист'),
                ...shotlist.map((s) => _iconText(context, Icons.camera_alt_outlined, s, Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 8),
              ],
              if (cta.isNotEmpty) ...[
                _label(context, 'CTA'), _copyableText(context, cta),
              ],
            ],
          );
        }).toList(),
      )),
    ];
  }

  // ─── PITCH PACK ─────────────────────────────────────────────────────

  List<Widget> _buildPitchPack(BuildContext context) {
    final shortPitch = data['short_pitch'] as String? ?? '';
    final longPitch = data['long_pitch'] as String? ?? '';
    final subjects = _strList('email_subjects');
    final press = _strList('press_lines');
    final bio = data['artist_bio'] as String? ?? '';

    return [
      if (shortPitch.isNotEmpty) ...[_card(context, Icons.flash_on_rounded, 'Короткий питч', _copyableText(context, shortPitch)), const SizedBox(height: 12)],
      if (longPitch.isNotEmpty) ...[_card(context, Icons.article_rounded, 'Развёрнутый питч', _copyableText(context, longPitch)), const SizedBox(height: 12)],
      if (subjects.isNotEmpty) ...[
        _card(context, Icons.email_rounded, 'Темы для email', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: subjects.map((s) => _copyableRow(context, s)).toList(),
        )),
        const SizedBox(height: 12),
      ],
      if (press.isNotEmpty) ...[
        _card(context, Icons.newspaper_rounded, 'Пресс-строки', Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: press.map((p) => _copyableRow(context, p)).toList(),
        )),
        const SizedBox(height: 12),
      ],
      if (bio.isNotEmpty) ...[_card(context, Icons.person_rounded, 'Биография артиста', _copyableText(context, bio)), const SizedBox(height: 12)],
    ];
  }

  // ─── HELPERS ────────────────────────────────────────────────────────

  List<String> _strList(String key) => (data[key] as List?)?.cast<String>() ?? [];
  List<Map<String, dynamic>> _mapList(String key) => (data[key] as List?)?.cast<Map<String, dynamic>>() ?? [];

  Widget _demoBanner(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Демо-версия', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
        const SizedBox(height: 2),
        Text('Перейдите на Прорыв для полной персонализации', style: Theme.of(context).textTheme.bodySmall),
      ])),
      TextButton(onPressed: () => context.push('/subscription'), child: const Text('Открыть')),
    ]),
  );

  Widget _card(BuildContext context, IconData icon, String title, Widget child) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Flexible(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _bulletList(BuildContext context, List<String> items, IconData icon, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items.map((i) => _iconText(context, icon, i, color)).toList(),
  );

  Widget _iconText(BuildContext context, IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
    ]),
  );

  Widget _numberedList(BuildContext context, List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _numBadge(context, '${e.key + 1}'),
        const SizedBox(width: 10),
        Expanded(child: Text(e.value, style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    )).toList(),
  );

  Widget _numBadge(BuildContext context, String text) => Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    alignment: Alignment.center,
    child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 13)),
  );

  Widget _labelValue(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.bodyMedium),
    ]),
  );

  Widget _label(BuildContext context, String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(
      fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
  );

  Widget _copyableText(BuildContext context, String text) => GestureDetector(
    onLongPress: () {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)));
    },
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );

  Widget _copyableRow(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
      IconButton(
        icon: const Icon(Icons.copy_rounded, size: 16),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)));
        },
      ),
    ]),
  );

  Widget _platformBlock(BuildContext context, String platform, String text) {
    final label = switch (platform) {
      'yandex' => 'Яндекс Музыка',
      'vk' => 'VK Музыка',
      'spotify' => 'Spotify',
      'apple' => 'Apple Music',
      _ => platform,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано'), duration: Duration(seconds: 1)));
            },
          ),
        ]),
        const SizedBox(height: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );
  }
}

class _AllocationChart extends StatelessWidget {
  final List<Map<String, dynamic>> allocation;
  const _AllocationChart({required this.allocation});

  static const _colors = [Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFFF59E0B), Color(0xFF22C55E), Color(0xFF6B7280)];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(height: 28, child: Row(
          children: allocation.asMap().entries.map((e) {
            final p = (e.value['percent'] as num?)?.toDouble() ?? 0;
            if (p <= 0) return const SizedBox.shrink();
            return Expanded(flex: (p * 10).round(), child: Container(color: _colors[e.key % _colors.length]));
          }).toList(),
        )),
      ),
      const SizedBox(height: 16),
      ...allocation.asMap().entries.map((e) {
        final i = e.value;
        final c = _colors[e.key % _colors.length];
        return Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 14, height: 14, margin: const EdgeInsets.only(top: 3), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text('${i['category'] ?? ''}', style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
              Text('${i['amount'] ?? 0} ${i['currency'] ?? '₽'} (${i['percent'] ?? 0}%)', style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            if ((i['notes'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2),
              child: Text(i['notes'].toString(), style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)))),
          ])),
        ]));
      }),
    ]);
  }
}

class _DaysExpansion extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _DaysExpansion({required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(children: days.map((d) {
      final day = d['day'] ?? '?';
      final title = d['title'] ?? 'День $day';
      final tasks = (d['tasks'] as List?)?.cast<String>() ?? [];
      final outputs = (d['outputs'] as List?)?.cast<String>() ?? [];
      final timeMin = d['time_min'] ?? 0;

      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text('$day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.primary)),
        ),
        title: Text(title.toString(), style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text('~$timeMin мин', style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.45))),
        children: [
          if (tasks.isNotEmpty) ...[
            Align(alignment: Alignment.centerLeft, child: Text('Задачи:', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.6)))),
            const SizedBox(height: 4),
            ...tasks.map((t) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• ', style: TextStyle(color: cs.primary)),
              Expanded(child: Text(t, style: tt.bodySmall)),
            ]))),
          ],
          if (outputs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: Text('Результаты:', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF22C55E)))),
            const SizedBox(height: 4),
            ...outputs.map((o) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.check_rounded, size: 14, color: Color(0xFF22C55E)),
              const SizedBox(width: 6),
              Expanded(child: Text(o, style: tt.bodySmall)),
            ]))),
          ],
        ],
      );
    }).toList());
  }
}
