import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

import 'tool_result_screen.dart';

class GrowthPlanFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const GrowthPlanFormScreen({super.key, required this.release});

  @override
  ConsumerState<GrowthPlanFormScreen> createState() => _GrowthPlanFormScreenState();
}

class _GrowthPlanFormScreenState extends ConsumerState<GrowthPlanFormScreen> {
  bool _checkingSaved = true;
  bool _loading = false;

  String _genre = 'pop';
  String _goal = 'streams';
  String _region = 'RU';
  final Set<String> _platforms = {'yandex', 'vk', 'spotify'};
  final _audienceController = TextEditingController();
  final _strengthsCtrl = TextEditingController();
  bool _coverReady = true;
  bool _musicVideo = false;
  bool _hasPreSaves = false;

  static const _genres = ['pop', 'rap', 'rock', 'r&b', 'electronic', 'indie', 'jazz', 'classical', 'folk', 'metal', 'other'];
  static const _goals = [
    ('streams', 'Стримы'),
    ('playlisting', 'Плейлисты'),
    ('followers', 'Подписчики'),
    ('brand', 'Бренд'),
    ('press', 'Пресса'),
  ];
  static const _regions = [('RU', 'Россия'), ('AM', 'Армения'), ('GLOBAL', 'Глобально'), ('CIS', 'СНГ')];
  static const _platformOptions = [
    ('yandex', 'Яндекс Музыка'),
    ('vk', 'VK Музыка'),
    ('spotify', 'Spotify'),
    ('apple', 'Apple Music'),
    ('youtube', 'YouTube Music'),
    ('tiktok', 'TikTok'),
    ('instagram', 'Instagram'),
  ];

  @override
  void initState() {
    super.initState();
    _prefillFromRelease();
    _checkForSaved();
  }

  void _prefillFromRelease() {
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
  void dispose() {
    _audienceController.dispose();
    _strengthsCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkForSaved() async {
    try {
      final saved = await ref.read(toolServiceProvider).getSaved(widget.release.id, 'growth-plan');
      if (saved != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ToolResultScreen(
              release: widget.release,
              toolKey: 'growth-plan',
              data: saved.output,
              isDemo: saved.isDemo,
            ),
          ),
        );
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingSaved = false);
  }

  Future<void> _generate() async {
    setState(() => _loading = true);

    final inputs = {
      'genre': _genre,
      'releaseDate': widget.release.releaseDate?.toIso8601String().split('T').first ?? DateTime.now().toIso8601String().split('T').first,
      'goal': _goal,
      'region': _region,
      'platforms': _platforms.toList(),
      'audience': _audienceController.text.trim().isEmpty ? null : _audienceController.text.trim(),
      'strengths': _strengthsCtrl.text.trim().isEmpty ? null : _strengthsCtrl.text.trim(),
      'assets': {
        'coverReady': _coverReady,
        'musicVideo': _musicVideo,
        'preSaves': _hasPreSaves,
      },
    };

    final result = await ref.read(toolServiceProvider).generate(widget.release.id, 'growth-plan', inputs);
    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ToolResultScreen(
            release: widget.release,
            toolKey: 'growth-plan',
            data: result.data,
            isDemo: result.isDemo,
          ),
        ),
      );
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Ошибка генерации'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSaved) {
      return Scaffold(
        appBar: AppBar(title: const Text('Карта роста')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Карта роста: ${widget.release.title}')),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Генерируем персональный план для ${widget.release.artist ?? "вашего релиза"}...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _releaseInfoBanner(),
                const SizedBox(height: 20),
                _sectionTitle('Жанр'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _genres.map((g) => ChoiceChip(
                    label: Text(g),
                    selected: _genre == g,
                    onSelected: (v) { if (v) setState(() => _genre = g); },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Главная цель'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _goals.map((g) => ChoiceChip(
                    label: Text(g.$2),
                    selected: _goal == g.$1,
                    onSelected: (v) { if (v) setState(() => _goal = g.$1); },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Регион'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _regions.map((r) => ChoiceChip(
                    label: Text(r.$2),
                    selected: _region == r.$1,
                    onSelected: (v) { if (v) setState(() => _region = r.$1); },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Платформы'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _platformOptions.map((p) => FilterChip(
                    label: Text(p.$2),
                    selected: _platforms.contains(p.$1),
                    onSelected: (v) {
                      setState(() { v ? _platforms.add(p.$1) : _platforms.remove(p.$1); });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _sectionTitle('Целевая аудитория'),
                const SizedBox(height: 8),
                TextField(
                  controller: _audienceController,
                  decoration: const InputDecoration(
                    hintText: 'Например: парни 18-25, слушают рэп, живут в Москве',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _sectionTitle('Ваши сильные стороны (опционально)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _strengthsCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Например: 5000 подписчиков в IG, активная аудитория в VK, знакомые блогеры',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _sectionTitle('Готовность'),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Обложка готова'),
                  value: _coverReady,
                  onChanged: (v) => setState(() => _coverReady = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Есть музыкальный клип'),
                  value: _musicVideo,
                  onChanged: (v) => setState(() => _musicVideo = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Настроены пре-сейвы'),
                  value: _hasPreSaves,
                  onChanged: (v) => setState(() => _hasPreSaves = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _platforms.isEmpty ? null : _generate,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Сгенерировать план'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
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
      child: Row(
        children: [
          if (r.coverUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(r.coverUrl!, width: 48, height: 48, fit: BoxFit.cover),
            )
          else
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.album_rounded, color: cs.primary),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                [r.artist ?? '', r.genre ?? '', r.releaseType].where((s) => s.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      );
}
