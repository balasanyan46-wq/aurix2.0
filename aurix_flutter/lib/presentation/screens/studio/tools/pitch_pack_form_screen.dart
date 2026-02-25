import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tools_registry.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/widgets/tool_ai_panel.dart';

class PitchPackFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const PitchPackFormScreen({super.key, required this.release});

  @override
  ConsumerState<PitchPackFormScreen> createState() => _PitchPackFormScreenState();
}

class _PitchPackFormScreenState extends ConsumerState<PitchPackFormScreen> {
  String _genre = 'pop';
  String _region = 'RU';
  String _pitchTarget = 'playlists';
  final _aboutCtrl = TextEditingController();
  final _vibeCtrl = TextEditingController();
  final _refsCtrl = TextEditingController();
  final _achievementsCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();

  static const _genres = ['pop', 'rap', 'rock', 'r&b', 'electronic', 'indie', 'jazz', 'folk', 'metal', 'other'];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально'), ('CIS', 'СНГ')];
  static const _pitchTargets = [
    ('playlists', 'Плейлист-кураторы'),
    ('press', 'Журналисты/блогеры'),
    ('radio', 'Радиостанции'),
    ('labels', 'Лейблы'),
  ];

  @override
  void initState() {
    super.initState();
    _prefill();
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
  void dispose() { _aboutCtrl.dispose(); _vibeCtrl.dispose(); _refsCtrl.dispose(); _achievementsCtrl.dispose(); _storyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Питч: ${widget.release.title}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _releaseInfoBanner(),
          const SizedBox(height: 20),
          _s('Жанр'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _genres
                .map((g) => ChoiceChip(
                      label: Text(g),
                      selected: _genre == g,
                      onSelected: (v) {
                        if (v) setState(() => _genre = g);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          _s('Кому питчим'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _pitchTargets
                .map((t) => ChoiceChip(
                      label: Text(t.$2),
                      selected: _pitchTarget == t.$1,
                      onSelected: (v) {
                        if (v) setState(() => _pitchTarget = t.$1);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          _s('О чём трек'),
          const SizedBox(height: 8),
          TextField(
            controller: _aboutCtrl,
            decoration: const InputDecoration(
              hintText: 'Тема трека, основное сообщение, история',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _s('История создания (опционально)'),
          const SizedBox(height: 8),
          TextField(
            controller: _storyCtrl,
            decoration: const InputDecoration(
              hintText: 'Как и почему был создан этот трек? Что вдохновило?',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _s('Вайб / настроение'),
          const SizedBox(height: 8),
          TextField(
            controller: _vibeCtrl,
            decoration: const InputDecoration(
              hintText: 'Например: энергичный, меланхоличный, ночной',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _s('Референсы'),
          const SizedBox(height: 8),
          TextField(
            controller: _refsCtrl,
            decoration: const InputDecoration(
              hintText: 'Похожие артисты, треки или альбомы',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _s('Достижения артиста'),
          const SizedBox(height: 8),
          TextField(
            controller: _achievementsCtrl,
            decoration: const InputDecoration(
              hintText: 'Например: 100K стримов, 2 EP, выступление на Bosco Fresh Fest',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _s('Регион'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _regions
                .map((r) => ChoiceChip(
                      label: Text(r.$2),
                      selected: _region == r.$1,
                      onSelected: (v) {
                        if (v) setState(() => _region = r.$1);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          ToolAiPanel(
            toolId: toolIdPlaylistPitch,
            buildFormData: () => {
              'release': {
                'id': widget.release.id,
                'title': widget.release.title,
                'artist': widget.release.artist,
                'genre': widget.release.genre,
                'releaseType': widget.release.releaseType,
                'releaseDate': widget.release.releaseDate?.toIso8601String(),
                'language': widget.release.language,
              },
              'inputs': {
                'genre': _genre,
                'pitchTarget': _pitchTarget,
                'about': _aboutCtrl.text.trim(),
                'creationStory': _storyCtrl.text.trim(),
                'vibe': _vibeCtrl.text.trim(),
                'references': _refsCtrl.text.trim(),
                'achievements': _achievementsCtrl.text.trim(),
                'region': _region,
              },
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
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
