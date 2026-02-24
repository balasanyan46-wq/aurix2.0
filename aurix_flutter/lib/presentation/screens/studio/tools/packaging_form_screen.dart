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
  String _tone = 'emotional';
  final Set<String> _platforms = {'yandex', 'vk', 'spotify', 'apple'};
  final _vibeCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _refsCtrl = TextEditingController();
  final _keyLyricsCtrl = TextEditingController();

  static const _genres = ['pop', 'rap', 'rock', 'r&b', 'electronic', 'indie', 'jazz', 'folk', 'metal', 'other'];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально'), ('CIS', 'СНГ')];
  static const _platformOpts = [
    ('yandex', 'Яндекс Музыка'), ('vk', 'VK Музыка'), ('spotify', 'Spotify'), ('apple', 'Apple Music'),
  ];
  static const _tones = [
    ('emotional', 'Эмоциональный'),
    ('provocative', 'Провокационный'),
    ('poetic', 'Поэтичный'),
    ('minimalist', 'Минималистичный'),
    ('storytelling', 'Сторителлинг'),
    ('hype', 'Хайповый'),
  ];

  @override
  void initState() {
    super.initState();
    _prefill();
    _checkForSaved();
  }

  void _prefill() {
    final r = widget.release;
    if (r.genre != null) {
      _genre = r.genre!.toLowerCase();
      if (!_genres.contains(_genre)) _genre = 'other';
    }
    if (r.language != null) {
      final lang = r.language!.toLowerCase();
      if (lang.contains('arm') || lang.contains('hy')) _region = 'AM';
      else if (lang.contains('en')) _region = 'GLOBAL';
    }
  }

  @override
  void dispose() { _vibeCtrl.dispose(); _aboutCtrl.dispose(); _refsCtrl.dispose(); _keyLyricsCtrl.dispose(); super.dispose(); }

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
      'keyLyrics': _keyLyricsCtrl.text.trim(),
      'tone': _tone,
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
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(), const SizedBox(height: 16),
            Text('AI создаёт упаковку для «${widget.release.title}»...'),
          ]))
        : ListView(padding: const EdgeInsets.all(20), children: [
            _releaseInfoBanner(),
            const SizedBox(height: 20),
            _s('Жанр'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _genres.map((g) => ChoiceChip(label: Text(g), selected: _genre == g, onSelected: (v) { if (v) setState(() => _genre = g); })).toList()),
            const SizedBox(height: 20),
            _s('О чём трек'), const SizedBox(height: 8),
            TextField(controller: _aboutCtrl, decoration: const InputDecoration(hintText: 'Опишите тему, историю, основное сообщение трека', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 20),
            _s('Ключевые строки из текста (опционально)'), const SizedBox(height: 8),
            TextField(controller: _keyLyricsCtrl, decoration: const InputDecoration(hintText: 'Вставьте 1-3 цепляющие строки из текста, которые отражают суть', border: OutlineInputBorder()), maxLines: 3),
            const SizedBox(height: 20),
            _s('Вайб / настроение'), const SizedBox(height: 8),
            TextField(controller: _vibeCtrl, decoration: const InputDecoration(hintText: 'Например: ночной, меланхоличный, драйвовый, танцевальный', border: OutlineInputBorder()), maxLines: 2),
            const SizedBox(height: 20),
            _s('Тон упаковки'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _tones.map((t) => ChoiceChip(label: Text(t.$2), selected: _tone == t.$1, onSelected: (v) { if (v) setState(() => _tone = t.$1); })).toList()),
            const SizedBox(height: 20),
            _s('Референсы (артисты, треки)'), const SizedBox(height: 8),
            TextField(controller: _refsCtrl, decoration: const InputDecoration(hintText: 'На кого похож стиль? Drake, Скриптонит, Billie Eilish...', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            _s('Регион'), const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: _regions.map((r) => ChoiceChip(label: Text(r.$2), selected: _region == r.$1, onSelected: (v) { if (v) setState(() => _region = r.$1); })).toList()),
            const SizedBox(height: 20),
            _s('Платформы для описаний'), const SizedBox(height: 8),
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
