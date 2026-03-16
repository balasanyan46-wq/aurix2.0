import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';

Future<void> showNavigatorRouteBuilderSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _NavigatorRouteBuilderSheet(),
  );
}

class _NavigatorRouteBuilderSheet extends ConsumerStatefulWidget {
  const _NavigatorRouteBuilderSheet();

  @override
  ConsumerState<_NavigatorRouteBuilderSheet> createState() =>
      _NavigatorRouteBuilderSheetState();
}

class _NavigatorRouteBuilderSheetState
    extends ConsumerState<_NavigatorRouteBuilderSheet> {
  int step = 0;
  String? stage;
  String? goal;
  String? blocker;
  String? depth;
  String? releaseExperience;
  String? teamSetup;
  final Set<String> focus = <String>{};
  bool saving = false;

  static const int total = 7;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context);
    final pad = horizontalPadding(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 14 + inset.bottom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: AurixTokens.bg1.withValues(alpha: 0.985),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AurixTokens.stroke(0.24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 28,
              spreadRadius: -16,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Собрать мой маршрут',
                style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Короткая AI-диагностика, чтобы показать следующий лучший шаг.',
                style: TextStyle(color: AurixTokens.textSecondary),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (step + 1) / total,
                  minHeight: 8,
                  backgroundColor: AurixTokens.glass(0.12),
                  valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Шаг ${step + 1} из $total',
                style: const TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: SizedBox(
                  key: ValueKey(step),
                  width: double.infinity,
                  child: _stepBody(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (step > 0)
                    OutlinedButton(
                      onPressed: saving ? null : () => setState(() => step--),
                      child: const Text('Назад'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: !_canNext() || saving ? null : _next,
                    child: Text(step == total - 1 ? 'Собрать маршрут' : 'Далее'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody() {
    switch (step) {
      case 0:
        return _choice(
          'На каком этапе ты сейчас?',
          const [
            'только начинаю',
            'уже выпускаю музыку',
            'выпускаю регулярно',
            'есть команда / движение',
          ],
          stage,
          (v) => setState(() => stage = v),
        );
      case 1:
        return _choice(
          'Что сейчас важнее всего?',
          const [
            'подготовить релиз',
            'набрать аудиторию',
            'выстроить контент',
            'разобраться с продвижением',
            'разобраться с правами',
            'начать систему',
            'заработать на музыке',
          ],
          goal,
          (v) => setState(() => goal = v),
        );
      case 2:
        return _choice(
          'Ты уже выпускал музыку официально?',
          const [
            'да регулярно',
            'да несколько раз',
            'нет',
          ],
          releaseExperience,
          (v) => setState(() => releaseExperience = v),
        );
      case 3:
        return _choice(
          'Есть ли у тебя команда или рабочие договоренности?',
          const [
            'всё делаю сам',
            'есть люди без договоров',
            'есть команда и процессы',
          ],
          teamSetup,
          (v) => setState(() => teamSetup = v),
        );
      case 4:
        return _choice(
          'Что у тебя слабее всего?',
          const [
            'позиционирование',
            'контент',
            'дисциплина',
            'продвижение',
            'понимание платформ',
            'защита прав',
            'упаковка бренда',
          ],
          blocker,
          (v) => setState(() => blocker = v),
        );
      case 5:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'На каких платформах ты делаешь основной упор?',
              style: TextStyle(
                color: AurixTokens.text,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in const [
                  'vk',
                  'яндекс',
                  'youtube',
                  'tiktok',
                  'telegram',
                  'пока не понимаю',
                ])
                  FilterChip(
                    label: Text(item),
                    selected: focus.contains(item),
                    onSelected: (s) {
                      setState(() {
                        if (s) {
                          focus.add(item);
                        } else {
                          focus.remove(item);
                        }
                      });
                    },
                    selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
                    backgroundColor: AurixTokens.glass(0.06),
                    side: BorderSide(color: AurixTokens.stroke(0.24)),
                  ),
              ],
            ),
          ],
        );
      default:
        return _choice(
          'В каком формате удобнее учиться?',
          const [
            'быстро и по делу',
            'баланс',
            'глубоко и подробно',
          ],
          depth,
          (v) => setState(() => depth = v),
        );
    }
  }

  Widget _choice(
    String title,
    List<String> options,
    String? value,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AurixTokens.text,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in options)
              ChoiceChip(
                label: Text(item),
                selected: value == item,
                onSelected: (_) => onChanged(item),
                selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
                backgroundColor: AurixTokens.glass(0.06),
                side: BorderSide(color: AurixTokens.stroke(0.24)),
              ),
          ],
        ),
      ],
    );
  }

  bool _canNext() {
    return switch (step) {
      0 => stage != null,
      1 => goal != null,
      2 => releaseExperience != null,
      3 => teamSetup != null,
      4 => blocker != null,
      5 => focus.isNotEmpty,
      6 => depth != null,
      _ => false,
    };
  }

  Future<void> _next() async {
    if (step < total - 1) {
      setState(() => step++);
      return;
    }
    setState(() => saving = true);
    final answers = NavigatorOnboardingAnswers(
      stage: stage!,
      goal: goal!,
      releaseStage: '',
      platforms: focus.toList(),
      blocker: blocker!,
      depth: depth!,
      marketRegion: _resolveMarketRegion(focus),
      releaseExperience: releaseExperience ?? '',
      teamSetup: teamSetup ?? '',
    );
    await ref.read(navigatorControllerProvider.notifier).submitOnboarding(answers);
    if (mounted) Navigator.of(context).pop();
  }

  String _resolveMarketRegion(Set<String> selectedPlatforms) {
    final low = selectedPlatforms.map((e) => e.toLowerCase()).toSet();
    if (low.contains('vk') ||
        low.contains('яндекс') ||
        low.contains('telegram')) {
      return 'ru_cis';
    }
    return 'global';
  }
}
