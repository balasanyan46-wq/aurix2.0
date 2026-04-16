import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/presentation/providers/artist_provider.dart';
import 'package:aurix_flutter/presentation/screens/studio/models/artist_profile.dart';

class ArtistOnboardingFlow extends ConsumerStatefulWidget {
  const ArtistOnboardingFlow({super.key});

  @override
  ConsumerState<ArtistOnboardingFlow> createState() => _ArtistOnboardingFlowState();
}

class _ArtistOnboardingFlowState extends ConsumerState<ArtistOnboardingFlow> {
  int _step = 0; // 0=intro, 1=name, 2=genre, 3=audience, 4=experience, 5=goals, 6=done
  final _nameCtrl = TextEditingController();
  final Set<String> _genres = {};
  final Set<String> _audience = {};
  final Set<String> _experience = {};
  final Set<String> _goals = {};
  bool _saving = false;

  static const _genreOptions = [
    'Хип-хоп', 'Рэп', 'Поп', 'R&B', 'Рок', 'Электро',
    'Инди', 'Трэп', 'Дрилл', 'Фонк', 'Альтернатива', 'Другое',
  ];

  // Step 3: Аудитория — кто слушает
  static const _audienceOptions = [
    '14-18 лет', '18-24 года', '25-34 года', '35+',
    'Парни', 'Девушки', 'Все',
    'Россия', 'СНГ', 'Весь мир',
  ];

  // Step 4: Уровень опыта
  static const _experienceOptions = [
    'Только начинаю', 'Есть несколько треков', 'Выпускал релизы',
    'Есть аудитория (до 1K)', 'Есть аудитория (1K-10K)', 'Больше 10K',
    'Пишу сам', 'Работаю с продюсером', 'Сам продюсер',
    'Снимаю клипы', 'Выступаю живьём',
  ];

  // Step 5: Цели
  static const _goalOptions = [
    'Набрать первую аудиторию', 'Больше стримов', 'Попасть в плейлисты',
    'Выпустить альбом/EP', 'Начать зарабатывать', 'Найти свой звук',
    'Коллаборации', 'Живые выступления', 'Выход на международный рынок',
  ];

