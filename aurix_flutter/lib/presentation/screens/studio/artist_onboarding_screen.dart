import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/artist_provider.dart';
import 'models/artist_profile.dart';

/// Multi-step onboarding: genre → mood → refs → goals → name.
class ArtistOnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onDone;

  const ArtistOnboardingScreen({super.key, required this.onDone});

  @override
  ConsumerState<ArtistOnboardingScreen> createState() => _ArtistOnboardingState();
}

class _ArtistOnboardingState extends ConsumerState<ArtistOnboardingScreen> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _styleCtrl = TextEditingController();

  String? _selectedGenre;
  String? _selectedMood;
  final _selectedRefs = <String>{};
  final _selectedGoals = <String>{};

  static const _genres = [
    'Хип-хоп', 'Рэп', 'Поп', 'R&B', 'Рок', 'Электро',
    'Инди', 'Трэп', 'Дрилл', 'Фонк', 'Альтернатива', 'Другое',
  ];

  static const _moods = [
    'Агрессивный', 'Меланхоличный', 'Энергичный', 'Романтичный',
    'Тёмный', 'Лёгкий', 'Философский', 'Дерзкий',
  ];

  static const _refs = [
    'Miyagi', 'Travis Scott', 'Скриптонит', 'Oxxxymiron',
    'Playboi Carti', 'The Weeknd', 'Билли Айлиш', 'PHARAOH',
    'Drake', 'Kanye West', 'Markul', 'Lil Uzi Vert',
    'Макс Корж', 'Моргенштерн', 'XXXTentacion', 'Другой',
  ];

  static const _goals = [
    'Популярность', 'Деньги', 'Концерты', 'Свой стиль',
    'Признание', 'Сообщество', 'Фит с кумиром', 'Лейбл',
  ];

  int get _totalSteps => 4;

  void _next() {
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  bool get _canProceed {
    switch (_step) {
      case 0: return _selectedGenre != null;
      case 1: return _selectedRefs.isNotEmpty;
      case 2: return _selectedGoals.isNotEmpty;
      case 3: return _nameCtrl.text.trim().isNotEmpty;
      default: return false;
    }
  }

  Future<void> _save() async {
    final profile = ArtistProfile(
      name: _nameCtrl.text.trim(),
      genre: _selectedGenre ?? '',
      mood: _selectedMood ?? '',
      references: _selectedRefs.toList(),
      goals: _selectedGoals.toList(),
      styleDescription: _styleCtrl.text.trim(),
    );
    await ref.read(artistProfileProvider.notifier).save(profile);
    widget.onDone();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _styleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Header — only on first step
                  if (_step == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AurixTokens.accent.withValues(alpha: 0.15),
                          AurixTokens.accent.withValues(alpha: 0.03),
                        ]),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 32, color: AurixTokens.accent),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Progress
                  _ProgressBar(current: _step, total: _totalSteps),
                  const SizedBox(height: 28),

                  // Content
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildStep(),
                    ),
                  ),

                  // Navigation
                  const SizedBox(height: 24),
                  Row(children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _back,
                        child: Text('Назад', style: TextStyle(color: AurixTokens.muted)),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _canProceed ? _next : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AurixTokens.accent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AurixTokens.glass(0.1),
                        disabledForegroundColor: AurixTokens.muted.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        _step == _totalSteps - 1 ? 'Запустить AURIX' : 'Далее',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _StepGenre(
        key: const ValueKey('genre'),
        selectedGenre: _selectedGenre,
        selectedMood: _selectedMood,
        genres: _genres,
        moods: _moods,
        onGenre: (g) => setState(() => _selectedGenre = g),
        onMood: (m) => setState(() => _selectedMood = m),
      );
      case 1: return _StepRefs(
        key: const ValueKey('refs'),
        refs: _refs,
        selected: _selectedRefs,
        onToggle: (r) => setState(() {
          _selectedRefs.contains(r) ? _selectedRefs.remove(r) : _selectedRefs.add(r);
        }),
      );
      case 2: return _StepGoals(
        key: const ValueKey('goals'),
        goals: _goals,
        selected: _selectedGoals,
        onToggle: (g) => setState(() {
          _selectedGoals.contains(g) ? _selectedGoals.remove(g) : _selectedGoals.add(g);
        }),
      );
      case 3: return _StepName(
        key: const ValueKey('name'),
        nameCtrl: _nameCtrl,
        styleCtrl: _styleCtrl,
        onChanged: () => setState(() {}),
      );
      default: return const SizedBox.shrink();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Steps
// ══════════════════════════════════════════════════════════════

class _StepGenre extends StatelessWidget {
  final String? selectedGenre;
  final String? selectedMood;
  final List<String> genres;
  final List<String> moods;
  final ValueChanged<String> onGenre;
  final ValueChanged<String> onMood;

  const _StepGenre({
    super.key,
    required this.selectedGenre,
    required this.selectedMood,
    required this.genres,
    required this.moods,
    required this.onGenre,
    required this.onMood,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepTitle(
          title: 'Настроим AURIX под тебя',
          subtitle: 'Чтобы анализ треков и советы были точными — расскажи о своей музыке',
        ),
        const SizedBox(height: 24),
        Text('Жанр', style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: genres.map((g) =>
          _Chip(label: g, selected: selectedGenre == g, onTap: () => onGenre(g)),
        ).toList()),
        const SizedBox(height: 24),
        Text('Настроение', style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: moods.map((m) =>
          _Chip(label: m, selected: selectedMood == m, onTap: () => onMood(m)),
        ).toList()),
      ]),
    );
  }
}

