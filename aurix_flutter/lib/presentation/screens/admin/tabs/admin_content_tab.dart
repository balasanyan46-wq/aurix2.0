import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/services/ai_chat_service.dart';

final _templatesProvider = FutureProvider<List<LegalTemplateModel>>((ref) async {
  return ref.read(legalRepositoryProvider).fetchTemplates();
});

final _navigatorAdminMaterialsProvider =
    FutureProvider<List<NavigatorMaterial>>((ref) async {
  final res = await ApiClient.get('/artist-navigator-materials', query: {
    'limit': 120,
  });
  final rows = asList(res.data);
  return rows
      .whereType<Map>()
      .map((e) => NavigatorMaterial.fromJson(e.cast<String, dynamic>()))
      .toList();
});

class AdminContentTab extends ConsumerWidget {
  const AdminContentTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(_templatesProvider);
    final profilesAsync = ref.watch(allProfilesProvider);
    final releasesAsync = ref.watch(allReleasesAdminProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('КОНТЕНТ И ПЛАТФОРМА', style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Управление контентом, шаблонами и обзор платформы.', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),

          const SizedBox(height: 24),

          // Platform quick stats
          _SectionHeader('ПЛАТФОРМА'),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final cards = [
              _InfoCard(
                icon: Icons.gavel_rounded,
                label: 'Юр. шаблонов',
                value: templatesAsync.when(data: (t) => '${t.length}', loading: () => '...', error: (_, __) => '—'),
                color: AurixTokens.orange,
              ),
              _InfoCard(
                icon: Icons.people_rounded,
                label: 'Пользователей',
                value: profilesAsync.when(data: (p) => '${p.length}', loading: () => '...', error: (_, __) => '—'),
                color: AurixTokens.positive,
              ),
              _InfoCard(
                icon: Icons.album_rounded,
                label: 'Релизов',
                value: releasesAsync.when(data: (r) => '${r.length}', loading: () => '...', error: (_, __) => '—'),
                color: Colors.blue,
              ),
              _InfoCard(
                icon: Icons.check_circle_rounded,
                label: 'Одобрено',
                value: releasesAsync.when(
                  data: (r) => '${r.where((rel) => rel.status == 'approved' || rel.status == 'live').length}',
                  loading: () => '...',
                  error: (_, __) => '—',
                ),
                color: AurixTokens.positive,
              ),
            ];
            if (isWide) {
              return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: c))).toList());
            }
            return Wrap(spacing: 10, runSpacing: 10, children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 10) / 2, child: c)).toList());
          }),

          const SizedBox(height: 28),

          // Release types breakdown
          _SectionHeader('ТИПЫ РЕЛИЗОВ'),
          const SizedBox(height: 12),
          releasesAsync.when(
            data: (releases) {
              final types = <String, int>{};
              for (final r in releases) {
                types[r.releaseType] = (types[r.releaseType] ?? 0) + 1;
              }
              if (types.isEmpty) return _emptyCard('Нет данных');
              final sorted = types.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final max = sorted.first.value.toDouble();
              return _card(
                child: Column(
                  children: sorted.map((e) {
                    final pct = releases.isEmpty ? 0.0 : e.value / releases.length;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(_releaseTypeLabel(e.key), style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LayoutBuilder(builder: (ctx, c) {
                              return Container(
                                height: 20,
                                width: c.maxWidth * (max > 0 ? e.value / max : 0),
                                decoration: BoxDecoration(
                                  color: AurixTokens.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: Text('${e.value} (${(pct * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFeatures: AurixTokens.tabularFigures),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => _loading(),
            error: (e, _) => _errorWidget(e.toString()),
          ),

          const SizedBox(height: 28),

          // Genres breakdown
          _SectionHeader('ЖАНРЫ'),
          const SizedBox(height: 12),
          releasesAsync.when(
            data: (releases) {
              final genres = <String, int>{};
              for (final r in releases) {
                final g = (r.genre != null && r.genre!.isNotEmpty) ? r.genre! : 'Не указан';
                genres[g] = (genres[g] ?? 0) + 1;
              }
              if (genres.isEmpty) return _emptyCard('Нет данных');
              final sorted = genres.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final top = sorted.take(10).toList();
              return _card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: top.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AurixTokens.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.2)),
                      ),
                      child: Text('${e.key} (${e.value})', style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500)),
                    )).toList(),
                  ),
                ),
              );
            },
            loading: () => _loading(),
            error: (e, _) => _errorWidget(e.toString()),
          ),

          const SizedBox(height: 28),

          // Legal templates
          _SectionHeader('ЮРИДИЧЕСКИЕ ШАБЛОНЫ'),
          const SizedBox(height: 12),
          templatesAsync.when(
            data: (templates) {
              if (templates.isEmpty) return _emptyCard('Нет шаблонов');
              return Column(
                children: templates.map((t) => _TemplateCard(template: t)).toList(),
              );
            },
            loading: () => _loading(),
            error: (e, _) => _errorWidget(e.toString()),
          ),
          const SizedBox(height: 28),
          _SectionHeader('СТАТЬИ НАВИГАТОРА'),
          const SizedBox(height: 12),
          const _NavigatorArticleAdminSection(),
        ],
      ),
    );
  }

  static String _releaseTypeLabel(String type) => switch (type) {
        'single' => 'Сингл',
        'ep' => 'EP',
        'album' => 'Альбом',
        'compilation' => 'Сборник',
        _ => type,
      };

  static Widget _loading() => const Center(
    child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
  );

  static Widget _errorWidget(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Text('Ошибка: $msg', style: const TextStyle(color: AurixTokens.danger, fontSize: 13)),
  );

  static Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: AurixTokens.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.border)),
    child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
  );

  static Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AurixTokens.bg1.withValues(alpha: 0.95),
          AurixTokens.bg2.withValues(alpha: 0.86),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AurixTokens.stroke(0.24)),
      boxShadow: [...AurixTokens.subtleShadow],
    ),
    child: child,
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AurixTokens.micro,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.5,
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
              Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final LegalTemplateModel template;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.2)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AurixTokens.muted,
        collapsedIconColor: AurixTokens.muted,
        title: Text(template.title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            _categoryBadge(template.category),
            const SizedBox(width: 8),
            if (template.version != null) Text('v${template.version}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          ],
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(template.description, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
          ),
          if (template.formKeys.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(alignment: Alignment.centerLeft, child: Text('ПОЛЯ ФОРМЫ', style: TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: template.formKeys.map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(4)),
                child: Text(k, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 11, fontFamily: 'monospace')),
              )).toList(),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AurixTokens.bg0, borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(
                child: SelectableText(template.body, style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontFamily: 'monospace', height: 1.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBadge(LegalCategory cat) {
    final color = switch (cat) {
      LegalCategory.distribution => Colors.blue,
      LegalCategory.team => AurixTokens.positive,
      LegalCategory.production => AurixTokens.orange,
      LegalCategory.nda => AurixTokens.warning,
      LegalCategory.all => AurixTokens.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
      child: Text(cat.label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _NavigatorArticleAdminSection extends ConsumerStatefulWidget {
  const _NavigatorArticleAdminSection();

  @override
  ConsumerState<_NavigatorArticleAdminSection> createState() =>
      _NavigatorArticleAdminSectionState();
}

class _NavigatorArticleAdminSectionState
    extends ConsumerState<_NavigatorArticleAdminSection> {
  static const _formatKinds = [
    'hero',
    'intro',
    'how_it_works',
    'misconceptions',
    'mistakes',
    'practical_steps',
    'real_world_example',
    'takeaway',
    'action_after_reading',
  ];

  final _titleCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _excerptCtrl = TextEditingController();
  final _draftCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _platformsCtrl = TextEditingController();
  final _stagesCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _blockersCtrl = TextEditingController();
  final _readingCtrl = TextEditingController(text: '10');
  final _priorityCtrl = TextEditingController(text: '0.75');

  String _category = 'Старт и позиционирование';
  String _difficulty = 'средний';
  bool _isPublished = true;
  bool _isFeatured = false;
  bool _normalizing = false;
  bool _saving = false;
  String? _error;
  String? _ok;

  List<Map<String, dynamic>> _bodyBlocks = const [];
  List<Map<String, dynamic>> _actionLinks = const [];
  List<Map<String, dynamic>> _sourcePack = const [];
  List<String> _relatedContentIds = const [];
  List<String> _relatedTools = const [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _slugCtrl.dispose();
    _subtitleCtrl.dispose();
    _excerptCtrl.dispose();
    _draftCtrl.dispose();
    _tagsCtrl.dispose();
    _platformsCtrl.dispose();
    _stagesCtrl.dispose();
    _goalsCtrl.dispose();
    _blockersCtrl.dispose();
    _readingCtrl.dispose();
    _priorityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final articlesAsync = ref.watch(_navigatorAdminMaterialsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Добавить статью с AI-нормализацией',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Админ вставляет черновик, AI автоматически приводит материал к формату Навигатора (длинный разбор). После проверки — сохранить.',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Заголовок статьи',
                        ),
                        onChanged: (v) {
                          if (_slugCtrl.text.trim().isEmpty) {
                            _slugCtrl.text = _slugify(v);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _slugCtrl,
                        decoration: const InputDecoration(labelText: 'slug'),
                      ),
                    ),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Категория'),
                        selectedItemBuilder: (context) => const [
                          'Старт и позиционирование',
                          'Релиз как система',
                          'Контент и короткие форматы',
                          'Аналитика',
                          'Монетизация и прямой доход от аудитории',
                          'Система артиста / дисциплина',
                          'Кейсы и разборы',
                          'Яндекс Музыка',
                          'VK Музыка',
                          'Право и безопасность',
                          'Договоры и права',
                          'Бренд артиста',
                        ]
                            .map(
                              (e) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  e,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        items: const [
                          'Старт и позиционирование',
                          'Релиз как система',
                          'Контент и короткие форматы',
                          'Аналитика',
                          'Монетизация и прямой доход от аудитории',
                          'Система артиста / дисциплина',
                          'Кейсы и разборы',
                          'Яндекс Музыка',
                          'VK Музыка',
                          'Право и безопасность',
                          'Договоры и права',
                          'Бренд артиста',
                        ]
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<String>(
                        value: _difficulty,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Сложность'),
                        items: const ['базовый', 'средний', 'продвинутый']
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _difficulty = v ?? _difficulty),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _readingCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Минут на чтение'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: _priorityCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Приоритет'),
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _subtitleCtrl,
                        decoration: const InputDecoration(labelText: 'Подзаголовок'),
                      ),
                    ),
                    SizedBox(
                      width: 760,
                      child: TextField(
                        controller: _excerptCtrl,
                        minLines: 2,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Короткое описание'),
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Теги (через запятую)',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _platformsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Платформы (через запятую)',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _stagesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Этапы (через запятую)',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 380,
                      child: TextField(
                        controller: _goalsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Цели (через запятую)',
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 760,
                      child: TextField(
                        controller: _blockersCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Блокеры (через запятую)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _draftCtrl,
                  minLines: 10,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: 'Черновик статьи (свободный текст)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Switch(
                      value: _isPublished,
                      onChanged: (v) => setState(() => _isPublished = v),
                    ),
                    const Text('Опубликовать'),
                    const SizedBox(width: 16),
                    Switch(
                      value: _isFeatured,
                      onChanged: (v) => setState(() => _isFeatured = v),
                    ),
                    const Text('Избранный материал'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: _normalizing ? null : _normalizeWithAi,
                      icon: _normalizing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(_normalizing
                          ? 'AI форматирует...'
                          : 'AI: привести к формату Навигатора'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _saveArticle,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(_saving ? 'Сохраняю...' : 'Сохранить статью'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _bodyBlocks = const [];
                          _actionLinks = const [];
                          _sourcePack = const [];
                          _relatedContentIds = const [];
                          _relatedTools = const [];
                          _error = null;
                          _ok = null;
                        });
                      },
                      child: const Text('Очистить AI-результат'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: const TextStyle(color: AurixTokens.danger)),
                ],
                if (_ok != null) ...[
                  const SizedBox(height: 10),
                  Text(_ok!,
                      style: const TextStyle(color: AurixTokens.positive)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Предпросмотр структуры',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (_bodyBlocks.isEmpty)
                  const Text(
                    'После AI-нормализации здесь появятся секции long-read.',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _bodyBlocks
                        .map((e) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AurixTokens.bg2,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AurixTokens.border),
                              ),
                              child: Text(
                                '${e['kind']} · ${(e['title'] ?? '').toString()}',
                                style: const TextStyle(
                                  color: AurixTokens.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Последние статьи в базе',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                articlesAsync.when(
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const Text(
                        'Пока нет данных в artist_navigator_materials',
                        style: TextStyle(color: AurixTokens.muted),
                      );
                    }
                    return Column(
                      children: rows.take(12).map((m) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            m.title.isNotEmpty ? m.title : m.slug,
                            style: const TextStyle(
                                color: AurixTokens.text, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${NavigatorClusters.label(m.category)} • ${m.slug}',
                            style: const TextStyle(
                                color: AurixTokens.muted, fontSize: 12),
                          ),
                          trailing: Text(
                            m.isPublished ? 'published' : 'draft',
                            style: TextStyle(
                              color: m.isPublished
                                  ? AurixTokens.positive
                                  : AurixTokens.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(
                      color: AurixTokens.orange,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (e, _) => Text(
                    'Ошибка загрузки статей: $e',
                    style: const TextStyle(color: AurixTokens.danger),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _normalizeWithAi() async {
    final draft = _draftCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    if (draft.isEmpty || title.isEmpty) {
      setState(() {
        _error = 'Заполни заголовок и черновик статьи.';
        _ok = null;
      });
      return;
    }
    setState(() {
      _normalizing = true;
      _error = null;
      _ok = null;
    });
    try {
      final prompt = _buildAiPrompt(title: title, draft: draft);
      final raw = await AiChatService().send(message: prompt);
      final parsed = _extractJsonObject(raw);
      final normalized = _normalizePayload(parsed, fallbackTitle: title);
      setState(() {
        _subtitleCtrl.text = normalized['subtitle'] as String;
        _excerptCtrl.text = normalized['excerpt'] as String;
        _tagsCtrl.text = (normalized['tags'] as List).join(', ');
        _platformsCtrl.text = (normalized['platforms'] as List).join(', ');
        _stagesCtrl.text = (normalized['stages'] as List).join(', ');
        _goalsCtrl.text = (normalized['goals'] as List).join(', ');
        _blockersCtrl.text = (normalized['blockers'] as List).join(', ');
        _readingCtrl.text = '${normalized['reading_time_minutes']}';
        _priorityCtrl.text = '${normalized['priority_score']}';
        _difficulty = normalized['difficulty'] as String;
        _category = normalized['category'] as String;
        _bodyBlocks =
            (normalized['body_blocks'] as List).cast<Map<String, dynamic>>();
        _actionLinks =
            (normalized['action_links'] as List).cast<Map<String, dynamic>>();
        _sourcePack =
            (normalized['source_pack'] as List).cast<Map<String, dynamic>>();
        _relatedContentIds =
            (normalized['related_content_ids'] as List).cast<String>();
        _relatedTools = (normalized['related_tools'] as List).cast<String>();
        _ok = 'AI привел материал к формату. Проверь и нажми сохранить.';
      });
    } catch (e) {
      setState(() {
        _error = 'Не удалось привести текст через AI: $e';
      });
    } finally {
      if (mounted) setState(() => _normalizing = false);
    }
  }

  Future<void> _saveArticle() async {
    final title = _titleCtrl.text.trim();
    final slug = _slugCtrl.text.trim().isEmpty
        ? _slugify(title)
        : _slugCtrl.text.trim();
    if (title.isEmpty || slug.isEmpty) {
      setState(() {
        _error = 'Заполни минимум заголовок и slug.';
        _ok = null;
      });
      return;
    }
    if (_bodyBlocks.isEmpty) {
      setState(() {
        _error = 'Сначала нажми AI: привести к формату Навигатора.';
        _ok = null;
      });
      return;
    }
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'id': 'nav_admin_${DateTime.now().millisecondsSinceEpoch}',
      'slug': slug,
      'title': title,
      'subtitle': _subtitleCtrl.text.trim(),
      'excerpt': _excerptCtrl.text.trim(),
      'short_description': _excerptCtrl.text.trim(),
      'category': _category,
      'cluster': _category,
      'difficulty': _difficulty,
      'reading_time_minutes': int.tryParse(_readingCtrl.text.trim()) ?? 10,
      'priority_score': double.tryParse(_priorityCtrl.text.trim()) ?? 0.75,
      'tags': _csv(_tagsCtrl.text),
      'platforms': _csv(_platformsCtrl.text),
      'stages': _csv(_stagesCtrl.text),
      'goals': _csv(_goalsCtrl.text),
      'blockers': _csv(_blockersCtrl.text),
      'stage_tags': _csv(_stagesCtrl.text),
      'goal_tags': _csv(_goalsCtrl.text),
      'platform_tags': _csv(_platformsCtrl.text),
      'format_type': 'long_read',
      'body_blocks': _bodyBlocks,
      'action_links': _actionLinks,
      'action_pack': _actionLinks,
      'source_pack': _sourcePack,
      'related_content_ids': _relatedContentIds,
      'related_articles': _relatedContentIds,
      'related_tools': _relatedTools,
      'is_published': _isPublished,
      'is_featured': _isFeatured,
      'updated_at': now,
      'created_at': now,
    };
    setState(() {
      _saving = true;
      _error = null;
      _ok = null;
    });
    try {
      await ApiClient.post('/artist-navigator-materials/upsert', data: payload);
      ref.invalidate(_navigatorAdminMaterialsProvider);
      setState(() {
        _ok = 'Статья сохранена в artist_navigator_materials.';
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка сохранения: $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _buildAiPrompt({required String title, required String draft}) {
    return '''
Ты редактор базы знаний AURIX. Приведи черновик к формату long-read статьи Навигатора артиста.
Ответь СТРОГО JSON-объектом без пояснений и без markdown.

Нужные поля:
{
  "subtitle": "краткий подзаголовок",
  "excerpt": "короткий анонс 1-2 предложения",
  "category": "одна категория",
  "difficulty": "базовый|средний|продвинутый",
  "reading_time_minutes": 8,
  "priority_score": 0.8,
  "tags": ["..."],
  "platforms": ["..."],
  "stages": ["..."],
  "goals": ["..."],
  "blockers": ["..."],
  "body_blocks": [
    {"kind":"hero","title":"Что внутри","text":"...","items":[]},
    {"kind":"intro","title":"Почему это важно","text":"...","items":[]},
    {"kind":"how_it_works","title":"Как это устроено","text":"...","items":[]},
    {"kind":"misconceptions","title":"Что понимают неправильно","text":"...","items":["...","..."]},
    {"kind":"mistakes","title":"Где теряют","text":"...","items":["...","..."]},
    {"kind":"practical_steps","title":"Как делать правильно","text":"...","items":["...","...","..."]},
    {"kind":"real_world_example","title":"Мини-кейс","text":"...","items":[]},
    {"kind":"takeaway","title":"Что запомнить","text":"...","items":[]},
    {"kind":"action_after_reading","title":"Что сделать после чтения","text":"...","items":["...","...","..."]}
  ],
  "action_links": [
    {"action_type":"open_release","label":"Открыть релиз","route":"/releases"},
    {"action_type":"open_promo","label":"Открыть промо","route":"/promo"}
  ],
  "source_pack": [
    {"title":"Внутренняя редакционная заметка","url":"https://example.com","source_type":"note","note":"Проверить и заменить на боевой источник"}
  ],
  "related_content_ids": [],
  "related_tools": ["/analytics"]
}

Ограничения:
- Только русский язык.
- Без англицизмов по возможности.
- Текст плотный, практичный, без воды.
- Сохрани смысл черновика.

Заголовок: $title
Черновик:
$draft
''';
  }

  Map<String, dynamic> _extractJsonObject(String raw) {
    final fence = RegExp(r'```json\s*([\s\S]*?)```', multiLine: true)
        .firstMatch(raw);
    final content = (fence?.group(1) ?? raw).trim();

    final candidates = <String>[
      content,
      _sliceFirstJsonObject(content),
    ].where((e) => e.trim().isNotEmpty).toList();

    Object? lastError;
    for (final candidate in candidates) {
      try {
        return (jsonDecode(candidate) as Map).cast<String, dynamic>();
      } catch (e) {
        lastError = e;
      }
    }

    // If model returned near-JSON (common for long texts), try safe repairs.
    for (final candidate in candidates) {
      try {
        final repaired = _repairJsonLike(candidate);
        return (jsonDecode(repaired) as Map).cast<String, dynamic>();
      } catch (e) {
        lastError = e;
      }
    }

    throw FormatException('Не удалось разобрать JSON AI: $lastError');
  }

  String _sliceFirstJsonObject(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return raw;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < raw.length; i++) {
      final ch = raw[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == r'\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) {
          return raw.substring(start, i + 1).trim();
        }
      }
    }
    return raw.substring(start).trim();
  }

  String _repairJsonLike(String input) {
    final src = input.trim();
    final sb = StringBuffer();
    var inString = false;
    var escaped = false;

    String? nextNonWs(int from) {
      for (var i = from; i < src.length; i++) {
        final c = src[i];
        if (c.trim().isNotEmpty) return c;
      }
      return null;
    }

    for (var i = 0; i < src.length; i++) {
      final ch = src[i];

      if (escaped) {
        sb.write(ch);
        escaped = false;
        continue;
      }

      if (ch == r'\') {
        sb.write(ch);
        escaped = true;
        continue;
      }

      if (ch == '"') {
        if (!inString) {
          inString = true;
          sb.write(ch);
          continue;
        }
        final next = nextNonWs(i + 1);
        final closesString = next == null ||
            next == ',' ||
            next == '}' ||
            next == ']' ||
            next == ':';
        if (closesString) {
          inString = false;
          sb.write(ch);
        } else {
          sb.write(r'\"');
        }
        continue;
      }

      if (inString && (ch == '\n' || ch == '\r')) {
        sb.write(r'\n');
        continue;
      }

      sb.write(ch);
    }

    var out = sb.toString();
    out = out.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    return out;
  }

  Map<String, dynamic> _normalizePayload(
    Map<String, dynamic> ai, {
    required String fallbackTitle,
  }) {
    List<Map<String, dynamic>> asBlocks(dynamic v) {
      final list = (v as List? ?? const []);
      final blocks = list
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      final byKind = {for (final b in blocks) (b['kind'] ?? '').toString(): b};
      for (final k in _formatKinds) {
        byKind.putIfAbsent(
          k,
          () => {
            'kind': k,
            'title': _defaultTitleForKind(k),
            'text': '',
            'items': <String>[],
          },
        );
      }
      return _formatKinds.map((k) => byKind[k]!).toList();
    }

    List<String> asStrings(dynamic v) =>
        ((v as List?) ?? const []).map((e) => e.toString()).toList();

    final category = (ai['category'] ?? _category).toString();
    return {
      'subtitle': (ai['subtitle'] ?? '').toString(),
      'excerpt': (ai['excerpt'] ?? '').toString(),
      'category': category,
      'difficulty': (ai['difficulty'] ?? 'средний').toString(),
      'reading_time_minutes':
          (ai['reading_time_minutes'] as num?)?.toInt() ?? 10,
      'priority_score': (ai['priority_score'] as num?)?.toDouble() ?? 0.75,
      'tags': asStrings(ai['tags']),
      'platforms': asStrings(ai['platforms']),
      'stages': asStrings(ai['stages']),
      'goals': asStrings(ai['goals']),
      'blockers': asStrings(ai['blockers']),
      'body_blocks': asBlocks(ai['body_blocks']),
      'action_links': ((ai['action_links'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      'source_pack': ((ai['source_pack'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      'related_content_ids': asStrings(ai['related_content_ids']),
      'related_tools': asStrings(ai['related_tools']),
      'title': fallbackTitle,
    };
  }

  String _defaultTitleForKind(String kind) {
    switch (kind) {
      case 'hero':
        return 'О чем этот материал';
      case 'intro':
        return 'Почему это важно';
      case 'how_it_works':
        return 'Как это устроено';
      case 'misconceptions':
        return 'Что понимают неправильно';
      case 'mistakes':
        return 'Где теряют';
      case 'practical_steps':
        return 'Как делать правильно';
      case 'real_world_example':
        return 'Мини-кейс';
      case 'takeaway':
        return 'Что запомнить';
      case 'action_after_reading':
        return 'Что сделать после чтения';
      default:
        return 'Раздел';
    }
  }

  List<String> _csv(String v) => v
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Widget _panel({required Widget child}) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AurixTokens.bg1.withValues(alpha: 0.94),
              AurixTokens.bg2.withValues(alpha: 0.86),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.stroke(0.22)),
          boxShadow: [...AurixTokens.subtleShadow],
        ),
        child: child,
      );

  String _slugify(String value) {
    var out = value.toLowerCase().trim();
    final map = <String, String>{
      'а': 'a',
      'б': 'b',
      'в': 'v',
      'г': 'g',
      'д': 'd',
      'е': 'e',
      'ё': 'e',
      'ж': 'zh',
      'з': 'z',
      'и': 'i',
      'й': 'y',
      'к': 'k',
      'л': 'l',
      'м': 'm',
      'н': 'n',
      'о': 'o',
      'п': 'p',
      'р': 'r',
      'с': 's',
      'т': 't',
      'у': 'u',
      'ф': 'f',
      'х': 'h',
      'ц': 'c',
      'ч': 'ch',
      'ш': 'sh',
      'щ': 'sch',
      'ъ': '',
      'ы': 'y',
      'ь': '',
      'э': 'e',
      'ю': 'yu',
      'я': 'ya',
    };
    map.forEach((k, v) => out = out.replaceAll(k, v));
    out = out.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    out = out.replaceAll(RegExp(r'-+'), '-');
    return out.replaceAll(RegExp(r'^-|-$'), '');
  }
}
