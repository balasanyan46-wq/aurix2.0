import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/presentation/providers/artist_provider.dart';
import 'models/artist_profile.dart';

/// Artist career screen — XP, level, goal, today's actions, AI recommendation.
/// Also serves as the profile editor (no onboarding gate).
class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(artistProfileProvider);
    final memory = ref.watch(aiMemoryProvider);

    // If empty profile — show inline edit form
    if (profile.isEmpty) {
      return _InlineProfileEditor(onSave: (p) async {
        await ref.read(artistProfileProvider.notifier).save(p);
        _syncToBackend(p);
      });
    }

    final level = profile.level;
    final todayActions = profile.todayActions;
    final recentIdeas = memory.recentIdeas;

    return PremiumPageScaffold(
      title: profile.name,
      subtitle: 'Карьера артиста',
      children: [
        // XP + Level hero
        _XpHero(profile: profile),
        const SizedBox(height: 20),

        // Goal
        _GoalCard(profile: profile, onEdit: () => _editGoal(context, ref, profile)),
        const SizedBox(height: 20),

        // AI Recommendation — next step
        _NextStepCard(nextStep: profile.getNextStep()),
        const SizedBox(height: 20),

        // Today's actions
        _TodayCard(actions: todayActions, todayXp: profile.todayXp),
        const SizedBox(height: 20),

        // Style card (editable)
        _StyleCard(profile: profile),
        const SizedBox(height: 20),

        // AI comment
        _AiComment(level: level, xp: profile.xp),
        const SizedBox(height: 20),

        // Recent ideas
        if (recentIdeas.isNotEmpty) ...[
          _RecentIdeas(ideas: recentIdeas),
          const SizedBox(height: 20),
        ],

        // Actions
        Row(children: [
          Expanded(child: _ActionCard(
            icon: Icons.auto_awesome,
            label: 'Studio AI',
            accent: AurixTokens.aiAccent,
            onTap: () => context.go('/ai'),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ActionCard(
            icon: Icons.rocket_launch_rounded,
            label: 'Промо',
            accent: AurixTokens.accent,
            onTap: () => context.go('/promo'),
          )),
          const SizedBox(width: 12),
          Expanded(child: _ActionCard(
            icon: Icons.edit_rounded,
            label: 'Изменить',
            accent: AurixTokens.muted,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _InlineProfileEditor(
                  initial: profile,
                  onSave: (p) async {
                    await ref.read(artistProfileProvider.notifier).save(p);
                    _syncToBackend(p);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          )),
        ]),
      ],
    );
  }

  /// Fire-and-forget sync to backend (for server-side AI context).
  static void _syncToBackend(ArtistProfile p) {
    ApiClient.post('/api/ai/profile', data: {
      'name': p.name,
      'genre': p.genre,
      'mood': p.mood,
      'references_list': p.references,
      'goals': p.goals,
      'style_description': p.styleDescription,
    }).ignore();
  }

  void _editGoal(BuildContext context, WidgetRef ref, ArtistProfile profile) {
    final ctrl = TextEditingController(text: profile.goal);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Твоя цель', style: TextStyle(color: AurixTokens.text)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: AurixTokens.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Например: выпустить EP к лету',
            hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.45)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(artistProfileProvider.notifier).setGoal(ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.accent, foregroundColor: Colors.white),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// XP Hero — animated level + progress
// ══════════════════════════════════════════════════════════════

class _XpHero extends StatelessWidget {
  final ArtistProfile profile;

  const _XpHero({required this.profile});

  @override
  Widget build(BuildContext context) {
    final level = profile.level;
    final accent = _levelColor(level);
    final nextLevel = profile.nextLevel;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: 0.12), AurixTokens.bg2.withValues(alpha: 0.3)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 32, spreadRadius: -12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Level badge with glow
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [accent.withValues(alpha: 0.3), accent.withValues(alpha: 0.06)]),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 24, spreadRadius: -8)],
            ),
            child: Center(child: Text(level.emoji, style: const TextStyle(fontSize: 26))),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(level.label, style: TextStyle(color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${profile.xp} XP', style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.9), fontSize: 14, fontWeight: FontWeight.w600)),
          ])),
          // Today's XP badge
          if (profile.todayXp > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AurixTokens.positive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.25)),
              ),
              child: Text(
                '+${profile.todayXp} сегодня',
                style: TextStyle(color: AurixTokens.positive, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
        ]),
        if (nextLevel != null) ...[
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: profile.levelProgress),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, value, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: AurixTokens.glass(0.08),
                    color: accent,
                    minHeight: 8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${profile.xp}/${nextLevel.minXp} → ${nextLevel.label}',
              style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ]),
        ],
      ]),
    );
  }

  Color _levelColor(ArtistLevel l) => switch (l) {
    ArtistLevel.beginner => AurixTokens.muted,
    ArtistLevel.growing => AurixTokens.positive,
    ArtistLevel.breakthrough => AurixTokens.accent,
    ArtistLevel.artist => AurixTokens.aiAccent,
  };
}

