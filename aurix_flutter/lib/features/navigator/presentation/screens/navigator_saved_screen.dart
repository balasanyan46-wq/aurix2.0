import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';

class NavigatorSavedScreen extends ConsumerWidget {
  const NavigatorSavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(navigatorControllerProvider);
    final ctrl = ref.read(navigatorControllerProvider.notifier);
    final pad = horizontalPadding(context);
    final saved = state.materials.where((m) => state.savedIds.contains(m.id)).toList();
    final done = saved.where((m) => state.completedIds.contains(m.id)).length;
    final progress = saved.isEmpty ? 0.0 : (done / saved.length);

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 28),
      children: [
        Text(
          'Мой маршрут',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        AurixGlassCard(
          radius: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Прогресс по маршруту',
                style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AurixTokens.glass(0.12),
                  valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$done из ${saved.length} материалов пройдено',
                style: const TextStyle(color: AurixTokens.textSecondary),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () {
                  final rec = state.recommendations;
                  if (rec == null || rec.topRequired.isEmpty) {
                    context.go('/navigator/library');
                    return;
                  }
                  context.go('/navigator/article/${rec.topRequired.first.material.slug}');
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Следующий лучший шаг'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (saved.isEmpty)
          AurixGlassCard(
            child: Column(
              children: [
                const Icon(Icons.bookmarks_outlined,
                    color: AurixTokens.muted, size: 30),
                const SizedBox(height: 8),
                const Text('Пока пусто',
                    style: TextStyle(
                        color: AurixTokens.text, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Сохраняй материалы из библиотеки или рекомендаций, чтобы собрать личный маршрут.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AurixTokens.textSecondary),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => context.go('/navigator/library'),
                  child: const Text('Открыть библиотеку'),
                ),
              ],
            ),
          )
        else
          ...saved.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AurixGlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: const TextStyle(
                          color: AurixTokens.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.excerpt,
                      style: const TextStyle(color: AurixTokens.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton(
                          onPressed: () =>
                              context.push('/navigator/article/${m.slug}'),
                          child: const Text('Открыть'),
                        ),
                        OutlinedButton(
                          onPressed: () => ctrl.toggleCompleted(m.id),
                          child: Text(
                            state.completedIds.contains(m.id)
                                ? 'Отметить как не пройдено'
                                : 'Отметить как пройдено',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => ctrl.toggleSaved(m.id),
                          child: const Text('Убрать из маршрута'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
