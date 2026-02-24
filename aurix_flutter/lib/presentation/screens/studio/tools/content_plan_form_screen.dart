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

  static const _goals = [('streams', 'Стримы'), ('playlisting', 'Плейлисты'), ('followers', 'Подписчики'), ('brand', 'Бренд')];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально')];
  static const _platformOpts = [
    ('instagram', 'Instagram'), ('tiktok', 'TikTok'), ('youtube', 'YouTube Shorts'), ('vk', 'VK Клипы'),
  ];

  @override
  void initState() { super.initState(); _checkForSaved(); }

  @override
  void dispose() { _vibeCtrl.dispose(); _audienceCtrl.dispose(); super.dispose(); }

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
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('AI создаёт контент-план...')]))
        : ListView(padding: const EdgeInsets.all(20), children: [
            _s('Цель'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _goals.map((g) => ChoiceChip(label: Text(g.$2), selected: _goal == g.$1, onSelected: (v) { if (v) setState(() => _goal = g.$1); })).toList()),
            const SizedBox(height: 20),
            _s('Регион'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _regions.map((r) => ChoiceChip(label: Text(r.$2), selected: _region == r.$1, onSelected: (v) { if (v) setState(() => _region = r.$1); })).toList()),
            const SizedBox(height: 20),
            _s('Платформы'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _platformOpts.map((p) => FilterChip(label: Text(p.$2), selected: _platforms.contains(p.$1), onSelected: (v) { setState(() { v ? _platforms.add(p.$1) : _platforms.remove(p.$1); }); })).toList()),
            const SizedBox(height: 20),
            _s('Вайб / стиль контента'), const SizedBox(height: 8),
            TextField(controller: _vibeCtrl, decoration: const InputDecoration(hintText: 'Например: дерзкий, эстетичный, ироничный', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 20),
            _s('Аудитория (опционально)'), const SizedBox(height: 8),
            TextField(controller: _audienceCtrl, decoration: const InputDecoration(hintText: 'Например: молодёжь 18-25, фанаты хип-хопа', border: OutlineInputBorder()), maxLines: 2),
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

  Widget _s(String t) => Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600));
}
