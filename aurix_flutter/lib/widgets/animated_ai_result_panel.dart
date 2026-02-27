import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class AnimatedAiResultPanel extends StatefulWidget {
  const AnimatedAiResultPanel({
    super.key,
    required this.isLoading,
    required this.errorText,
    required this.markdownText,
    required this.onCopy,
    required this.onClear,
    required this.onRetry,
    this.enableTypewriter = true,
    this.enableStaggerSections = true,
    this.showHeader = true,
    this.motivations,
  });

  final bool isLoading;
  final String? errorText;
  final String? markdownText;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  final VoidCallback onRetry;
  final bool enableTypewriter;
  final bool enableStaggerSections;
  final bool showHeader;
  final List<String>? motivations;

  @override
  State<AnimatedAiResultPanel> createState() => _AnimatedAiResultPanelState();
}

class _AnimatedAiResultPanelState extends State<AnimatedAiResultPanel> with TickerProviderStateMixin {
  static const _revealDuration = Duration(milliseconds: 340);
  static const _revealCurve = Curves.easeOutCubic;

  // Typewriter: chunked, max duration capped.
  static const _typeTick = Duration(milliseconds: 20); // 16–25ms target
  static const _minChunk = 10;
  static const _maxChunk = 20;
  static const _maxTypeDuration = Duration(milliseconds: 3200); // 2.5–4s target

  Timer? _typeTimer;
  Timer? _hardStopTimer;
  String _typed = '';
  bool _typing = false;
  bool _showSections = false;

  late final AnimationController _sectionsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  Timer? _doneToastTimer;
  bool _showDone = false;

  Timer? _motTimer;
  int _motIndex = 0;

  @override
  void initState() {
    super.initState();
    _syncToInput(prevText: null, nextText: widget.markdownText);
  }

