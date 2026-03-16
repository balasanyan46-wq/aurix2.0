import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';

class NavigatorArticleScreen extends ConsumerStatefulWidget {
  const NavigatorArticleScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<NavigatorArticleScreen> createState() =>
      _NavigatorArticleScreenState();
}

class _NavigatorArticleScreenState extends ConsumerState<NavigatorArticleScreen> {
  NavigatorMaterial? _material;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = ref.read(navigatorControllerProvider);
    NavigatorMaterial? mat;
    for (final m in state.materials) {
      if (m.slug == widget.slug) {
        mat = m;
        break;
      }
    }
    mat ??= await ref.read(navigatorRepositoryProvider).getBySlug(widget.slug);
    if (!mounted) return;
    if (mat != null) {
      final openedId = mat.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(navigatorControllerProvider.notifier).markOpened(openedId);
      });
    }
    setState(() {
      _material = mat;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final m = _material;
    if (m == null) {
      return const Center(
        child: Text(
          'Материал не найден',
          style: TextStyle(color: AurixTokens.textSecondary),
        ),
      );
    }

    final state = ref.watch(navigatorControllerProvider);
    final ctrl = ref.read(navigatorControllerProvider.notifier);
    final next = _resolveNextMaterial(state.materials, m);
    final isSaved = state.savedIds.contains(m.id);
    final isCompleted = state.completedIds.contains(m.id);

    final hero = _text(m, 'hero', fallback: m.excerpt);
    final audience = _text(m, 'audience_label', fallback: _audienceLabel(m));
    final intro = _text(
      m,
      'intro',
      fallback: _text(
        m,
        'why_it_matters',
        fallback:
            'Тема кажется простой только на первый взгляд. На практике она влияет на качество решений, темп роста и результат релизов.',
      ),
    );
    final howItWorks = _text(
      m,
      'how_it_works',
      fallback: _combinedText(
        m,
        'key_points',
        fallback:
            'Механика всегда сводится к одному: четкий фокус, измеримые сигналы и регулярная корректировка действий.',
      ),
    );
    final insiderNotes = _items(m, 'insider_notes');
    final misconceptions = _items(m, 'misconceptions');
    final mistakes = _items(m, 'mistakes');
    final practicalSteps = _items(
      m,
      'practice_steps',
      fallback: _items(
        m,
        'action_steps',
        fallback: const [
          'Выбери один приоритетный шаг.',
          'Поставь дедлайн и критерий результата.',
          'Проверь эффект через 3-7 дней.',
        ],
      ),
    );
    final example = _text(
      m,
      'real_world_example',
      fallback:
          'В реальном кейсе результат появляется, когда команда убирает хаос и действует по одной понятной последовательности.',
    );
    final takeaway = _text(
      m,
      'takeaway',
      fallback: _text(
        m,
        'final_takeaway',
        fallback:
            'Главная идея: глубокое понимание темы дает результат только тогда, когда сразу переводится в конкретные действия.',
      ),
    );
    final actionAfterReading = _items(
      m,
      'action_after_reading',
      fallback: practicalSteps.take(4).toList(),
    );

    return PremiumPageContainer(
      maxWidth: 900,
      padding: EdgeInsets.fromLTRB(pad, 20, pad, 34),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LongReadHero(
                  title: m.title,
                  description: hero,
                  category: NavigatorClusters.label(m.category),
                  readingTime: m.readingTimeMinutes,
                  audience: audience,
                ),
                const SizedBox(height: 18),
                _LongReadSection(
                  title: 'В чем суть',
                  body: intro,
                ),
                const SizedBox(height: 18),
                _LongReadSection(
                  title: 'Как это реально устроено',
                  body: howItWorks,
                ),
                if (insiderNotes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _ListSection(
                    title: 'Инсайты из практики рынка',
                    lead:
                        'Это наблюдения из реальных рабочих сценариев артистов и команд, которые редко попадают в обычные гайды.',
                    items: insiderNotes,
                    bulletColor: const Color(0xFF7AA8FF),
                  ),
                ],
                if (misconceptions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _ListSection(
                    title: 'Что артист обычно понимает неправильно',
                    lead:
                        'Эти иллюзии создают ощущение работы, но мешают реальному результату.',
                    items: misconceptions,
                    bulletColor: const Color(0xFFFFA76A),
                  ),
                ],
                if (mistakes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _ListSection(
                    title: 'Реальные ошибки на практике',
                    lead:
                        'Каждая ошибка ниже не просто “неправильно”, а приводит к конкретной потере темпа, денег или фокуса.',
                    items: mistakes,
                    bulletColor: const Color(0xFFFF8B8B),
                  ),
                ],
                if (practicalSteps.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _ListSection(
                    title: 'Что делать правильно',
                    lead:
                        'Пошаговая логика внедрения, чтобы после чтения появилось не вдохновение, а управляемое действие.',
                    items: practicalSteps,
                    bulletColor: AurixTokens.positive,
                  ),
                ],
                const SizedBox(height: 18),
                _ExampleSection(text: example),
                const SizedBox(height: 18),
                _LongReadSection(
                  title: 'Что нужно запомнить',
                  body: takeaway,
                ),
                const SizedBox(height: 18),
                _ActionAfterReadingSection(
                  items: actionAfterReading,
                  isSaved: isSaved,
                  isCompleted: isCompleted,
                  hasNext: next != null,
                  onSave: () => ctrl.toggleSaved(m.id),
                  onComplete: () => ctrl.toggleCompleted(m.id),
                  onNext: next == null
                      ? null
                      : () => context.push('/navigator/article/${next.slug}'),
                ),
              ],
            ),
    );
  }

  String _text(
    NavigatorMaterial material,
    String kind, {
    required String fallback,
  }) {
    for (final block in material.bodyBlocks) {
      if (block.kind == kind) {
        if (block.text.trim().isNotEmpty) return block.text.trim();
        if (block.items.isNotEmpty) return block.items.join('\n');
      }
    }
    return fallback;
  }

  String _combinedText(
    NavigatorMaterial material,
    String kind, {
    required String fallback,
  }) {
    for (final block in material.bodyBlocks) {
      if (block.kind == kind) {
        final parts = <String>[];
        if (block.text.trim().isNotEmpty) parts.add(block.text.trim());
        if (block.items.isNotEmpty) {
          parts.add(block.items.map((e) => '• $e').join('\n'));
        }
        if (parts.isNotEmpty) return parts.join('\n\n');
      }
    }
    return fallback;
  }

  List<String> _items(
    NavigatorMaterial material,
    String kind, {
    List<String> fallback = const [],
  }) {
    for (final block in material.bodyBlocks) {
      if (block.kind == kind && block.items.isNotEmpty) {
        return block.items;
      }
    }
    return fallback;
  }

  NavigatorMaterial? _resolveNextMaterial(
    List<NavigatorMaterial> all,
    NavigatorMaterial current,
  ) {
    for (final id in current.relatedContentIds) {
      for (final item in all) {
        if (item.id == id && item.slug != current.slug) return item;
      }
    }
    for (final item in all) {
      if (item.slug != current.slug && item.category == current.category) return item;
    }
    for (final item in all) {
      if (item.slug != current.slug) return item;
    }
    return null;
  }

  String _audienceLabel(NavigatorMaterial m) {
    if (m.stages.isEmpty) return 'для артистов, которые хотят системный рост';
    return 'для артистов на этапе: ${m.stages.take(2).join(' / ')}';
  }
}