  void _next() {
    if (_step < 5) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final profile = ArtistProfile(
      name: _nameCtrl.text.trim(),
      genre: _genres.join(', '),
      mood: _audience.join(', '),
      references: _experience.toList(),
      goals: _goals.toList(),
    );

    await ref.read(artistProfileProvider.notifier).save(profile);

    // Sync to backend — AI will use all this data for personalization
    try {
      await ApiClient.post('/api/ai/profile', data: {
        'name': profile.name,
        'genre': profile.genre,
        'mood': _audience.join(', '),
        'references_list': _experience.toList(),
        'goals': _goals.toList(),
        'style_description': 'Аудитория: ${_audience.join(", ")}. Опыт: ${_experience.join(", ")}.',
      });
    } catch (_) {}

    if (mounted) {
      setState(() => _step = 6);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) context.go('/home');
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: AnimatedSwitcher(
                duration: AurixTokens.dMedium,
                child: _buildStep(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Column(
      key: const ValueKey('name'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepIndicator(current: 1, total: 5),
        const SizedBox(height: 32),
        Text('Как тебя зовут?', style: TextStyle(
          fontFamily: AurixTokens.fontHeading, color: AurixTokens.text,
          fontSize: 24, fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 8),
        Text('Сценическое имя или псевдоним', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        const SizedBox(height: 28),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            color: AurixTokens.text,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Твоё имя',
            hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.4)),
            filled: true,
            fillColor: AurixTokens.surface1,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AurixTokens.stroke(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AurixTokens.stroke(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AurixTokens.accent),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          ),
          onSubmitted: (_) { if (_nameCtrl.text.trim().isNotEmpty) _next(); },
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            SizedBox(
              height: 48, width: 48,
              child: IconButton(
                onPressed: _back,
                icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
                style: IconButton.styleFrom(
                  backgroundColor: AurixTokens.surface1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _NextButton(enabled: _nameCtrl.text.trim().isNotEmpty, onPressed: _next)),
          ],
        ),
      ],
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _IntroStep(onStart: () => setState(() => _step = 1));
      case 1: return _buildNameStep();
      case 2: return _MultiSelectStep(
        key: const ValueKey('genre'),
        title: 'Твой жанр',
        subtitle: 'Можно выбрать несколько — AI учтёт все',
        items: _genreOptions,
        selected: _genres,
        onToggle: (v) => setState(() {
          _genres.contains(v) ? _genres.remove(v) : _genres.add(v);
        }),
        onNext: _next,
        onBack: _back,
        step: 2,
        canSkip: false,
        canProceed: _genres.isNotEmpty,
      );
      case 3: return _MultiSelectStep(
        key: const ValueKey('audience'),
        title: 'Твоя аудитория',
        subtitle: 'Кто слушает или будет слушать твою музыку?',
        items: _audienceOptions,
        selected: _audience,
        onToggle: (v) => setState(() {
          _audience.contains(v) ? _audience.remove(v) : _audience.add(v);
        }),
        onNext: _next,
        onBack: _back,
        step: 3,
        canSkip: false,
        canProceed: _audience.isNotEmpty,
      );
      case 4: return _MultiSelectStep(
        key: const ValueKey('experience'),
        title: 'Твой опыт',
        subtitle: 'AI подстроит сложность советов под твой уровень',
        items: _experienceOptions,
        selected: _experience,
        onToggle: (v) => setState(() {
          _experience.contains(v) ? _experience.remove(v) : _experience.add(v);
        }),
        onNext: _next,
        onBack: _back,
        step: 4,
      );
      case 5: return _MultiSelectStep(
        key: const ValueKey('goals'),
        title: 'Твои цели',
        subtitle: 'AI подстроит советы под твои приоритеты',
        items: _goalOptions,
        selected: _goals,
        onToggle: (v) => setState(() {
          _goals.contains(v) ? _goals.remove(v) : _goals.add(v);
        }),
        onNext: _next,
        onBack: _back,
        step: 5,
        isLast: true,
      );
      case 6: return _DoneStep(key: const ValueKey('done'));
      default: return const SizedBox.shrink();
    }
  }
}

// ── Intro Step ───────────────────────────────────────────

class _IntroStep extends StatelessWidget {
  final VoidCallback onStart;
  const _IntroStep({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeInSlide(
          delayMs: 0,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AurixTokens.accent, AurixTokens.accent.withValues(alpha: 0.5)],
              ),
              boxShadow: AurixTokens.accentGlowShadow,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 28),
        FadeInSlide(
          delayMs: 100,
          child: Text(
            'Настроим AI под тебя',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeInSlide(
          delayMs: 200,
          child: Text(
            'Расскажи о себе за 30 секунд.\n'
            'AI-продюсер будет знать твой жанр, стиль и цели — '
            'и давать точные советы вместо generic ответов.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeInSlide(
          delayMs: 300,
          child: Wrap(
            spacing: 8, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _featureChip('Персональные советы'),
              _featureChip('Контент под твой стиль'),
              _featureChip('Стратегия роста'),
            ],
          ),
        ),
        const SizedBox(height: 36),
        FadeInSlide(
          delayMs: 400,
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Начать'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeInSlide(
          delayMs: 500,
          child: TextButton(
            onPressed: () => GoRouter.of(context).go('/home'),
            child: Text('Пропустить', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          ),
        ),
      ],
    );
  }

  static Widget _featureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AurixTokens.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
      ),
      child: Text(text, style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}


// ── Multi Select Step ────────────────────────────────────

class _MultiSelectStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> items;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int step;
  final bool isLast;
  final bool canSkip;
  final bool canProceed;

  const _MultiSelectStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    required this.selected,
    required this.onToggle,
    required this.onNext,
    this.onBack,
    required this.step,
    this.isLast = false,
    this.canSkip = true,
    this.canProceed = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canSkip || canProceed;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StepIndicator(current: step, total: 5),
        const SizedBox(height: 32),
        Text(title, style: TextStyle(
          fontFamily: AurixTokens.fontHeading, color: AurixTokens.text,
          fontSize: 24, fontWeight: FontWeight.w800,
        )),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8, runSpacing: 8,
          alignment: WrapAlignment.center,
          children: items.map((item) {
            final isSelected = selected.contains(item);
            return GestureDetector(
              onTap: () => onToggle(item),
              child: AnimatedContainer(
                duration: AurixTokens.dFast,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AurixTokens.accent.withValues(alpha: 0.15) : AurixTokens.surface1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AurixTokens.accent : AurixTokens.stroke(0.15),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(Icons.check_rounded, color: AurixTokens.accent, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(item, style: TextStyle(
                      color: isSelected ? AurixTokens.accent : AurixTokens.text,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            if (onBack != null) ...[
              SizedBox(
                height: 48,
                width: 48,
                child: IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
                  style: IconButton.styleFrom(
                    backgroundColor: AurixTokens.surface1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: _NextButton(
                enabled: enabled,
                onPressed: onNext,
                label: isLast ? 'Готово' : 'Далее',
              ),
            ),
          ],
        ),
        if (canSkip && !isLast) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onNext,
            child: Text('Пропустить', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

// ── Done Step ────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  const _DoneStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeInSlide(
          delayMs: 0,
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AurixTokens.positive.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.check_rounded, color: AurixTokens.positive, size: 40),
          ),
        ),
        const SizedBox(height: 24),
        FadeInSlide(
          delayMs: 100,
          child: Text('AI настроен под тебя', style: TextStyle(
            fontFamily: AurixTokens.fontHeading, color: AurixTokens.text,
            fontSize: 24, fontWeight: FontWeight.w800,
          )),
        ),
        const SizedBox(height: 8),
        FadeInSlide(
          delayMs: 200,
          child: Text(
            'Теперь все советы, контент-идеи и стратегии\nбудут персонализированы под твой стиль',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
          ),
        ),
      ],
    );
  }
}

// ── Shared Widgets ───────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i < current;
        final isCurrent = i == current - 1;
        return Container(
          width: isCurrent ? 24 : 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: isCurrent
                ? AurixTokens.accent
                : active
                    ? AurixTokens.accent.withValues(alpha: 0.3)
                    : AurixTokens.surface2,
          ),
        );
      }),
    );
  }
}

class _NextButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;
  final String label;
  const _NextButton({required this.enabled, required this.onPressed, this.label = 'Далее'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AurixTokens.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AurixTokens.accent.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
