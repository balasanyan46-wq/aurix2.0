import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'creative_model.dart';
import 'creative_service.dart';

/// Floating creative assistant panel — "AI Идеи".
///
/// Shows 3 action buttons, then displays generated suggestion cards.
class CreativePanel extends StatefulWidget {
  final double bpm;
  final int vocalTrackCount;
  final double totalDuration;
  final String? currentLyrics;
  final ValueChanged<String>? onInsert;
  final VoidCallback onClose;

  const CreativePanel({
    super.key,
    required this.bpm,
    required this.vocalTrackCount,
    required this.totalDuration,
    this.currentLyrics,
    this.onInsert,
    required this.onClose,
  });

  @override
  State<CreativePanel> createState() => _CreativePanelState();
}

class _CreativePanelState extends State<CreativePanel>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  CreativeType? _activeType;
  List<CreativeSuggestion> _results = [];

  late AnimationController _entrance;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
    _slideIn = Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _entrance.forward();
  }

  @override
  void dispose() { _entrance.dispose(); super.dispose(); }

  Future<void> _generate(CreativeType type) async {
    setState(() { _loading = true; _activeType = type; _results = []; });

    final ctx = CreativeContext(
      bpm: widget.bpm,
      requestType: type,
      currentLyrics: widget.currentLyrics,
      vocalTrackCount: widget.vocalTrackCount,
      totalDuration: widget.totalDuration,
    );

    final results = await CreativeService.generate(ctx);
    if (mounted) setState(() { _loading = false; _results = results; });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Скопировано'),
        backgroundColor: AurixTokens.positive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (_, child) => FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(position: _slideIn, child: child),
      ),
      child: Container(
        width: 340,
        constraints: const BoxConstraints(maxHeight: 460),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          color: AurixTokens.bg1.withValues(alpha: 0.85),
          border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 32,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AurixTokens.aiAccent.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: -4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildActionButtons(),
                if (_loading) _buildLoader(),
                if (_results.isNotEmpty) _buildResults(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: LinearGradient(
                colors: [
                  AurixTokens.aiAccent.withValues(alpha: 0.2),
                  AurixTokens.aiAccent.withValues(alpha: 0.08),
                ],
              ),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 15, color: AurixTokens.aiGlow),
          ),
          const SizedBox(width: 10),
          Text('AI Идеи', style: TextStyle(
            fontFamily: AurixTokens.fontBody, fontSize: 14,
            fontWeight: FontWeight.w700, color: AurixTokens.text)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onClose,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, size: 16, color: AurixTokens.micro),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(children: [
        _ActionBtn(
          label: 'Придумай хук',
          icon: Icons.bolt_rounded,
          active: _activeType == CreativeType.hook,
          onTap: () => _generate(CreativeType.hook),
        ),
        const SizedBox(width: 6),
        _ActionBtn(
          label: 'Продолжи текст',
          icon: Icons.edit_rounded,
          active: _activeType == CreativeType.line,
          onTap: () => _generate(CreativeType.line),
        ),
        const SizedBox(width: 6),
        _ActionBtn(
          label: 'Что дальше?',
          icon: Icons.lightbulb_outline_rounded,
          active: _activeType == CreativeType.structure,
          onTap: () => _generate(CreativeType.structure),
        ),
      ]),
    );
  }

  Widget _buildLoader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 24, height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AurixTokens.aiAccent.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Text('Генерирую...', style: TextStyle(
            fontFamily: AurixTokens.fontBody, fontSize: 12,
            color: AurixTokens.muted)),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _ResultCard(
          suggestion: _results[i],
          onInsert: () {
            widget.onInsert?.call(_results[i].text);
            setState(() => _results[i].inserted = true);
          },
          onCopy: () => _copy(_results[i].text),
        ),
      ),
    );
  }
}

// ─── Action button ───

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon,
    required this.active, required this.onTap});
  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn>
    with SingleTickerProviderStateMixin {
  late AnimationController _b;
  @override void initState() { super.initState();
    _b = AnimationController(vsync: this, duration: const Duration(milliseconds: 100)); }
  @override void dispose() { _b.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => _b.forward(),
        onTapUp: (_) { _b.reverse(); widget.onTap(); },
        onTapCancel: () => _b.reverse(),
        child: AnimatedBuilder(
          animation: _b,
          builder: (_, c) => Transform.scale(scale: 1 - _b.value * 0.04, child: c),
          child: AnimatedContainer(
            duration: AurixTokens.dFast,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
              color: a ? AurixTokens.aiAccent.withValues(alpha: 0.12)
                     : AurixTokens.surface1.withValues(alpha: 0.4),
              border: Border.all(
                color: a ? AurixTokens.aiAccent.withValues(alpha: 0.35)
                       : AurixTokens.stroke(0.1)),
            ),
            child: Column(children: [
              Icon(widget.icon, size: 18,
                color: a ? AurixTokens.aiAccent : AurixTokens.muted),
              const SizedBox(height: 4),
              Text(widget.label, textAlign: TextAlign.center, style: TextStyle(
                fontFamily: AurixTokens.fontBody, fontSize: 10,
                fontWeight: a ? FontWeight.w700 : FontWeight.w500,
                color: a ? AurixTokens.aiAccent : AurixTokens.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Result card ───

class _ResultCard extends StatefulWidget {
  final CreativeSuggestion suggestion;
  final VoidCallback onInsert;
  final VoidCallback onCopy;
  const _ResultCard({required this.suggestion, required this.onInsert, required this.onCopy});
  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
          color: s.inserted
              ? AurixTokens.positive.withValues(alpha: 0.06)
              : AurixTokens.surface1.withValues(alpha: 0.35),
          border: Border.all(
            color: s.inserted
                ? AurixTokens.positive.withValues(alpha: 0.2)
                : AurixTokens.stroke(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.text, style: TextStyle(
              fontFamily: AurixTokens.fontBody, fontSize: 13,
              fontWeight: FontWeight.w500, color: AurixTokens.text, height: 1.5)),
            const SizedBox(height: 8),
            Row(children: [
              _CardBtn(
                label: s.inserted ? 'Вставлено' : 'Вставить',
                icon: s.inserted ? Icons.check_rounded : Icons.add_rounded,
                color: s.inserted ? AurixTokens.positive : AurixTokens.aiAccent,
                onTap: s.inserted ? null : widget.onInsert,
              ),
              const SizedBox(width: 6),
              _CardBtn(
                label: 'Копировать',
                icon: Icons.copy_rounded,
                color: AurixTokens.muted,
                onTap: widget.onCopy,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _CardBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _CardBtn({required this.label, required this.icon,
    required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withValues(alpha: onTap != null ? 0.1 : 0.05),
          border: Border.all(color: color.withValues(alpha: onTap != null ? 0.25 : 0.1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: color.withValues(alpha: onTap != null ? 1 : 0.5)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontFamily: AurixTokens.fontBody, fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: onTap != null ? 1 : 0.5))),
        ]),
      ),
    );
  }
}
