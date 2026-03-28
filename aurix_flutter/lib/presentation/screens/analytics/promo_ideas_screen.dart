import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

// ── Screen ───────────────────────────────────────────────────

class PromoIdeasScreen extends ConsumerStatefulWidget {
  const PromoIdeasScreen({super.key});

  @override
  ConsumerState<PromoIdeasScreen> createState() => _PromoIdeasScreenState();
}

class _PromoIdeasScreenState extends ConsumerState<PromoIdeasScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;

  List<Map<String, dynamic>> _ideas = [];
  bool _loading = false;
  String? _error;
  String _source = '';

  final _descCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  final _moodCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _descCtrl.dispose();
    _genreCtrl.dispose();
    _moodCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Расскажи о треке — хотя бы пару слов');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final body = <String, dynamic>{'description': _descCtrl.text.trim()};
      if (_genreCtrl.text.trim().isNotEmpty) body['genre'] = _genreCtrl.text.trim();
      if (_moodCtrl.text.trim().isNotEmpty) body['mood'] = _moodCtrl.text.trim();

      final res = await ApiClient.post('/analytics/promo-ideas', data: body);
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _ideas = (data['ideas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _source = data['source']?.toString() ?? 'template';
        _loading = false;
      });
      _entryCtrl.reset();
      _entryCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Не удалось сгенерировать. Попробуй ещё.'; _loading = false; });
    }
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
                  const Text('VIRAL MACHINE', style: TextStyle(
                    color: AurixTokens.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  )),
                  const SizedBox(height: 4),
                  Text('10 идей, каждая может стать той самой', style: TextStyle(
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

          // AI badge + stats
          if (_ideas.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _FadeSlide(controller: _entryCtrl, delay: 0.1, child: _buildResultHeader()),
              ),
            ),

          // Ideas
          if (_ideas.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              sliver: SliverList.builder(
                itemCount: _ideas.length,
                itemBuilder: (ctx, i) => _FadeSlide(
                  controller: _entryCtrl,
                  delay: 0.12 + i * 0.035,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _IdeaCard(idea: _ideas[i], index: i),
                  ),
                ),
              ),
            ),

          // Empty state
          if (_ideas.isEmpty && !_loading)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: _FadeSlide(controller: _entryCtrl, delay: 0.15, child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 56, color: AurixTokens.orange.withValues(alpha: 0.25)),
                    const SizedBox(height: 16),
                    Text(
                      _error ?? 'Опиши трек — AI выдаст 10 идей для промо',
                      style: TextStyle(
                        color: _error != null ? AurixTokens.danger : AurixTokens.muted,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_error == null) ...[
                      const SizedBox(height: 6),
                      Text('Каждая с объяснением почему она работает', style: TextStyle(
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
        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('РАССКАЖИ О ТРЕКЕ', style: TextStyle(
            color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
          )),
          const SizedBox(height: 14),
          _InputField(controller: _descCtrl, hint: 'О чём трек? Что чувствуешь?', icon: Icons.edit_rounded, maxLines: 3),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _InputField(controller: _genreCtrl, hint: 'Жанр', icon: Icons.category_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _InputField(controller: _moodCtrl, hint: 'Вайб / настроение', icon: Icons.mood_rounded)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton(
              onPressed: _loading ? null : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: AurixTokens.orange,
                foregroundColor: AurixTokens.bg0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.bg0))
                  : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Сгенерировать идеи', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader() {
    final avgViral = _ideas.isEmpty ? 0 : _ideas.fold<int>(0, (s, i) => s + ((i['viral_potential'] as num?)?.toInt() ?? 5)) ~/ _ideas.length;
    final easyCount = _ideas.where((i) => i['difficulty'] == 'easy').length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        if (_source == 'ai') ...[
          Icon(Icons.auto_awesome, size: 14, color: AurixTokens.accent.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text('AI', style: TextStyle(color: AurixTokens.accent, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
        ],
        Text('${_ideas.length} идей', style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
        const Spacer(),
        Icon(Icons.whatshot_rounded, size: 14, color: AurixTokens.orange.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text('avg viral: $avgViral/10', style: TextStyle(color: AurixTokens.orange, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Text('$easyCount лёгких', style: TextStyle(color: AurixTokens.positive, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Idea Card ────────────────────────────────────────────────

class _IdeaCard extends StatefulWidget {
  const _IdeaCard({required this.idea, required this.index});
  final Map<String, dynamic> idea;
  final int index;

  @override
  State<_IdeaCard> createState() => _IdeaCardState();
}

class _IdeaCardState extends State<_IdeaCard> {
  bool _expanded = false;

  static const _typeColors = {
    'video': Color(0xFF6C63FF), 'reels': Color(0xFFFF6B35), 'story': Color(0xFF00B4D8),
    'post': Color(0xFF06D6A0), 'collab': Color(0xFFFFBE0B), 'challenge': Color(0xFFE040FB),
  };
  static const _typeIcons = {
    'video': Icons.videocam_rounded, 'reels': Icons.slow_motion_video_rounded, 'story': Icons.amp_stories_rounded,
    'post': Icons.article_rounded, 'collab': Icons.handshake_rounded, 'challenge': Icons.local_fire_department_rounded,
  };
  static const _diffLabels = {'easy': 'Легко', 'medium': 'Средне', 'hard': 'Сложно'};
  static const _diffColors = {'easy': AurixTokens.positive, 'medium': Color(0xFFFFBE0B), 'hard': AurixTokens.danger};

  @override
  Widget build(BuildContext context) {
    final idea = widget.idea;
    final title = idea['title']?.toString() ?? '';
    final desc = idea['description']?.toString() ?? '';
    final type = idea['type']?.toString() ?? 'video';
    final hook = idea['hook']?.toString() ?? '';
    final difficulty = idea['difficulty']?.toString() ?? 'medium';
    final viralPotential = (idea['viral_potential'] as num?)?.toInt() ?? 5;
    final whyItWorks = idea['why_it_works']?.toString() ?? '';
    final color = _typeColors[type] ?? AurixTokens.accent;
    final icon = _typeIcons[type] ?? Icons.lightbulb_rounded;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: _expanded ? 0.35 : 0.12)),
          boxShadow: [if (_expanded) BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: -2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Row(children: [
                    _Badge(text: type.toUpperCase(), color: color),
                    const SizedBox(width: 6),
                    _Badge(text: _diffLabels[difficulty] ?? difficulty, color: _diffColors[difficulty] ?? AurixTokens.muted),
                  ]),
                ],
              )),
              // Viral meter
              _ViralMeter(score: viralPotential),
            ]),

            // Expanded
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hook
                    if (hook.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withValues(alpha: 0.12)),
                        ),
                        child: Row(children: [
                          Icon(Icons.format_quote_rounded, size: 16, color: color.withValues(alpha: 0.6)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(hook, style: TextStyle(
                            color: color, fontSize: 13, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic,
                          ))),
                        ]),
                      ),

                    // Description
                    Text(desc, style: TextStyle(
                      color: AurixTokens.muted.withValues(alpha: 0.85), fontSize: 13, height: 1.5,
                    )),

                    // WHY IT WORKS
                    if (whyItWorks.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AurixTokens.accent.withValues(alpha: 0.06), AurixTokens.orange.withValues(alpha: 0.03)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.psychology_rounded, size: 14, color: AurixTokens.accent.withValues(alpha: 0.7)),
                              const SizedBox(width: 6),
                              Text('ПОЧЕМУ ЭТО РАБОТАЕТ', style: TextStyle(
                                color: AurixTokens.accent.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8,
                              )),
                            ]),
                            const SizedBox(height: 8),
                            Text(whyItWorks, style: TextStyle(
                              color: AurixTokens.text.withValues(alpha: 0.85), fontSize: 12, height: 1.4, fontWeight: FontWeight.w500,
                            )),
                          ],
                        ),
                      ),
                    ],

                    // Action buttons
                    const SizedBox(height: 14),
                    Row(children: [
                      _ActionChip(
                        label: 'Сделать это',
                        icon: Icons.check_circle_outline_rounded,
                        color: AurixTokens.positive,
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        label: 'В план релиза',
                        icon: Icons.add_circle_outline_rounded,
                        color: AurixTokens.accent,
                      ),
                    ]),
                  ],
                ),
              ),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),

            // Expand indicator
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18, color: AurixTokens.muted.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Viral Meter ──────────────────────────────────────────────

class _ViralMeter extends StatelessWidget {
  const _ViralMeter({required this.score});
  final int score;

  Color get _color {
    if (score >= 8) return const Color(0xFFFF6B35);
    if (score >= 6) return AurixTokens.orange;
    if (score >= 4) return const Color(0xFFFFBE0B);
    return AurixTokens.muted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text('$score', style: TextStyle(color: _color, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 1),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.whatshot_rounded, size: 10, color: _color.withValues(alpha: 0.7)),
            const SizedBox(width: 2),
            Text('viral', style: TextStyle(color: _color.withValues(alpha: 0.7), fontSize: 8, fontWeight: FontWeight.w700)),
          ]),
        ],
      ),
    );
  }
}

// ── Shared Widgets ───────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({required this.controller, required this.hint, required this.icon, this.maxLines = 1});
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, size: 18, color: AurixTokens.muted.withValues(alpha: 0.5)),
        filled: true, fillColor: AurixTokens.bg0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5))),
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