class _LongReadHero extends StatelessWidget {
  const _LongReadHero({
    required this.title,
    required this.description,
    required this.category,
    required this.readingTime,
    required this.audience,
  });

  final String title;
  final String description;
  final String category;
  final int readingTime;
  final String audience;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 42,
              height: 1.06,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _meta(category),
              _meta('~$readingTime мин'),
              _meta(audience),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AurixTokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LongReadSection extends StatelessWidget {
  const _LongReadSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final paragraphs = body
        .split('\n\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return AurixGlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          ...paragraphs.map(
            (paragraph) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                paragraph,
                style: const TextStyle(
                  color: AurixTokens.textSecondary,
                  fontSize: 16,
                  height: 1.72,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.lead,
    required this.items,
    required this.bulletColor,
  });

  final String title;
  final String lead;
  final List<String> items;
  final Color bulletColor;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 24,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lead,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 14,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: bulletColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: AurixTokens.textSecondary,
                        fontSize: 15.5,
                        height: 1.62,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleSection extends StatelessWidget {
  const _ExampleSection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.accentWarm.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: 0.1),
            AurixTokens.glass(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Как это выглядит в реальности',
            style: TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionAfterReadingSection extends StatelessWidget {
  const _ActionAfterReadingSection({
    required this.items,
    required this.isSaved,
    required this.isCompleted,
    required this.hasNext,
    required this.onSave,
    required this.onComplete,
    required this.onNext,
  });

  final List<String> items;
  final bool isSaved;
  final bool isCompleted;
  final bool hasNext;
  final VoidCallback onSave;
  final VoidCallback onComplete;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Что сделать после чтения',
            style: TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          ...items.take(5).map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• $item',
                    style: const TextStyle(
                      color: AurixTokens.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onSave,
                icon: Icon(
                  isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                ),
                label: Text(isSaved ? 'Сохранено' : 'Сохранить'),
              ),
              OutlinedButton.icon(
                onPressed: onComplete,
                icon: Icon(
                  isCompleted ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                ),
                label: Text(isCompleted ? 'Прочитано' : 'Отметить прочитанным'),
              ),
              if (hasNext)
                FilledButton(
                  onPressed: onNext,
                  child: const Text('Следующий материал'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
