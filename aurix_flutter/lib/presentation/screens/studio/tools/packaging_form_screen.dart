import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

import 'tool_result_screen.dart';

class PackagingFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const PackagingFormScreen({super.key, required this.release});

  @override
  ConsumerState<PackagingFormScreen> createState() => _PackagingFormScreenState();
}

class _PackagingFormScreenState extends ConsumerState<PackagingFormScreen> {
  bool _checkingSaved = true;
  bool _loading = false;

  String _genre = 'pop';
  String _region = 'RU';
  final Set<String> _platforms = {'yandex', 'vk', 'spotify', 'apple'};
  final _vibeCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _refsCtrl = TextEditingController();

  static const _genres = ['pop', 'rap', 'rock', 'r&b', 'electronic', 'indie', 'jazz', 'folk', 'metal', 'other'];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально')];
  static const _platformOpts = [
    ('yandex', 'Яндекс'), ('vk', 'VK'), ('spotify', 'Spotify'), ('apple', 'Apple Music'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.release.genre != null) {
      _genre = widget.release.genre!.toLowerCase();
      if (!_genres.contains(_genre)) _genre = 'other';
    }
    _checkForSaved();
  }

  @override
  void dispose() { _vibeCtrl.dispose(); _aboutCtrl.dispose(); _refsCtrl.dispose(); super.dispose(); }

  Future<void> _checkForSaved() async {
    try {
      final saved = await ref.read(toolServiceProvider).getSaved(widget.release.id, 'release-packaging');
      if (saved != null && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
          ToolResultScreen(release: widget.release, toolKey: 'release-packaging', data: saved.output, isDemo: saved.isDemo)));
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingSaved = false);
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final inputs = {
      'genre': _genre,
      'vibe': _vibeCtrl.text.trim(),
      'about': _aboutCtrl.text.trim(),
      'references': _refsCtrl.text.trim(),
      'region': _region,
      'platforms': _platforms.toList(),
    };
    final result = await ref.read(toolServiceProvider).generate(widget.release.id, 'release-packaging', inputs);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
        ToolResultScreen(release: widget.release, toolKey: 'release-packaging', data: result.data, isDemo: result.isDemo)));
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Ошибка'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSaved) return Scaffold(appBar: AppBar(title: const Text('AI-Упаковка')), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text('Упаковка: ${widget.release.title}')),
      body: _loading
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('AI генерирует упаковку...')]))
        : ListView(padding: const EdgeInsets.all(20), children: [
            _s('Жанр'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _genres.map((g) => ChoiceChip(label: Text(g), selected: _genre == g, onSelected: (v) { if (v) setState(() => _genre = g); })).toList()),
            const SizedBox(height: 20),
            _s('Вайб / настроение'), const SizedBox(height: 8),
            TextField(controller: _vibeCtrl, decoration: const InputDecoration(hintText: 'Например: меланхоличный, ночной, драйвовый', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 20),
            _s('О чём трек'), const SizedBox(height: 8),
            TextField(controller: _aboutCtrl, decoration: const InputDecoration(hintText: 'Кратко опишите о чём ваш трек', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 20),
            _s('Референсы (артисты, треки)'), const SizedBox(height: 8),
            TextField(controller: _refsCtrl, decoration: const InputDecoration(hintText: 'Например: Drake, Скриптонит, The Weeknd', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            _s('Регион'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _regions.map((r) => ChoiceChip(label: Text(r.$2), selected: _region == r.$1, onSelected: (v) { if (v) setState(() => _region = r.$1); })).toList()),
            const SizedBox(height: 20),
            _s('Платформы'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _platformOpts.map((p) => FilterChip(label: Text(p.$2), selected: _platforms.contains(p.$1), onSelected: (v) { setState(() { v ? _platforms.add(p.$1) : _platforms.remove(p.$1); }); })).toList()),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _aboutCtrl.text.trim().isEmpty ? null : _generate,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Сгенерировать упаковку'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ]),
    );
  }

  Widget _s(String t) => Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600));
}
