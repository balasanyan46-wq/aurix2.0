import 'dart:convert';

import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/budget_form_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/content_plan_form_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/growth_plan_form_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/packaging_form_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/pitch_pack_form_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_result_models.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_result_normalizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  late final ToolNormalizationOutcome _outcome;
  late final bool _showDebugPanel = () {
    var enabled = false;
    assert(() {
      enabled = true;
      return true;
    }());
    return enabled;
  }();

  @override
  void initState() {
    super.initState();
    _outcome = ToolResultNormalizer.normalize(widget.toolKey, widget.data);
  }

  String get _title => switch (widget.toolKey) {
        'growth-plan' => 'Карта роста релиза',
        'budget-plan' => 'Бюджет-менеджер',
        'release-packaging' => 'AI-упаковка релиза',
        'content-plan-14' => 'Контент-план Reels/Shorts',
        'playlist-pitch-pack' => 'Плейлист-питч пакет',
        _ => 'Studio AI результат',
      };

  Color get _accent => switch (widget.toolKey) {
        'growth-plan' => const Color(0xFF22C55E),
        'budget-plan' => const Color(0xFFFF6B35),
        'release-packaging' => const Color(0xFF8B5CF6),
        'content-plan-14' => const Color(0xFFEC4899),
        'playlist-pitch-pack' => const Color(0xFF0EA5E9),
        _ => const Color(0xFFF59E0B),
      };

  void _openTool() {
    Widget screen;
    switch (widget.toolKey) {
      case 'growth-plan':
        screen = GrowthPlanFormScreen(release: widget.release);
      case 'budget-plan':
        screen = BudgetFormScreen(release: widget.release);
      case 'release-packaging':
        screen = PackagingFormScreen(release: widget.release);
      case 'content-plan-14':
        screen = ContentPlanFormScreen(release: widget.release);
      case 'playlist-pitch-pack':
        screen = PitchPackFormScreen(release: widget.release);
      default:
        return;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _copyResult() async {
    final r = _outcome.result;
    if (r == null) return;
    final lines = <String>[r.hero.title, r.hero.subtitle, ...r.summaryLines];
    if (r.priorities.isNotEmpty) {
      lines.add('');
      lines.add('Приоритеты:');
      for (final p in r.priorities) {
        lines.add('- ${p.title}: ${p.why}');
      }
    }
    await _copyText(lines.join('\n'));
  }

  Future<void> _copyFullJson() async {
    final r = _outcome.result;
    if (r == null) return;
    await _copyText(const JsonEncoder.withIndent('  ').convert(r.toJson()));
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано')));
  }

  @override
  Widget build(BuildContext context) {
    if (!_outcome.isOk) {
      return _errorScaffold(context);
    }
    final result = _outcome.result!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          TextButton.icon(
            onPressed: _openTool,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Пересобрать'),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              if (widget.isDemo) _demoBanner(context),
              _heroCard(context, result),
              const SizedBox(height: 12),
              _summaryCard(context, result),
              const SizedBox(height: 12),
              if (result.priorities.isNotEmpty) ...[
                _prioritiesCard(context, result),
                const SizedBox(height: 12),
              ],
              _firstActionsCard(context, result),
              const SizedBox(height: 12),
              _risksCard(context, result),
              const SizedBox(height: 12),
              _specificSections(context, result),
              if (_showDebugPanel && _outcome.rawEnvelope != null) ...[
                const SizedBox(height: 12),
                _debugPanel(
                  context,
                  'Raw envelope (dev only)',
                  const JsonEncoder.withIndent('  ').convert(_outcome.rawEnvelope),
                ),
              ],
            ],
          ),
          _stickyActions(context),
        ],
      ),
    );
  }

  Widget _errorScaffold(BuildContext context) {
    final err = _outcome.error!;
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _card(
              context,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI не смог собрать нормальный результат', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(err.message),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      OutlinedButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Назад')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _openTool,
                        style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black),
                        child: const Text('Пересобрать'),
                      ),
                    ],
                  ),
                  if (_showDebugPanel && _outcome.rawEnvelope != null) ...[
                    const SizedBox(height: 12),
                    _debugPanel(
                      context,
                      'Сырой ответ (dev only)',
                      const JsonEncoder.withIndent('  ').convert(_outcome.rawEnvelope),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroCard(BuildContext context, NormalizedToolResult result) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(result.hero.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(result.hero.subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context, NormalizedToolResult result) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Кратко по задаче', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...result.summaryLines.map((m) => _line(context, m)),
        ],
      ),
    );
  }

  Widget _prioritiesCard(BuildContext context, NormalizedToolResult result) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('3 главных приоритета', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...result.priorities.asMap().entries.map((entry) {
            final i = entry.key + 1;
            final p = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _badge(i.toString()),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.title, style: Theme.of(context).textTheme.titleSmall)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Почему: ${p.why}', style: Theme.of(context).textTheme.bodySmall),
                  Text('Effort: ${p.effort} • Impact: ${p.impact}', style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 4),
                  ...p.actions.map((s) => _line(context, s)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _firstActionsCard(BuildContext context, NormalizedToolResult result) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Что делать в первую очередь', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...result.firstActions.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a.title} (~${a.etaMinutes} мин)', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    ...a.steps.map((s) => _line(context, s)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _risksCard(BuildContext context, NormalizedToolResult result) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ошибки / риски', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...result.risksOrMistakes.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text('Signal: ${r.signal}', style: Theme.of(context).textTheme.bodySmall),
                    Text('Fix: ${r.fix}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _specificSections(BuildContext context, NormalizedToolResult result) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Специфика инструмента', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...result.specificSections.map((section) {
            final title = section['title']?.toString() ?? 'Раздел';
            final items = (section['items'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  ...items.map((e) => _line(context, e)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stickyActions(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(child: OutlinedButton(onPressed: _copyResult, child: const Text('Скопировать результат'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton(onPressed: _openTool, child: const Text('Пересобрать'))),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _copyFullJson,
                style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: Colors.black),
                child: const Text('Экспорт JSON'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _debugPanel(BuildContext context, String title, String body) {
    return _card(
      context,
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(title),
        children: [SelectableText(body, style: const TextStyle(fontSize: 12))],
      ),
    );
  }

  Widget _demoBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Демо-режим: для полной персонализации нужен тариф Прорыв.')),
          TextButton(onPressed: () => context.push('/subscription'), child: const Text('Открыть')),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: child,
    );
  }

  Widget _line(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: _accent)),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: _accent, fontWeight: FontWeight.w700)),
    );
  }
}
