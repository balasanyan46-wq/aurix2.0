import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

import 'tool_result_screen.dart';

class ContentPlanFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const ContentPlanFormScreen({super.key, required this.release});

  @override
  ConsumerState<ContentPlanFormScreen> createState() => _ContentPlanFormScreenState();
}

class _ContentPlanFormScreenState extends ConsumerState<ContentPlanFormScreen> {
  bool _checkingSaved = true;
  bool _loading = false;

  String _goal = 'streams';
  String _region = 'RU';
  final Set<String> _platforms = {'instagram', 'tiktok', 'youtube'};
  final _vibeCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  String _visualStyle = 'aesthetic';

  static const _goals = [('streams', 'Стримы'), ('playlisting', 'Плейлисты'), ('followers', 'Подписчики'), ('brand', 'Бренд')];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально'), ('CIS', 'СНГ')];
  static const _platformOpts = [
    ('instagram', 'Instagram Reels'), ('tiktok', 'TikTok'), ('youtube', 'YouTube Shorts'), ('vk', 'VK Клипы'),
  ];
  static const _visualStyles = [
    ('aesthetic', 'Эстетичный'),
    ('raw', 'Сырой/Аутентичный'),
    ('professional', 'Профессиональный'),
    ('funny', 'Юморной'),
    ('dark', 'Тёмный/Мрачный'),
    ('bright', 'Яркий/Поп'),
  ];

  @override
  void initState() {
    super.initState();
    _prefill();
    _checkForSaved();
  }

  void _prefill() {
    final r = widget.release;
    if (r.language != null) {
      final lang = r.language!.toLowerCase();
      if (lang.contains('arm') || lang.contains('hy')) _region = 'AM';
      else if (lang.contains('en')) _region = 'GLOBAL';
    }
  }

  @override
  void dispose() { _vibeCtrl.dispose(); _audienceCtrl.dispose(); _aboutCtrl.dispose(); super.dispose(); }

  Future<void> _checkForSaved() async {
    try {
      final saved = await ref.read(toolServiceProvider).getSaved(widget.release.id, 'content-plan-14');
      if (saved != null && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
          ToolResultScreen(release: widget.release, toolKey: 'content-plan-14', data: saved.output, isDemo: saved.isDemo)));
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingSaved = false);
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final inputs = {
      'goal': _goal,
      'region': _region,
      'platforms': _platforms.toList(),
      'vibe': _vibeCtrl.text.trim(),
      'audience': _audienceCtrl.text.trim(),
      'about': _aboutCtrl.text.trim(),
      'visualStyle': _visualStyle,
    };
    final result = await ref.read(toolServiceProvider).generate(widget.release.id, 'content-plan-14', inputs);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
        ToolResultScreen(release: widget.release, toolKey: 'content-plan-14', data: result.data, isDemo: result.isDemo)));
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Ошибка'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSaved) return Scaffold(appBar: AppBar(title: const Text('Контент-план')), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text('Контент: ${widget.release.title}')),
      body: _loading
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(), const SizedBox(height: 16),
            Text('AI создаёт контент-план для ${widget.release.artist ?? "вашего релиза"}...'),
          ]))
        : ListView(padding: const EdgeInsets.all(20), children: [
            _releaseInfoBanner(),
            const SizedBox(height: 20),
            _s('Цель'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _goals.map((g) => ChoiceChip(label: Text(g.$2), selected: _goal == g.$1, onSelected: (v) { if (v) setState(() => _goal = g.$1); })).toList()),
            const SizedBox(height: 20),
            _s('Регион'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _regions.map((r) => ChoiceChip(label: Text(r.$2), selected: _region == r.$1, onSelected: (v) { if (v) setState(() => _region = r.$1); })).toList()),
            const SizedBox(height: 20),
            _s('Платформы'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _platformOpts.map((p) => FilterChip(label: Text(p.$2), selected: _platforms.contains(p.$1), onSelected: (v) { setState(() { v ? _platforms.add(p.$1) : _platforms.remove(p.$1); }); })).toList()),
            const SizedBox(height: 20),
            _s('Визуальный стиль'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _visualStyles.map((s) => ChoiceChip(label: Text(s.$2), selected: _visualStyle == s.$1, onSelected: (v) { if (v) setState(() => _visualStyle = s.$1); })).toList()),
            const SizedBox(height: 20),
            _s('О чём трек (для привязки контента)'), const SizedBox(height: 8),
            TextField(controller: _aboutCtrl, decoration: const InputDecoration(hintText: 'Кратко: о чём текст, какая история', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 20),
            _s('Вайб / стиль контента'), const SizedBox(height: 8),
            TextField(controller: _vibeCtrl, decoration: const InputDecoration(hintText: 'Например: дерзкий, эстетичный, ироничный, ламповый', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 20),
            _s('Аудитория (опционально)'), const SizedBox(height: 8),
            TextField(controller: _audienceCtrl, decoration: const InputDecoration(hintText: 'Например: молодёжь 18-25, фанаты хип-хопа из СНГ', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _platforms.isEmpty ? null : _generate,
              icon: const Icon(Icons.video_library_rounded),
              label: const Text('Сгенерировать план'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ]),
    );
  }

  Widget _releaseInfoBanner() {
    final r = widget.release;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        if (r.coverUrl != null)
          ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(r.coverUrl!, width: 48, height: 48, fit: BoxFit.cover))
        else
          Container(width: 48, height: 48, decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.album_rounded, color: cs.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          Text([r.artist ?? '', r.genre ?? '', r.releaseType].where((s) => s.isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
        ])),
      ]),
    );
  }

  Widget _s(String t) => Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600));
}
