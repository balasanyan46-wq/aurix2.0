import 'package:flutter/material.dart' hide NavigatorState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_reveal.dart';

class NavigatorLandingScreen extends ConsumerWidget {
  const NavigatorLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(navigatorControllerProvider);
    final ctrl = ref.read(navigatorControllerProvider.notifier);
    final pad = horizontalPadding(context);
    final hasProfile = state.answers != null;
    final recommended = _topRecommended(state);
    final progress = _progress(state);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero ──
              NavigatorReveal(
                child: _Hero(
                  hasProfile: hasProfile,
                  onStart: () => context.go('/navigator/ai-intake'),
                ),
              ),

              const SizedBox(height: 20),

              // ── Progress bar (if any activity) ──
              if (progress.total > 0)
                NavigatorReveal(
                  delay: const Duration(milliseconds: 80),
                  child: _ProgressBar(progress: progress),
                ),

              if (progress.total > 0) const SizedBox(height: 20),

              // ── Next step (if has recommendations) ──
              if (hasProfile &&
                  state.recommendations?.nextBestStep != null) ...[
                NavigatorReveal(
                  delay: const Duration(milliseconds: 120),
                  child: _NextStepCard(
                    card: state.recommendations!.nextBestStep,
                    onOpen: () {
                      ctrl.markOpened(
                          state.recommendations!.nextBestStep.material.id);
                      context.push(
                          '/navigator/article/${state.recommendations!.nextBestStep.material.slug}');
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ── Recommended materials ──
              if (recommended.isNotEmpty) ...[
                NavigatorReveal(
                  delay: const Duration(milliseconds: 160),
                  child: _SectionLabel(
                    title: hasProfile ? 'Подобрано для тебя' : 'С чего начать',
                    action: hasProfile ? 'Обновить подбор' : null,
                    onAction: hasProfile
                        ? () => context.go('/navigator/ai-intake')
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                ...recommended.asMap().entries.map((entry) {
                  final i = entry.key;
                  final card = entry.value;
                  return NavigatorReveal(
                    delay: Duration(milliseconds: 200 + i * 60),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _MaterialCard(
                        material: card.material,
                        badge: card.recommendationBadge,
                        reason: card.personalReason.isNotEmpty
                            ? card.personalReason
                            : card.whyNow,
                        isSaved: state.savedIds.contains(card.material.id),
                        isCompleted:
                            state.completedIds.contains(card.material.id),
                        onOpen: () {
                          ctrl.markOpened(card.material.id);
                          context.push(
                              '/navigator/article/${card.material.slug}');
                        },
                        onSave: () => ctrl.toggleSaved(card.material.id),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 24),

              // ── Quick actions ──
              NavigatorReveal(
                delay: const Duration(milliseconds: 400),
                child: _QuickActions(
                  hasProfile: hasProfile,
                  savedCount: state.savedIds.length,
                  onLibrary: () => context.push('/navigator/library'),
                  onSaved: () => context.push('/navigator/saved'),
                  onIntake: () => context.go('/navigator/ai-intake'),
                ),
              ),

              const SizedBox(height: 24),

              // ── Topics grid ──
              NavigatorReveal(
                delay: const Duration(milliseconds: 460),
                child: const _SectionLabel(title: 'Темы'),
              ),
              const SizedBox(height: 10),
              NavigatorReveal(
                delay: const Duration(milliseconds: 500),
                child: _TopicsGrid(
                  onSelect: (topic) {
                    ctrl.setQuery(topic);
                    context.push('/navigator/library');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<NavigatorRecommendationCard> _topRecommended(NavigatorState state) {
    final rec = state.recommendations;
    if (rec != null && rec.recommendedMaterials.isNotEmpty) {
      return rec.recommendedMaterials.take(4).toList();
    }
    final fallback = [...state.materials]
      ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return fallback.take(4).map((m) {
      return NavigatorRecommendationCard(
        material: m,
        whyNow: m.excerpt,
        score: m.priorityScore,
        recommendationBadge: '',
      );
    }).toList();
  }

  _ProgressData _progress(NavigatorState state) {
    final saved = state.savedIds.length;
    final completed = state.completedIds.length;
    final total = state.materials.length;
    return _ProgressData(
      saved: saved,
      completed: completed,
      total: total,
    );
  }
}

class _ProgressData {
  final int saved;
  final int completed;
  final int total;
  const _ProgressData(
      {required this.saved, required this.completed, required this.total});
}

// ─────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.hasProfile, required this.onStart});
  final bool hasProfile;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.explore_rounded,
                  color: AurixTokens.accent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Навигатор артиста',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Изучай только то, что реально нужно тебе сейчас. '
            'AI подберет материалы под твой этап, цель и текущие задачи.',
            style: TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          if (!hasProfile) ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Настроить персональный подбор'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Progress bar
// ─────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});
  final _ProgressData progress;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.total > 0
        ? progress.completed / progress.total
        : 0.0;
    return AurixGlassCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Прогресс: ${progress.completed} из ${progress.total}',
                style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(
                  color: AurixTokens.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AurixTokens.bg2,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AurixTokens.accent),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Next step card
// ─────────────────────────────────────────────────

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.card, required this.onOpen});
  final NavigatorRecommendationCard card;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: AurixGlassCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AurixTokens.positive.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: AurixTokens.positive,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Следующий шаг',
                    style: TextStyle(
                      color: AurixTokens.positive,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.material.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AurixTokens.glass(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${card.material.readingTimeMinutes} мин',
                style: const TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: AurixTokens.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.title,
    this.action,
    this.onAction,
  });
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AurixTokens.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                color: AurixTokens.accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// Material card
// ─────────────────────────────────────────────────

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.badge,
    required this.reason,
    required this.isSaved,
    required this.isCompleted,
    required this.onOpen,
    required this.onSave,
  });

  final NavigatorMaterial material;
  final String badge;
  final String reason;
  final bool isSaved;
  final bool isCompleted;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: AurixGlassCard(
        padding: const EdgeInsets.all(16),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: badge + meta
            Row(
              children: [
                if (badge.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AurixTokens.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: AurixTokens.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                _MetaPill(
                  icon: Icons.schedule_rounded,
                  label: '${material.readingTimeMinutes} мин',
                ),
                const SizedBox(width: 6),
                _MetaPill(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: material.difficulty,
                ),
                const Spacer(),
                if (isCompleted)
                  const Icon(Icons.check_circle_rounded,
                      color: AurixTokens.positive, size: 18),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              material.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),

            // Excerpt
            Text(
              material.excerpt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AurixTokens.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            // Reason (if personalized)
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AurixTokens.accent, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 12,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onOpen,
                    child: const Text('Читать'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onSave,
                  icon: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: isSaved
                        ? AurixTokens.accent
                        : AurixTokens.muted,
                  ),
                  tooltip: isSaved ? 'Убрать из сохраненных' : 'Сохранить',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AurixTokens.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: AurixTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// Quick actions
// ─────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.hasProfile,
    required this.savedCount,
    required this.onLibrary,
    required this.onSaved,
    required this.onIntake,
  });

  final bool hasProfile;
  final int savedCount;
  final VoidCallback onLibrary;
  final VoidCallback onSaved;
  final VoidCallback onIntake;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF5B8DEF),
          title: 'Библиотека',
          subtitle: 'Все материалы с фильтрами и поиском',
          onTap: onLibrary,
        ),
        const SizedBox(height: 8),
        if (savedCount > 0) ...[
          _ActionTile(
            icon: Icons.bookmark_rounded,
            color: AurixTokens.accent,
            title: 'Мой маршрут',
            subtitle: '$savedCount сохраненных материалов',
            onTap: onSaved,
          ),
          const SizedBox(height: 8),
        ],
        _ActionTile(
          icon: Icons.auto_awesome_rounded,
          color: AurixTokens.accentWarm,
          title: hasProfile ? 'Обновить AI-подбор' : 'Настроить AI-подбор',
          subtitle: hasProfile
              ? 'Пересобрать рекомендации под текущие задачи'
              : 'Ответь на 8 вопросов — получи персональный маршрут',
          onTap: onIntake,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AurixGlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AurixTokens.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// Topics grid
// ─────────────────────────────────────────────────

class _TopicsGrid extends StatelessWidget {
  const _TopicsGrid({required this.onSelect});
  final ValueChanged<String> onSelect;

  static const _topics = <(String, IconData)>[
    ('Старт', Icons.rocket_launch_rounded),
    ('Релизы', Icons.album_rounded),
    ('Яндекс Музыка', Icons.music_note_rounded),
    ('VK Музыка', Icons.headphones_rounded),
    ('Контент', Icons.videocam_rounded),
    ('Продвижение', Icons.trending_up_rounded),
    ('Аналитика', Icons.bar_chart_rounded),
    ('Монетизация', Icons.payments_rounded),
    ('Право', Icons.gavel_rounded),
    ('Дисциплина', Icons.psychology_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _topics.map((t) {
        return GestureDetector(
          onTap: () => onSelect(t.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AurixTokens.bg2.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AurixTokens.stroke(0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(t.$2, size: 15, color: AurixTokens.muted),
                const SizedBox(width: 6),
                Text(
                  t.$1,
                  style: const TextStyle(
                    color: AurixTokens.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
