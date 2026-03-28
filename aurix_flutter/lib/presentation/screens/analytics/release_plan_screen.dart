import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

// ── State ────────────────────────────────────────────────────

class _PlanState {
  final List<Map<String, dynamic>> plan;
  final String source;
  final String releaseDate;
  final Map<String, dynamic>? goal;
  final Set<int> completed;

  const _PlanState({
    this.plan = const [],
    this.source = '',
    this.releaseDate = '',
    this.goal,
    this.completed = const {},
  });

  _PlanState copyWith({
    List<Map<String, dynamic>>? plan,
    String? source,
    String? releaseDate,
    Map<String, dynamic>? goal,
    Set<int>? completed,
  }) => _PlanState(
    plan: plan ?? this.plan,
    source: source ?? this.source,
    releaseDate: releaseDate ?? this.releaseDate,
    goal: goal ?? this.goal,
    completed: completed ?? this.completed,
  );
}

// ── Screen ───────────────────────────────────────────────────

class ReleasePlanScreen extends ConsumerStatefulWidget {
  const ReleasePlanScreen({super.key});

  @override
  ConsumerState<ReleasePlanScreen> createState() => _ReleasePlanScreenState();
}

class _ReleasePlanScreenState extends ConsumerState<ReleasePlanScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;

  _PlanState _state = const _PlanState();
  bool _loading = false;
  String? _error;

  final _titleCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  int _days = 14;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _titleCtrl.dispose();
    _genreCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final body = <String, dynamic>{'days': _days};
      if (_titleCtrl.text.trim().isNotEmpty) body['track_title'] = _titleCtrl.text.trim();
      if (_genreCtrl.text.trim().isNotEmpty) body['genre'] = _genreCtrl.text.trim();

      final res = await ApiClient.post('/analytics/release-plan', data: body);
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _state = _PlanState(
          plan: (data['plan'] as List?)?.cast<Map<String, dynamic>>() ?? [],
          source: data['source']?.toString() ?? 'template',
          releaseDate: data['release_date']?.toString() ?? '',
          goal: data['goal'] as Map<String, dynamic>?,
          completed: {},
        );
        _loading = false;
      });
      _entryCtrl.reset();
      _entryCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Не удалось сгенерировать. Попробуй ещё раз.'; _loading = false; });
    }
  }

  void _toggleComplete(int day) {
    final set = Set<int>.from(_state.completed);
    set.contains(day) ? set.remove(day) : set.add(day);
    setState(() => _state = _state.copyWith(completed: set));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: _FadeSlide(controller: _entryCtrl, delay: 0, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ПЛАН АТАКИ', style: TextStyle(
                    color: AurixTokens.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  )),
                  const SizedBox(height: 4),
                  Text('Пошаговая стратегия, которая приведёт к результату', style: TextStyle(
                    color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 13,
                  )),
                ],
              )),
            ),
          ),

          // Form
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _FadeSlide(controller: _entryCtrl, delay: 0.05, child: _buildForm()),
            ),
          ),

          // ── GOAL CARD ───────────────────────────────────────
          if (_state.goal != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _FadeSlide(controller: _entryCtrl, delay: 0.08, child: _GoalCard(goal: _state.goal!)),
              ),
            ),

          // ── MILESTONES ──────────────────────────────────────
          if (_state.goal != null && _state.plan.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _FadeSlide(controller: _entryCtrl, delay: 0.1, child: _MilestoneBar(
                  milestones: ((_state.goal!['milestones'] as List?) ?? []).cast<Map<String, dynamic>>(),
                  totalDays: _days,
                  completed: _state.completed,
                  planDays: _state.plan.map((p) => p['day'] as int? ?? 0).toSet(),
                )),
              ),
            ),

          // ── PROGRESS ────────────────────────────────────────
          if (_state.plan.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _FadeSlide(controller: _entryCtrl, delay: 0.12, child: _buildProgress()),
              ),
            ),

          // ── TIMELINE ────────────────────────────────────────
          if (_state.plan.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              sliver: SliverList.builder(
                itemCount: _state.plan.length,
                itemBuilder: (ctx, i) {
                  final item = _state.plan[i];
                  final day = item['day'] as int? ?? (i + 1);
                  return _FadeSlide(
                    controller: _entryCtrl,
                    delay: 0.15 + i * 0.035,
                    child: _DayCard(
                      item: item, day: day,
                      isCompleted: _state.completed.contains(day),
                      isLast: i == _state.plan.length - 1,
                      onToggle: () => _toggleComplete(day),
                    ),
                  );
                },
              ),
            ),

          // Empty state
          if (_state.plan.isEmpty && !_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: _FadeSlide(controller: _entryCtrl, delay: 0.15, child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.rocket_launch_rounded, size: 56, color: AurixTokens.accent.withValues(alpha: 0.25)),
                    const SizedBox(height: 16),
                    Text(
                      _error ?? 'Укажи трек — AI построит стратегию запуска',
                      style: TextStyle(
                        color: _error != null ? AurixTokens.danger : AurixTokens.muted,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_error == null) ...[
                      const SizedBox(height: 6),
                      Text('Каждый день = конкретное действие', style: TextStyle(
                        color: AurixTokens.muted.withValues(alpha: 0.4), fontSize: 12,
                      )),
                    ],
                  ],
                )),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ЧТО ЗАПУСКАЕМ?', style: TextStyle(
            color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
          )),
          const SizedBox(height: 14),
          _InputField(controller: _titleCtrl, hint: 'Название трека', icon: Icons.music_note_rounded),
          const SizedBox(height: 10),
          _InputField(controller: _genreCtrl, hint: 'Жанр', icon: Icons.category_rounded),
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.timer_rounded, size: 16, color: AurixTokens.muted.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            const Text('Дней на промо:', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
            const Spacer(),
            for (final d in [7, 14, 21])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _DayChip(label: '$d', selected: _days == d, onTap: () => setState(() => _days = d)),
              ),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: AurixTokens.bg0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.bg0))
                  : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      SizedBox(width: 8),
                      Text('Построить план', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final total = _state.plan.length;
    final done = _state.completed.length;
    final pct = total > 0 ? done / total : 0.0;
    final highDone = _state.plan.where((p) => p['priority'] == 'high' && _state.completed.contains(p['day'] as int? ?? 0)).length;
    final highTotal = _state.plan.where((p) => p['priority'] == 'high').length;

    String statusText;
    Color statusColor;
    if (pct == 0) {
      statusText = 'Готов к старту? Жми на карточки чтобы отмечать выполненные';
      statusColor = AurixTokens.muted;
    } else if (pct < 0.5) {
      statusText = 'Набираешь обороты! Фокус на HIGH-приоритетах';
      statusColor = AurixTokens.orange;
    } else if (pct < 1) {
      statusText = 'Финишная прямая — осталось ${total - done} шагов!';
      statusColor = AurixTokens.accent;
    } else {
      statusText = 'План выполнен! Ты сделал это 🔥';
      statusColor = AurixTokens.positive;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.06), blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$done / $total выполнено', style: const TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('${(pct * 100).round()}%', style: TextStyle(color: statusColor, fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 8,
              backgroundColor: AurixTokens.bg0,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 10),
          Text(statusText, style: TextStyle(color: statusColor.withValues(alpha: 0.7), fontSize: 12)),
          if (highTotal > 0) ...[
            const SizedBox(height: 6),
            Text('HIGH-приоритеты: $highDone / $highTotal', style: TextStyle(
              color: AurixTokens.danger.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600,
            )),
          ],
          if (_state.source == 'ai')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Icon(Icons.auto_awesome, size: 12, color: AurixTokens.accent.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text('Сгенерировано AI', style: TextStyle(color: AurixTokens.accent.withValues(alpha: 0.5), fontSize: 10)),
              ]),
            ),
        ],
      ),
    );
  }
}

