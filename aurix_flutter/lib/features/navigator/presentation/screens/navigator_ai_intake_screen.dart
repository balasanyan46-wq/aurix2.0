import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';

class NavigatorAiIntakeScreen extends ConsumerStatefulWidget {
  const NavigatorAiIntakeScreen({super.key});

  @override
  ConsumerState<NavigatorAiIntakeScreen> createState() =>
      _NavigatorAiIntakeScreenState();
}

class _NavigatorAiIntakeScreenState extends ConsumerState<NavigatorAiIntakeScreen> {
  int _step = 0;
  bool _submitting = false;

  String? _stage;
  String? _goal;
  String? _confusion;
  String? _pain;
  String? _experience;
  String? _format;
  String? _hours;
  String? _outcome;

  final _steps = const [
    _IntakeStep(
      title: 'На каком этапе ты сейчас?',
      subtitle: 'Это поможет не давать тебе лишние материалы.',
      options: [
        'только начинаю',
        'уже выпускаю музыку',
        'есть релизы, но нет роста',
        'есть аудитория, хочу масштабироваться',
      ],
    ),
    _IntakeStep(
      title: 'Что сейчас важнее всего?',
      subtitle: 'Выбери главный фокус на ближайший период.',
      options: [
        'набрать аудиторию',
        'подготовить релиз',
        'разобраться с продвижением',
        'понять платформы',
        'выстроить контент',
        'заработать на музыке',
        'разобраться с правами',
      ],
    ),
    _IntakeStep(
      title: 'Где сейчас больше всего непонимания?',
      subtitle: 'AURIX подстроит подборку под эту зону.',
      options: [
        'Яндекс Музыка',
        'VK Музыка',
        'Spotify / международка',
        'контент / Reels / Shorts',
        'аналитика',
        'позиционирование',
        'договоры / права',
        'монетизация',
      ],
    ),
    _IntakeStep(
      title: 'Что происходит чаще всего?',
      subtitle: 'Выбери главную боль, которую нужно снять.',
      options: [
        'делаю много, а роста нет',
        'нет системы',
        'не понимаю, что реально работает',
        'путаюсь в советах',
        'не хватает дисциплины',
        'страшно ошибиться',
        'не понимаю, куда идти дальше',
      ],
    ),
    _IntakeStep(
      title: 'Сколько у тебя уже опыта?',
      subtitle: 'Это влияет на глубину и сложность материалов.',
      options: [
        'до 3 месяцев',
        '3-12 месяцев',
        '1-3 года',
        '3+ года',
      ],
    ),
    _IntakeStep(
      title: 'Как тебе удобнее учиться?',
      subtitle: 'Формат поможет собирать читаемые подборки.',
      options: [
        'быстро и по сути',
        'подробно и глубоко',
        'через кейсы',
        'через пошаговые инструкции',
      ],
    ),
    _IntakeStep(
      title: 'Сколько времени готов уделять обучению в неделю?',
      subtitle: 'AURIX подберет ритм и длину материалов.',
      options: [
        '15-30 минут',
        '1-2 часа',
        '3-5 часов',
        'сколько нужно',
      ],
    ),
    _IntakeStep(
      title: 'Что хочешь получить на выходе?',
      subtitle: 'Это станет главным критерием персональной подборки.',
      options: [
        'четкое понимание, что делать',
        'список приоритетных материалов',
        'личную карту тем',
        'персональный фокус на месяц',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);
    final curr = _steps[_step];
    final progress = (_step + 1) / _steps.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 18, pad, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI-настройка Навигатора',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 34,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ответь на несколько вопросов, и AURIX соберет персональный образовательный профиль и подборку материалов.',
                  style: TextStyle(color: AurixTokens.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AurixTokens.glass(0.12),
                    valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
                  ),
                ),
                const SizedBox(height: 16),
                AurixGlassCard(
                  radius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Шаг ${_step + 1} из ${_steps.length}',
                        style: const TextStyle(
                          color: AurixTokens.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        curr.title,
                        style: const TextStyle(
                          color: AurixTokens.text,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        curr.subtitle,
                        style: const TextStyle(
                          color: AurixTokens.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: curr.options
                            .map(
                              (opt) => ChoiceChip(
                                label: Text(opt),
                                selected: _selectedForStep(_step) == opt,
                                onSelected: (_) => setState(() => _setForStep(_step, opt)),
                                selectedColor: AurixTokens.orange.withValues(alpha: 0.22),
                                backgroundColor: AurixTokens.glass(0.1),
                                side: BorderSide(color: AurixTokens.stroke(0.24)),
                                labelStyle: TextStyle(
                                  color: _selectedForStep(_step) == opt
                                      ? AurixTokens.orange
                                      : AurixTokens.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _step == 0 || _submitting
                                ? null
                                : () => setState(() => _step--),
                            child: const Text('Назад'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _submitting ? null : _onNext,
                            child: Text(
                              _step == _steps.length - 1
                                  ? (_submitting
                                      ? 'Собираем профиль...'
                                      : 'Собрать AI-подбор')
                                  : 'Далее',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _selectedForStep(int step) {
    switch (step) {
      case 0:
        return _stage;
      case 1:
        return _goal;
      case 2:
        return _confusion;
      case 3:
        return _pain;
      case 4:
        return _experience;
      case 5:
        return _format;
      case 6:
        return _hours;
      case 7:
        return _outcome;
      default:
        return null;
    }
  }

  void _setForStep(int step, String value) {
    switch (step) {
      case 0:
        _stage = value;
        break;
      case 1:
        _goal = value;
        break;
      case 2:
        _confusion = value;
        break;
      case 3:
        _pain = value;
        break;
      case 4:
        _experience = value;
        break;
      case 5:
        _format = value;
        break;
      case 6:
        _hours = value;
        break;
      case 7:
        _outcome = value;
        break;
    }
  }

  Future<void> _onNext() async {
    final selected = _selectedForStep(_step);
    if (selected == null || selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбери один вариант, чтобы продолжить')),
      );
      return;
    }
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final answers = NavigatorOnboardingAnswers(
      stage: _stage ?? 'только начинаю',
      goal: _goal ?? 'начать систему',
      releaseStage: _mapReleaseStage(_experience ?? ''),
      platforms: _mapPlatforms(_confusion ?? ''),
      blocker: _pain ?? 'не понимаю, куда идти дальше',
      depth: _mapDepth(_format ?? ''),
      marketRegion: _mapRegion(_confusion ?? ''),
      releaseExperience: _experience ?? '',
      teamSetup: '',
      confusionArea: _confusion ?? '',
      learningHoursPerWeek: _hours ?? '',
      desiredOutcome: _outcome ?? '',
    );
    try {
      await ref.read(navigatorControllerProvider.notifier).submitOnboarding(answers);
      if (!mounted) return;
      context.go('/navigator/results');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _mapDepth(String format) {
    switch (format) {
      case 'быстро и по сути':
        return 'быстро и по делу';
      case 'подробно и глубоко':
        return 'глубоко и подробно';
      default:
        return 'баланс';
    }
  }

  String _mapReleaseStage(String exp) {
    switch (exp) {
      case 'до 3 месяцев':
        return 'релиза пока нет';
      case '3-12 месяцев':
        return 'релиз через 30+ дней';
      case '1-3 года':
      case '3+ года':
        return 'релиз через 14-30 дней';
      default:
        return '';
    }
  }

  List<String> _mapPlatforms(String confusion) {
    switch (confusion) {
      case 'Яндекс Музыка':
        return const ['яндекс', 'yandex_music'];
      case 'VK Музыка':
        return const ['vk', 'vk_music'];
      case 'Spotify / международка':
        return const ['spotify', 'youtube'];
      case 'контент / Reels / Shorts':
        return const ['youtube', 'short-form'];
      default:
        return const [];
    }
  }

  String _mapRegion(String confusion) {
    if (confusion == 'Яндекс Музыка' || confusion == 'VK Музыка') {
      return 'ru_cis';
    }
    return 'ru_cis';
  }
}

class _IntakeStep {
  final String title;
  final String subtitle;
  final List<String> options;

  const _IntakeStep({
    required this.title,
    required this.subtitle,
    required this.options,
  });
}
