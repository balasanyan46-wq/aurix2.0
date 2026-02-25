import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/tools/tools_registry.dart';
import 'package:aurix_flutter/widgets/tool_ai_panel.dart';

class ContentPlanFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const ContentPlanFormScreen({super.key, required this.release});

  @override
  ConsumerState<ContentPlanFormScreen> createState() => _ContentPlanFormScreenState();
}

class _ContentPlanFormScreenState extends ConsumerState<ContentPlanFormScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Контент: ${widget.release.title}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _releaseInfoBanner(),
          const SizedBox(height: 20),
          _s('Цель'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _goals
                .map((g) => ChoiceChip(
                      label: Text(g.$2),
                      selected: _goal == g.$1,
                      onSelected: (v) {
                        if (v) setState(() => _goal = g.$1);
                      },
                    ))
                .toList(),
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
          _s('Платформы'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _platformOpts
                .map((p) => FilterChip(
                      label: Text(p.$2),
                      selected: _platforms.contains(p.$1),
                      onSelected: (v) {
                        setState(() {
                          v ? _platforms.add(p.$1) : _platforms.remove(p.$1);
                        });
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          _s('Визуальный стиль'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _visualStyles
                .map((s) => ChoiceChip(
                      label: Text(s.$2),
                      selected: _visualStyle == s.$1,
                      onSelected: (v) {
                        if (v) setState(() => _visualStyle = s.$1);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          _s('О чём трек (для привязки контента)'),
          const SizedBox(height: 8),
          TextField(
            controller: _aboutCtrl,
            decoration: const InputDecoration(
              hintText: 'Кратко: о чём текст, какая история',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _s('Вайб / стиль контента'),
          const SizedBox(height: 8),
          TextField(
            controller: _vibeCtrl,
            decoration: const InputDecoration(
              hintText: 'Например: дерзкий, эстетичный, ироничный, ламповый',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          _s('Аудитория (опционально)'),
          const SizedBox(height: 8),
          TextField(
            controller: _audienceCtrl,
            decoration: const InputDecoration(
              hintText: 'Например: молодёжь 18-25, фанаты хип-хопа из СНГ',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 20),
          ToolAiPanel(
            tool: toolsRegistry[ToolId.reelsShortsPlan]!,
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
                'goal': _goal,
                'region': _region,
                'platforms': _platforms.toList(),
                'visualStyle': _visualStyle,
                'about': _aboutCtrl.text.trim(),
                'vibe': _vibeCtrl.text.trim(),
                'audience': _audienceCtrl.text.trim(),
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