// ══════════════════════════════════════════════════════════════
// Goal Card
// ══════════════════════════════════════════════════════════════

class _GoalCard extends StatelessWidget {
  final ArtistProfile profile;
  final VoidCallback onEdit;

  const _GoalCard({required this.profile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasGoal = profile.goal.isNotEmpty;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AurixTokens.accent.withValues(alpha: 0.06), Colors.transparent],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Icon(Icons.flag_rounded, size: 22, color: AurixTokens.accent.withValues(alpha: 0.8)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hasGoal ? 'Твоя цель' : 'Поставь цель',
                style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                hasGoal ? profile.goal : 'Нажми, чтобы задать направление',
                style: TextStyle(
                  color: hasGoal ? AurixTokens.text : AurixTokens.muted.withValues(alpha: 0.6),
                  fontSize: 15,
                  fontWeight: hasGoal ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ]),
          ),
          Icon(Icons.edit_rounded, size: 16, color: AurixTokens.muted.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI Recommendation — Next Step (highlighted)
// ══════════════════════════════════════════════════════════════

class _NextStepCard extends StatefulWidget {
  final String nextStep;

  const _NextStepCard({required this.nextStep});

  @override
  State<_NextStepCard> createState() => _NextStepCardState();
}

class _NextStepCardState extends State<_NextStepCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final glow = 0.06 + _ctrl.value * 0.06;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AurixTokens.aiAccent.withValues(alpha: glow), AurixTokens.aiAccent.withValues(alpha: 0.02)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.2 + _ctrl.value * 0.1)),
            boxShadow: [BoxShadow(color: AurixTokens.aiAccent.withValues(alpha: 0.05 + _ctrl.value * 0.05), blurRadius: 24, spreadRadius: -8)],
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
              child: Icon(Icons.auto_awesome_rounded, size: 18, color: AurixTokens.aiAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Следующий шаг', style: TextStyle(color: AurixTokens.aiAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  widget.nextStep,
                  style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
            Icon(Icons.arrow_forward_rounded, size: 18, color: AurixTokens.aiAccent.withValues(alpha: 0.6)),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Today's actions
// ══════════════════════════════════════════════════════════════

class _TodayCard extends StatelessWidget {
  final List<CompletedAction> actions;
  final int todayXp;

  const _TodayCard({required this.actions, required this.todayXp});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Сегодня', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (todayXp > 0) Text('+$todayXp XP', style: TextStyle(color: AurixTokens.positive, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        if (actions.isEmpty)
          Text('Пока ничего. Начни с рекомендации выше.', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 14))
        else
          ...actions.reversed.take(8).map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AurixTokens.positive.withValues(alpha: 0.1),
                ),
                child: Icon(Icons.check_rounded, size: 14, color: AurixTokens.positive),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(a.label, style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.8), fontSize: 14))),
              Text('+${a.xp}', style: TextStyle(color: AurixTokens.positive.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Style Card
// ══════════════════════════════════════════════════════════════

class _StyleCard extends StatelessWidget {
  final ArtistProfile profile;

  const _StyleCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Твой стиль', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        _InfoRow(label: 'Жанр', value: profile.genre),
        if (profile.mood.isNotEmpty) _InfoRow(label: 'Настроение', value: profile.mood),
        if (profile.references.isNotEmpty) _InfoRow(label: 'Референсы', value: profile.references.join(', ')),
        if (profile.goals.isNotEmpty) _InfoRow(label: 'Цели', value: profile.goals.join(', ')),
        if (profile.styleDescription.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            profile.styleDescription,
            style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.8), fontSize: 14, height: 1.4, fontStyle: FontStyle.italic),
          ),
        ],
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 13, fontWeight: FontWeight.w600))),
        Expanded(child: Text(value, style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.9), fontSize: 14))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI Comment
