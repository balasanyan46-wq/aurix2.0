import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/tool_config_base.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudioAiToolWizardScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  final StudioToolConfig config;

  const StudioAiToolWizardScreen({
    super.key,
    required this.release,
    required this.config,
  });

  @override
  ConsumerState<StudioAiToolWizardScreen> createState() => _StudioAiToolWizardScreenState();
}

class _StudioAiToolWizardScreenState extends ConsumerState<StudioAiToolWizardScreen> {
  int _step = 0;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  late StudioToolContext _context;
  final Map<String, dynamic> _answers = {};
  final Map<String, TextEditingController> _summaryControllers = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    for (final c in _summaryControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _answers.addAll(widget.config.defaultAnswers);
      _answers['region'] ??= _inferRegion(widget.release.language);
      _answers['platforms'] ??= _inferPlatformPriorities(widget.release.language);

      final profileModel = await ref.read(profileRepositoryProvider).getMyProfile();
      final profile = profileModel == null
          ? null
          : <String, dynamic>{
              'artist_name': profileModel.artistName,
              'city': profileModel.city,
              'bio': profileModel.bio,
              'plan': profileModel.plan,
            };
      final history = <dynamic>[];

      _context = StudioToolContext(
        releaseId: widget.release.id,
        title: widget.release.title,
        artist: widget.release.artist ?? (profile?['artist_name']?.toString() ?? ''),
        releaseType: widget.release.releaseType,
        releaseDateIso: widget.release.releaseDate?.toIso8601String(),
        genre: widget.release.genre ?? '',
        language: widget.release.language ?? '',
        explicit: widget.release.explicit,
        coverUrl: widget.release.coverUrl,
        coverPath: widget.release.coverPath,
        existingMetadata: {
          'upc': widget.release.upc,
          'label': widget.release.label,
          'status': widget.release.status,
          'copyright_year': widget.release.copyrightYear,
        },
        platformPriorities: _inferPlatformPriorities(widget.release.language),
        pastReleaseData: const <String, dynamic>{},
        studioHistory: history,
        profile: profile ?? const <String, dynamic>{},
      );

      _rebuildSummaryDraft();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<String> _inferPlatformPriorities(String? language) {
    final lang = (language ?? '').toLowerCase();
    if (lang.contains('arm') || lang.contains('hy')) {
      return const ['vk', 'youtube', 'instagram'];
    }
    if (lang.contains('en')) {
      return const ['spotify', 'youtube', 'instagram'];
    }
    return const ['yandex', 'vk', 'youtube'];
  }

  String _inferRegion(String? language) {
    final lang = (language ?? '').toLowerCase();
    if (lang.contains('arm') || lang.contains('hy')) return 'AM';
    if (lang.contains('en')) return 'GLOBAL';
    return 'RU';
  }

  List<ToolQuestion> get _visibleQuestions {
    return widget.config.questions.where((q) => q.isVisible?.call(_answers) ?? true).toList();
  }

  void _rebuildSummaryDraft() {
    final draft = widget.config.buildSummaryDraft(_context, _answers);
    for (final f in widget.config.summaryFields) {
      final existing = _summaryControllers[f.id];
      if (existing == null) {
        _summaryControllers[f.id] = TextEditingController(text: draft[f.id] ?? '');
      } else if (existing.text.trim().isEmpty) {
        existing.text = draft[f.id] ?? '';
      }
    }
  }

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final summaryText = _summaryControllers.entries
          .map((e) => '${e.key}: ${e.value.text.trim()}')
          .join('\n');

      final payload = widget.config.buildPayload(
        context: _context,
        answers: _answers,
        aiSummary: summaryText,
        locale: 'ru',
      );

      final res = await ref.read(toolServiceProvider).generate(
            widget.release.id,
            widget.config.backendToolKey,
            payload,
          );
      if (!mounted) return;
      if (!res.ok) {
        setState(() {
          _generating = false;
          _error = res.error ?? 'Ошибка генерации';
        });
        return;
      }

      setState(() => _generating = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ToolResultScreen(
            release: widget.release,
            toolKey: widget.config.toolId,
            data: res.data,
            isDemo: res.isDemo,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: Text(widget.config.title)), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _step == 0) {
      return Scaffold(appBar: AppBar(title: Text(widget.config.title)), body: Center(child: Text(_error!)));
    }

    const total = 4;
    final progress = (_step + 1) / total;

    return Scaffold(
      appBar: AppBar(title: Text(widget.config.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.config.icon, color: widget.config.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _phaseTitle(_step),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text('${_step + 1}/4', style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: progress,
                    color: widget.config.accent,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: ListView(
                key: ValueKey(_step),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_step == 0) _contextStep(context),
                  if (_step == 1) _questionsStep(context),
                  if (_step == 2) _summaryStep(context),
                  if (_step == 3) _generateStep(context),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.22))),
            ),
            child: Row(
              children: [
                if (_step > 0)
                  OutlinedButton(
                    onPressed: _generating ? null : () => setState(() => _step -= 1),
                    child: const Text('Назад'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _generating ? null : _onNext,
                  style: FilledButton.styleFrom(backgroundColor: widget.config.accent, foregroundColor: Colors.black),
                  child: Text(_step == 3 ? 'Сгенерировать' : 'Далее'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onNext() {
    if (_step == 1) {
      final invalid = _visibleQuestions.where((q) => q.required).firstWhere(
            (q) => !_hasValue(_answers[q.id]),
            orElse: () => const ToolQuestion(
              id: '',
              title: '',
              hint: '',
              example: '',
              required: false,
              type: ToolQuestionType.text,
            ),
          );
      if (invalid.id.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Заполните: ${invalid.title}')));
        return;
      }
      _rebuildSummaryDraft();
    }

    if (_step < 3) {
      setState(() => _step += 1);
    } else {
      _generate();
    }
  }

  bool _hasValue(dynamic v) {
    if (v == null) return false;
    if (v is String) return v.trim().isNotEmpty;
    if (v is List) return v.isNotEmpty;
    return true;
  }

  String _phaseTitle(int step) {
    return switch (step) {
      0 => 'Контекст',
      1 => 'Уточнение',
      2 => 'Вот как AI понял задачу',
      _ => 'Генерация',
    };
  }

  Widget _contextStep(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.release.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('${widget.release.artist ?? "Unknown artist"} • ${widget.release.releaseType}'),
          const SizedBox(height: 10),
          _line(context, 'Жанр: ${widget.release.genre ?? "—"}'),
          _line(context, 'Язык: ${widget.release.language ?? "—"}'),
          _line(context, 'Регион: ${_answers['region'] ?? "RU"}'),
          _line(context, 'Платформы: ${(_answers['platforms'] as List?)?.join(", ") ?? "—"}'),
          _line(context, 'История AI: ${_context.studioHistory.length} сессий'),
        ],
      ),
    );
  }

  Widget _questionsStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ключевые вопросы (${_visibleQuestions.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ..._visibleQuestions.map((q) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _questionCard(context, q),
            )),
      ],
    );
  }

  Widget _summaryStep(BuildContext context) {
    return Column(
      children: widget.config.summaryFields.map((field) {
        final ctrl = _summaryControllers[field.id]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(field.title, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  maxLines: 2,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _generateStep(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Готово к генерации', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(widget.config.subtitle),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (_generating) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _questionCard(BuildContext context, ToolQuestion q) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(q.hint, style: Theme.of(context).textTheme.bodySmall),
          if (q.example.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Пример: ${q.example}', style: Theme.of(context).textTheme.labelSmall),
          ],
          const SizedBox(height: 10),
          _questionInput(q),
        ],
      ),
    );
  }

  Widget _questionInput(ToolQuestion q) {
    switch (q.type) {
      case ToolQuestionType.single:
        final current = _answers[q.id]?.toString();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: q.options.map((o) {
            return ChoiceChip(
              label: Text(o.label),
              selected: current == o.id,
              onSelected: (_) => setState(() => _answers[q.id] = o.id),
            );
          }).toList(),
        );
      case ToolQuestionType.multi:
        final set = <String>{...((_answers[q.id] as List?)?.cast<String>() ?? [])};
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: q.options.map((o) {
            return FilterChip(
              label: Text(o.label),
              selected: set.contains(o.id),
              onSelected: (v) {
                setState(() {
                  v ? set.add(o.id) : set.remove(o.id);
                  _answers[q.id] = set.toList();
                });
              },
            );
          }).toList(),
        );
      case ToolQuestionType.text:
        final ctrl = TextEditingController(text: _answers[q.id]?.toString() ?? '');
        return TextField(
          controller: ctrl,
          maxLines: 3,
          onChanged: (v) => _answers[q.id] = v,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ToolQuestionType.number:
        final ctrl = TextEditingController(text: _answers[q.id]?.toString() ?? '');
        return TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          onChanged: (v) => _answers[q.id] = int.tryParse(v) ?? 0,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ToolQuestionType.boolean:
        final current = (_answers[q.id] as bool?) ?? false;
        return SwitchListTile(
          value: current,
          onChanged: (v) => setState(() => _answers[q.id] = v),
          title: Text(current ? 'Да' : 'Нет'),
          contentPadding: EdgeInsets.zero,
        );
    }
  }

  Widget _card(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _line(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 16, color: widget.config.accent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