class _StepRefs extends StatelessWidget {
  final List<String> refs;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _StepRefs({super.key, required this.refs, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepTitle(
          title: 'Кто вдохновляет?',
          subtitle: 'Мы учтём стиль референсов при анализе твоих треков',
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: refs.map((r) =>
          _Chip(label: r, selected: selected.contains(r), onTap: () => onToggle(r)),
        ).toList()),
      ]),
    );
  }
}

class _StepGoals extends StatelessWidget {
  final List<String> goals;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _StepGoals({super.key, required this.goals, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepTitle(
          title: 'Что для тебя важно?',
          subtitle: 'AURIX будет давать рекомендации с учётом твоих целей',
        ),
        const SizedBox(height: 20),
        Wrap(spacing: 8, runSpacing: 8, children: goals.map((g) =>
          _Chip(label: g, selected: selected.contains(g), onTap: () => onToggle(g)),
        ).toList()),
      ]),
    );
  }
}

class _StepName extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController styleCtrl;
  final VoidCallback onChanged;

  const _StepName({super.key, required this.nameCtrl, required this.styleCtrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepTitle(
          title: 'Последний шаг',
          subtitle: 'Имя артиста и описание — чтобы AI знал, кто ты',
        ),
        const SizedBox(height: 20),
        _Field(controller: nameCtrl, hint: 'Имя артиста', onChanged: onChanged),
        const SizedBox(height: 16),
        _Field(controller: styleCtrl, hint: 'Опиши свой стиль в 1-2 предложениях (необязательно)', maxLines: 3, onChanged: onChanged),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AurixTokens.accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.1)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 18, color: AurixTokens.accent.withValues(alpha: 0.6)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Это можно изменить позже в настройках профиля',
                style: TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.4),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Shared widgets
// ══════════════════════════════════════════════════════════════

class _StepTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StepTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      const SizedBox(height: 8),
      Text(subtitle, style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.4)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.accent.withValues(alpha: 0.15) : AurixTokens.glass(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AurixTokens.accent.withValues(alpha: 0.5) : AurixTokens.stroke(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AurixTokens.accent : AurixTokens.text.withValues(alpha: 0.8),
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final VoidCallback onChanged;

  const _Field({required this.controller, required this.hint, this.maxLines = 1, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      onChanged: (_) => onChanged(),
      style: const TextStyle(color: AurixTokens.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.45)),
        filled: true,
        fillColor: AurixTokens.glass(0.06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AurixTokens.stroke(0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.4))),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        final done = i < current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: active
                    ? AurixTokens.accent
                    : done
                        ? AurixTokens.accent.withValues(alpha: 0.4)
                        : AurixTokens.glass(0.1),
              ),
            ),
          ),
        );
      }),
    );
  }
}