// ══════════════════════════════════════════════════════════════

class _AiComment extends StatelessWidget {
  final ArtistLevel level;
  final int xp;

  const _AiComment({required this.level, required this.xp});

  String get _comment {
    if (xp == 0) return 'Добро пожаловать. Давай создадим что-то.';
    return switch (level) {
      ArtistLevel.beginner => 'Ты начинаешь формировать свой стиль. Каждое действие — шаг вперёд.',
      ArtistLevel.growing => 'Ты растёшь. AI уже видит паттерны в твоём стиле. Продолжай.',
      ArtistLevel.breakthrough => 'Серьёзный прогресс. Ты на пороге прорыва — не останавливайся.',
      ArtistLevel.artist => 'Ты — артист. AI полностью синхронизирован с твоим стилем.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AurixTokens.aiAccent.withValues(alpha: 0.06), Colors.transparent]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
          child: Icon(Icons.auto_awesome_rounded, size: 16, color: AurixTokens.aiAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(_comment, style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.85), fontSize: 14, height: 1.4, fontStyle: FontStyle.italic)),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Recent Ideas
// ══════════════════════════════════════════════════════════════

class _RecentIdeas extends StatelessWidget {
  final List<String> ideas;

  const _RecentIdeas({required this.ideas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Последние идеи', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...ideas.take(5).map((idea) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: AurixTokens.accent.withValues(alpha: 0.5))),
            const SizedBox(width: 10),
            Expanded(child: Text(idea, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.75), fontSize: 14))),
          ]),
        )),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Action Card