  @override
  void didUpdateWidget(covariant AnimatedAiResultPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdownText != widget.markdownText || oldWidget.isLoading != widget.isLoading) {
      _syncToInput(prevText: oldWidget.markdownText, nextText: widget.markdownText);
    }
  }

  void _syncToInput({required String? prevText, required String? nextText}) {
    // Loading: keep any existing reveal, but stop typewriter.
    if (widget.isLoading) {
      _stopTypewriter(showAll: true);
      _setDoneToast(false);
      _startMotivationTicker();
      return;
    }
    _stopMotivationTicker();

    // New successful answer.
    if (nextText != null && nextText.isNotEmpty && nextText != prevText) {
      _startReveal(nextText);
      _setDoneToast(true);
      return;
    }

    // Cleared.
    if ((nextText == null || nextText.isEmpty) && (prevText != null && prevText.isNotEmpty)) {
      _stopTypewriter(showAll: true);
      _showSections = false;
      _setDoneToast(false);
    }
  }

  void _setDoneToast(bool on) {
    _doneToastTimer?.cancel();
    if (!on) {
      if (mounted) setState(() => _showDone = false);
      return;
    }
    if (mounted) setState(() => _showDone = true);
    _doneToastTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showDone = false);
    });
  }

  void _startReveal(String fullText) {
    _stopTypewriter(showAll: true);
    _sectionsCtrl.stop();
    _sectionsCtrl.value = 0;

    if (widget.enableTypewriter) {
      _typed = '';
      _typing = true;
      _showSections = false;
      _startTypewriter(fullText);
    } else {
      _typed = fullText;
      _typing = false;
      _showSections = true;
      _sectionsCtrl.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  void _startTypewriter(String fullText) {
    final total = fullText.length;
    if (total == 0) {
      _stopTypewriter(showAll: true);
      return;
    }

    final maxTicks = (_maxTypeDuration.inMilliseconds / _typeTick.inMilliseconds).floor().clamp(1, 5000);
    final idealChunk = (total / maxTicks).ceil();
    final chunk = idealChunk.clamp(_minChunk, _maxChunk);

    _typeTimer?.cancel();
    _hardStopTimer?.cancel();
    _hardStopTimer = Timer(_maxTypeDuration, () {
      _stopTypewriter(showAll: true);
    });

    _typeTimer = Timer.periodic(_typeTick, (_) {
      if (!mounted) return;
      if (!_typing) return;
      final cur = _typed.length;
      if (cur >= total) {
        _stopTypewriter(showAll: true);
        return;
      }
      final next = (cur + chunk).clamp(0, total);
      setState(() {
        _typed = fullText.substring(0, next);
      });
    });
  }

  void _stopTypewriter({required bool showAll}) {
    _typeTimer?.cancel();
    _hardStopTimer?.cancel();
    _typeTimer = null;
    _hardStopTimer = null;

    final full = widget.markdownText ?? '';
    if (showAll) _typed = full;
    final wasTyping = _typing;
    _typing = false;

    if (wasTyping && full.isNotEmpty) {
      _showSections = true;
      _sectionsCtrl.forward(from: 0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _typeTimer?.cancel();
    _hardStopTimer?.cancel();
    _doneToastTimer?.cancel();
    _stopMotivationTicker();
    _sectionsCtrl.dispose();
    super.dispose();
  }

  void _startMotivationTicker() {
    final list = widget.motivations;
    if (list == null || list.isEmpty) return;
    _motTimer?.cancel();
    _motTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() => _motIndex = (_motIndex + 1) % list.length);
    });
  }

  void _stopMotivationTicker() {
    _motTimer?.cancel();
    _motTimer = null;
    _motIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.markdownText != null && widget.markdownText!.trim().isNotEmpty;
    final copyEnabled = hasText && !widget.isLoading;
    final clearEnabled = (hasText || widget.errorText != null) && !widget.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.isLoading) ...[
          _TopStatusPill(text: 'Генерируем…'),
          if (widget.motivations != null && widget.motivations!.isNotEmpty) ...[
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Text(
                widget.motivations![_motIndex],
                key: ValueKey('mot_$_motIndex'),
                style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _AiSkeletonCard(),
        ] else if (widget.errorText != null) ...[
          _TopStatusPill(text: 'Ошибка'),
          const SizedBox(height: 10),
          _ErrorCard(
            errorText: widget.errorText!,
            onRetry: widget.onRetry,
          ),
        ] else if (hasText) ...[
          if (widget.showHeader) ...[
            Row(
              children: [
                Text('AI-результат', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _showDone ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Text('Готово', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _RevealContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: copyEnabled ? widget.onCopy : null,
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Скопировать'),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: clearEnabled ? widget.onClear : null,
                      child: const Text('Очистить'),
                    ),
                    const Spacer(),
                    if (_typing)
                      TextButton(
                        onPressed: () => _stopTypewriter(showAll: true),
                        child: const Text('Показать сразу'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: _showSections && widget.enableStaggerSections
                      ? _SectionsView(
                          key: const ValueKey('sections'),
                          markdown: widget.markdownText!,
                          ctrl: _sectionsCtrl,
                        )
                      : _RawMarkdownView(
                          key: const ValueKey('raw'),
                          markdown: _plain(_typed),
                          dim: _typing,
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TopStatusPill extends StatelessWidget {
  const _TopStatusPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AurixTokens.stroke(0.14)),
        ),
        child: Text(text, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _RevealContainer extends StatelessWidget {
  const _RevealContainer({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _AnimatedAiResultPanelState._revealDuration,
      curve: _AnimatedAiResultPanelState._revealCurve,
      builder: (context, t, child) {
        final dy = (1 - t) * 10; // 8–12px target
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurixTokens.stroke(0.12)),
        ),
        child: child,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.errorText, required this.onRetry});
  final String errorText;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            errorText,
            style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Повторить'),
              style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _RawMarkdownView extends StatelessWidget {
  const _RawMarkdownView({super.key, required this.markdown, required this.dim});
  final String markdown;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      markdown,
      style: TextStyle(
        color: dim ? AurixTokens.text.withValues(alpha: 0.92) : AurixTokens.text,
        fontSize: 13.5,
        height: 1.45,
      ),
    );
  }
}

class _SectionsView extends StatelessWidget {
  const _SectionsView({super.key, required this.markdown, required this.ctrl});
  final String markdown;
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    final sections = _splitMarkdownSections(markdown);
    final n = sections.length;
    final staggerMs = 120;
    final totalMs = 280 + (n - 1).clamp(0, 99) * staggerMs;

    if (ctrl.duration == null || ctrl.duration!.inMilliseconds != totalMs) {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      ctrl.duration = Duration(milliseconds: totalMs.clamp(280, 1200));
    }
    if (!ctrl.isAnimating && ctrl.value == 0) {
      ctrl.forward();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < n; i++) ...[
          _StaggerSection(
            index: i,
            count: n,
            ctrl: ctrl,
            child: _SectionCard(section: sections[i]),
          ),
          if (i != n - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StaggerSection extends StatelessWidget {
  const _StaggerSection({
    required this.index,
    required this.count,
    required this.ctrl,
    required this.child,
  });

  final int index;
  final int count;
  final AnimationController ctrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.12).clamp(0.0, 0.92);
    final end = (start + 0.36).clamp(0.0, 1.0);
    final anim = CurvedAnimation(parent: ctrl, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final t = anim.value;
        final dy = (1 - t) * 10;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}

typedef _MdSection = ({String? title, String body});

List<_MdSection> _splitMarkdownSections(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  final sections = <String>[];
  final buf = StringBuffer();

  bool isHeading(String l) => l.startsWith('## ') || l.startsWith('### ');

  for (final line in lines) {
    if (isHeading(line) && buf.isNotEmpty) {
      sections.add(buf.toString().trim());
      buf.clear();
    }
    buf.writeln(line);
  }
  final last = buf.toString().trim();
  if (last.isNotEmpty) sections.add(last);

  final raw = sections.isEmpty ? [markdown.trim()] : sections;
  return raw.where((s) => s.trim().isNotEmpty).map(_parseSection).toList();
}

_MdSection _parseSection(String section) {
  final lines = section.split('\n');
  if (lines.isEmpty) return (title: null, body: section);
  final first = lines.first.trimRight();
  final isH = first.startsWith('## ') || first.startsWith('### ');
  if (!isH) return (title: null, body: section.trim());
  final title = first.replaceFirst('### ', '').replaceFirst('## ', '').trim();
  final body = lines.skip(1).join('\n').trim();
  return (title: title.isEmpty ? null : title, body: body);
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});
  final _MdSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title != null) ...[
            Text(
              section.title!,
              style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 8),
          ],
          SelectableText(
            section.body.isEmpty ? '—' : _plain(section.body),
            style: const TextStyle(color: AurixTokens.text, fontSize: 13.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

String _plain(String text) {
  // Lightweight markdown-to-plain cleanup to avoid showing "##", "**", backticks, etc.
  var t = text.replaceAll('\r\n', '\n');
  // headings
  t = t.replaceAll(RegExp(r'^\s*#{2,3}\s+', multiLine: true), '');
  // bold/italic
  t = t.replaceAll('**', '').replaceAll('__', '').replaceAll('*', '').replaceAll('_', '');
  // inline code
  t = t.replaceAll('`', '');
  // blockquote
  t = t.replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '');
  // checkboxes
  t = t.replaceAll(RegExp(r'^\s*-\s*\[[ xX]\]\s+', multiLine: true), '• ');
  // bullets
  t = t.replaceAll(RegExp(r'^\s*-\s+', multiLine: true), '• ');
  // trim repeated blank lines
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return t.trim();
}

class _AiSkeletonCard extends StatefulWidget {
  const _AiSkeletonCard();

  @override
  State<_AiSkeletonCard> createState() => _AiSkeletonCardState();
}

class _AiSkeletonCardState extends State<_AiSkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return _Shimmer(
            t: _c.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skLine(0.86),
                const SizedBox(height: 10),
                _skLine(0.92),
                const SizedBox(height: 10),
                _skLine(0.70),
                const SizedBox(height: 18),
                _skLine(0.78),
                const SizedBox(height: 10),
                _skLine(0.96),
                const SizedBox(height: 10),
                _skLine(0.62),
                const SizedBox(height: 18),
                _skLine(0.84),
                const SizedBox(height: 10),
                _skLine(0.74),
                const SizedBox(height: 10),
                _skLine(0.90),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _skLine(double w) {
    return FractionallySizedBox(
      widthFactor: w,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.10),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.t, required this.child});
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Lightweight shimmer: moving gradient in ShaderMask.
    final dx = (t * 2 - 1) * 1.6; // -1.6..+1.6
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(
          begin: Alignment(-1 + dx, 0),
          end: Alignment(1 + dx, 0),
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const [0.35, 0.5, 0.65],
        ).createShader(rect);
      },
      blendMode: BlendMode.srcATop,
      child: child,
    );
  }
}

Future<void> defaultCopyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано')));
}

