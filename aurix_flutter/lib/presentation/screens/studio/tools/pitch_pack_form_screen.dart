import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

import 'tool_result_screen.dart';

class PitchPackFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const PitchPackFormScreen({super.key, required this.release});

  @override
  ConsumerState<PitchPackFormScreen> createState() => _PitchPackFormScreenState();
}

class _PitchPackFormScreenState extends ConsumerState<PitchPackFormScreen> {
  bool _checkingSaved = true;
  bool _loading = false;

  String _genre = 'pop';
  String _region = 'RU';
  final _aboutCtrl = TextEditingController();
  final _vibeCtrl = TextEditingController();
  final _refsCtrl = TextEditingController();
  final _achievementsCtrl = TextEditingController();

  static const _genres = ['pop', 'rap', 'rock', 'r&b', 'electronic', 'indie', 'jazz', 'folk', 'metal', 'other'];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально')];

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
  void dispose() { _aboutCtrl.dispose(); _vibeCtrl.dispose(); _refsCtrl.dispose(); _achievementsCtrl.dispose(); super.dispose(); }

  Future<void> _checkForSaved() async {
    try {
      final saved = await ref.read(toolServiceProvider).getSaved(widget.release.id, 'playlist-pitch-pack');
      if (saved != null && mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
          ToolResultScreen(release: widget.release, toolKey: 'playlist-pitch-pack', data: saved.output, isDemo: saved.isDemo)));
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingSaved = false);
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    final inputs = {
      'genre': _genre,
      'about': _aboutCtrl.text.trim(),
      'vibe': _vibeCtrl.text.trim(),
      'references': _refsCtrl.text.trim(),
      'achievements': _achievementsCtrl.text.trim(),
      'region': _region,
    };
    final result = await ref.read(toolServiceProvider).generate(widget.release.id, 'playlist-pitch-pack', inputs);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
        ToolResultScreen(release: widget.release, toolKey: 'playlist-pitch-pack', data: result.data, isDemo: result.isDemo)));
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error ?? 'Ошибка'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSaved) return Scaffold(appBar: AppBar(title: const Text('Питч-пакет')), body: const Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: Text('Питч: ${widget.release.title}')),
      body: _loading
        ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('AI готовит питч-пакет...')]))
        : ListView(padding: const EdgeInsets.all(20), children: [
            _s('Жанр'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _genres.map((g) => ChoiceChip(label: Text(g), selected: _genre == g, onSelected: (v) { if (v) setState(() => _genre = g); })).toList()),
            const SizedBox(height: 20),
            _s('О чём трек'), const SizedBox(height: 8),
            TextField(controller: _aboutCtrl, decoration: const InputDecoration(hintText: 'Кратко о чём трек, история создания', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 20),
            _s('Вайб / настроение'), const SizedBox(height: 8),
            TextField(controller: _vibeCtrl, decoration: const InputDecoration(hintText: 'Например: энергичный, меланхоличный', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 20),
            _s('Референсы'), const SizedBox(height: 8),
            TextField(controller: _refsCtrl, decoration: const InputDecoration(hintText: 'Похожие артисты или треки', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            _s('Достижения артиста (опционально)'), const SizedBox(height: 8),
            TextField(controller: _achievementsCtrl, decoration: const InputDecoration(hintText: 'Например: 100k стримов, выступление на фестивале', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 20),
            _s('Регион'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _regions.map((r) => ChoiceChip(label: Text(r.$2), selected: _region == r.$1, onSelected: (v) { if (v) setState(() => _region = r.$1); })).toList()),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _aboutCtrl.text.trim().isEmpty ? null : _generate,
              icon: const Icon(Icons.mail_rounded),
              label: const Text('Сгенерировать питч-пакет'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 24),
          ]),
    );
  }

  Widget _s(String t) => Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600));
}