// ══════════════════════════════════════════════════════════════

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.accent, required this.onTap});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: _hovered ? widget.accent.withValues(alpha: 0.08) : AurixTokens.glass(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _hovered ? widget.accent.withValues(alpha: 0.3) : AurixTokens.stroke(0.1)),
          ),
          child: Column(children: [
            Icon(widget.icon, size: 24, color: widget.accent),
            const SizedBox(height: 8),
            Text(widget.label, style: TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Inline Profile Editor — replaces the old onboarding screen.
// Used both for first-time setup and editing existing profile.
// ══════════════════════════════════════════════════════════════

class _InlineProfileEditor extends StatefulWidget {
  final ArtistProfile? initial;
  final Future<void> Function(ArtistProfile) onSave;

  const _InlineProfileEditor({this.initial, required this.onSave});

  @override
  State<_InlineProfileEditor> createState() => _InlineProfileEditorState();
}

class _InlineProfileEditorState extends State<_InlineProfileEditor> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _styleCtrl;
  String? _genre;
  String? _mood;
  final _refs = <String>{};
  final _goals = <String>{};
  bool _saving = false;

  static const _genres = [
    'Хип-хоп', 'Рэп', 'Поп', 'R&B', 'Рок', 'Электро',
    'Инди', 'Трэп', 'Дрилл', 'Фонк', 'Альтернатива', 'Другое',
  ];
  static const _moods = [
    'Агрессивный', 'Меланхоличный', 'Энергичный', 'Романтичный',
    'Тёмный', 'Лёгкий', 'Философский', 'Дерзкий',
  ];
  static const _refsList = [
    'Miyagi', 'Travis Scott', 'Скриптонит', 'Oxxxymiron',
    'Playboi Carti', 'The Weeknd', 'Билли Айлиш', 'PHARAOH',
    'Drake', 'Kanye West', 'Markul', 'Lil Uzi Vert',
    'Макс Корж', 'Моргенштерн', 'XXXTentacion', 'Другой',
  ];
  static const _goalsList = [
    'Популярность', 'Деньги', 'Концерты', 'Свой стиль',
    'Признание', 'Сообщество', 'Фит с кумиром', 'Лейбл',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _styleCtrl = TextEditingController(text: p?.styleDescription ?? '');
    _genre = p?.genre.isNotEmpty == true ? p!.genre : null;
    _mood = p?.mood.isNotEmpty == true ? p!.mood : null;
    if (p != null) {
      _refs.addAll(p.references);
      _goals.addAll(p.goals);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _styleCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty && _genre != null;

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);

    final existing = widget.initial ?? ArtistProfile();
    final profile = ArtistProfile(
      name: _nameCtrl.text.trim(),
      genre: _genre ?? '',
      mood: _mood ?? '',
      references: _refs.toList(),
      goals: _goals.toList(),
      styleDescription: _styleCtrl.text.trim(),
      // Preserve XP and other data from existing profile
      xp: existing.xp,
      sessionsCount: existing.sessionsCount,
      completedActions: existing.completedActions,
      goal: existing.goal,
      createdAt: existing.createdAt,
    );

    await widget.onSave(profile);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initial != null;
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: isEditing
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Редактировать профиль', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
              centerTitle: true,
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (!isEditing) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Настроить AI-профиль',
                    style: TextStyle(color: AurixTokens.text, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Расскажи о себе — AI будет давать персональные советы',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 28),
                ],

                // Name
                _label('Имя артиста *'),
                const SizedBox(height: 8),
                _field(_nameCtrl, 'Как тебя зовут'),
                const SizedBox(height: 20),

                // Genre
                _label('Жанр *'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _genres.map((g) =>
                  _chip(g, _genre == g, () => setState(() => _genre = g)),
                ).toList()),
                const SizedBox(height: 20),

                // Mood
                _label('Настроение'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _moods.map((m) =>
                  _chip(m, _mood == m, () => setState(() => _mood = m)),
                ).toList()),
                const SizedBox(height: 20),

                // References
                _label('Кто вдохновляет'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _refsList.map((r) =>
                  _chip(r, _refs.contains(r), () => setState(() {
                    _refs.contains(r) ? _refs.remove(r) : _refs.add(r);
                  })),
                ).toList()),
                const SizedBox(height: 20),

                // Goals
                _label('Цели'),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _goalsList.map((g) =>
                  _chip(g, _goals.contains(g), () => setState(() {
                    _goals.contains(g) ? _goals.remove(g) : _goals.add(g);
                  })),
                ).toList()),
                const SizedBox(height: 20),

                // Style description
                _label('Опиши свой стиль (необязательно)'),
                const SizedBox(height: 8),
                _field(_styleCtrl, 'В 1-2 предложениях', maxLines: 3),
                const SizedBox(height: 28),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canSave && !_saving ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AurixTokens.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AurixTokens.glass(0.1),
                      disabledForegroundColor: AurixTokens.muted.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            isEditing ? 'Сохранить' : 'Готово',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),

                if (!isEditing) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Пропустить', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
  );

  Widget _field(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    onChanged: (_) => setState(() {}),
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

  Widget _chip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AurixTokens.accent.withValues(alpha: 0.15) : AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? AurixTokens.accent.withValues(alpha: 0.5) : AurixTokens.stroke(0.1)),
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