// ── Goal Card ────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final Map<String, dynamic> goal;

  @override
  Widget build(BuildContext context) {
    final title = goal['title']?.toString() ?? '';
    final desc = goal['description']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AurixTokens.accent.withValues(alpha: 0.08), AurixTokens.orange.withValues(alpha: 0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🎯', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Text('ЦЕЛЬ', style: TextStyle(color: AurixTokens.accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(desc, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.7), fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

// ── Milestone Bar ────────────────────────────────────────────

class _MilestoneBar extends StatelessWidget {
  const _MilestoneBar({required this.milestones, required this.totalDays, required this.completed, required this.planDays});
  final List<Map<String, dynamic>> milestones;
  final int totalDays;
  final Set<int> completed;
  final Set<int> planDays;

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: milestones.map((m) {
          final day = m['at_day'] as int? ?? 1;
          final label = m['label']?.toString() ?? '';
          final emoji = m['emoji']?.toString() ?? '📌';
          final reached = completed.any((c) => c >= day);

          return Column(
            children: [
              Text(emoji, style: TextStyle(fontSize: 16, color: reached ? null : AurixTokens.muted.withValues(alpha: 0.4))),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(
                color: reached ? AurixTokens.text : AurixTokens.muted.withValues(alpha: 0.5),
                fontSize: 9, fontWeight: FontWeight.w600,
              )),
              Text('День $day', style: TextStyle(
                color: AurixTokens.muted.withValues(alpha: 0.3), fontSize: 8,
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Day Card ─────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.item, required this.day,
    required this.isCompleted, required this.isLast,
    required this.onToggle,
  });
  final Map<String, dynamic> item;
  final int day;
  final bool isCompleted, isLast;
  final VoidCallback onToggle;

  static const _typeColors = {
    'content': Color(0xFF6C63FF),
    'social': Color(0xFF00B4D8),
    'release': Color(0xFFFF6B35),
    'engage': Color(0xFFFFBE0B),
    'analytics': Color(0xFF06D6A0),
  };
  static const _typeIcons = {
    'content': Icons.videocam_rounded,
    'social': Icons.share_rounded,
    'release': Icons.rocket_launch_rounded,
    'engage': Icons.people_rounded,
    'analytics': Icons.insights_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? '';
    final desc = item['description']?.toString() ?? '';
    final type = item['type']?.toString() ?? 'content';
    final priority = item['priority']?.toString() ?? 'medium';
    final why = item['why']?.toString() ?? '';
    final color = _typeColors[type] ?? AurixTokens.accent;
    final icon = _typeIcons[type] ?? Icons.check_circle_outline_rounded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline
            SizedBox(
              width: 40,
              child: Column(children: [
                GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: isCompleted ? AurixTokens.positive : color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted ? AurixTokens.positive : color.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check_rounded, size: 18, color: AurixTokens.bg0)
                          : Text('$day', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
                if (!isLast) Expanded(child: Container(
                  width: 2,
                  color: isCompleted ? AurixTokens.positive.withValues(alpha: 0.3) : AurixTokens.border,
                )),
              ]),
            ),
            const SizedBox(width: 8),
            // Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: onToggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCompleted ? AurixTokens.positive.withValues(alpha: 0.05) : AurixTokens.bg1,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isCompleted ? AurixTokens.positive.withValues(alpha: 0.25) : color.withValues(alpha: 0.12)),
                      boxShadow: [if (!isCompleted) BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 16, spreadRadius: -2)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(icon, size: 16, color: isCompleted ? AurixTokens.positive : color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(title, style: TextStyle(
                            color: isCompleted ? AurixTokens.muted : AurixTokens.text,
                            fontSize: 14, fontWeight: FontWeight.w600,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ))),
                          if (priority == 'high') Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                            child: const Text('HIGH', style: TextStyle(color: AurixTokens.danger, fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                        if (desc.isNotEmpty && !isCompleted) ...[
                          const SizedBox(height: 8),
                          Text(desc, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.75), fontSize: 12, height: 1.4)),
                        ],
                        // WHY block
                        if (why.isNotEmpty && !isCompleted) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: color.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('💡 ', style: TextStyle(fontSize: 11)),
                                Expanded(child: Text(why, style: TextStyle(
                                  color: color.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w500, height: 1.3,
                                ))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(children: [
                          _TypeTag(type: type, color: color),
                          const Spacer(),
                          Text(
                            isCompleted ? '✅ Сделано' : 'Нажми когда сделаешь',
                            style: TextStyle(
                              color: isCompleted ? AurixTokens.positive : AurixTokens.muted.withValues(alpha: 0.35),
                              fontSize: 10, fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Widgets ───────────────────────────────────────────

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.type, required this.color});
  final String type;
  final Color color;
  static const _labels = {'content': 'Контент', 'social': 'Соцсети', 'release': 'Релиз', 'engage': 'Вовлечение', 'analytics': 'Аналитика'};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(_labels[type] ?? type, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({required this.controller, required this.hint, required this.icon});
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, size: 18, color: AurixTokens.muted.withValues(alpha: 0.5)),
        filled: true, fillColor: AurixTokens.bg0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.5))),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.accent.withValues(alpha: 0.15) : AurixTokens.bg0,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? AurixTokens.accent : AurixTokens.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? AurixTokens.accent : AurixTokens.muted,
          fontSize: 13, fontWeight: FontWeight.w600,
        )),
      ),
    );
  }
}

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.controller, required this.delay, required this.child});
  final AnimationController controller;
  final double delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(delay.clamp(0, 0.9), (delay + 0.3).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, __) => Opacity(
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - curved.value)), child: child),
      ),
    );
  }
}
