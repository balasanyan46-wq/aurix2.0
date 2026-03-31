import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/ai/ai_service.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/artist_provider.dart';
import 'models/ai_character.dart';
import 'models/ai_session.dart';
import 'models/artist_profile.dart';
import 'widgets/ai_response_card.dart';
import 'track_analysis_screen.dart';

const _pipelineOrder = ['producer', 'writer', 'visual', 'smm'];

class CharacterScreen extends ConsumerStatefulWidget {
  final AiCharacter character;
  final AiSession? session;

  const CharacterScreen({super.key, required this.character, this.session});

  @override
  ConsumerState<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends ConsumerState<CharacterScreen> {
  final _ctrl = TextEditingController();
  late final AiSession _session;
  bool _loading = false;
  String? _result;
  String? _error;
  String? _lastQuery;

  AiCharacter get _c => widget.character;
  int get _stepIndex => _pipelineOrder.indexOf(_c.id).clamp(0, 3);
  bool get _hasContext => _session.contextFor(_c.id).isNotEmpty;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? AiSession();

    // If we have pipeline context, auto-generate
    if (_hasContext) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generateFromPipeline());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _generateFromPipeline() async {
    final context = _session.contextFor(_c.id);
    _generate(overrideMessage: context);
  }

  /// Build personalized system prompt with artist context.
  String _buildPrompt(String userMsg) {
    final profile = ref.read(artistProfileProvider);
    final memory = ref.read(aiMemoryProvider);
    final parts = <String>[_c.systemPrompt];

    // Inject artist identity
    if (!profile.isEmpty) {
      parts.add('---\n\nТы работаешь с артистом:\n${profile.toAiContext()}');
      parts.add('Адаптируй ответ под ЕГО стиль, жанр и цели. Это персональный результат.');
    }

    // Inject memory context
    final memCtx = memory.toAiContext(limit: 3);
    if (memCtx.isNotEmpty) {
      parts.add('---\n\n$memCtx');
    }

    parts.add('---\n\n$userMsg');
    return parts.join('\n\n');
  }

  Future<void> _generate({String? overrideMessage}) async {
    final msg = overrideMessage ?? _ctrl.text.trim();
    if (msg.isEmpty || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _lastQuery = msg;
    });
    if (overrideMessage == null) _ctrl.clear();

    try {
      final fullMessage = _buildPrompt(msg);

      final reply = await AiService.send(
        message: fullMessage,
        history: const [],
        mode: 'chat',
        locale: 'ru',
      );

      if (!mounted) return;
      _session.saveResult(_c.id, reply);

      // Save to memory + award XP
      final ideaText = overrideMessage ?? _lastQuery ?? msg;
      ref.read(aiMemoryProvider.notifier).addEntry(_c.id, ideaText, reply);
      final xpAction = XpAction.fromCharacter(_c.id);
      if (xpAction != null) {
        ref.read(artistProfileProvider.notifier).awardXp(xpAction);
      } else {
        ref.read(artistProfileProvider.notifier).incrementSessions();
      }

      setState(() {
        _result = reply;
        _loading = false;
      });
    } on AiServiceException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Ошибка соединения'; _loading = false; });
    }
  }

  /// Combine all pipeline results for analysis.
  String _buildPipelineContent() {
    final parts = <String>[];
    if (_session.producerResult != null) parts.add('КОНЦЕПЦИЯ:\n${_session.producerResult}');
    if (_session.writerResult != null) parts.add('ТЕКСТ:\n${_session.writerResult}');
    if (_session.visualResult != null) parts.add('ВИЗУАЛ:\n${_session.visualResult}');
    if (_session.smmResult != null) parts.add('КОНТЕНТ:\n${_session.smmResult}');
    return parts.join('\n\n---\n\n');
  }

  void _refine() {
    if (_lastQuery == null) return;
    _generate(overrideMessage: '$_lastQuery\n\nДоработай предыдущий результат. Сделай сильнее, конкретнее, без воды.');
  }

  void _reset() {
    setState(() { _result = null; _error = null; _lastQuery = null; });
  }

  void _goToNext() {
    final nextIdx = _stepIndex + 1;
    if (nextIdx >= _pipelineOrder.length) {
      // Pipeline complete → bonus XP → auto-analyze
      ref.read(artistProfileProvider.notifier).awardPipelineBonus();

      // Build pipeline content for analysis
      final analysisContent = _buildPipelineContent();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => TrackAnalysisScreen(pipelineContent: analysisContent, session: _session),
        ),
      );
      return;
    }

    final nextId = _pipelineOrder[nextIdx];
    final nextChar = aiCharacters.firstWhere((c) => c.id == nextId);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CharacterScreen(character: nextChar, session: _session),
      ),
    );
  }

  /// Show bottom sheet to transfer chat context to another specialist.
  void _showTransferSheet() {
    final others = aiCharacters.where((c) => c.id != _c.id).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AurixTokens.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Передать другому специалисту',
                style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Контекст текущего разговора будет передан',
                style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              for (final c in others) ...[
                _TransferOption(
                  character: c,
                  onTap: () {
                    Navigator.of(ctx).pop();
                    // Save current result into session, then navigate
                    if (_result != null) {
                      _session.saveResult(_c.id, _result!);
                    }
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => CharacterScreen(character: c, session: _session),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: _c.accent.withValues(alpha: 0.15)),
            child: Icon(_c.icon, size: 15, color: _c.accent),
          ),
          const SizedBox(width: 10),
          Text(_c.name, style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.swap_horiz_rounded, color: AurixTokens.muted.withValues(alpha: 0.7)),
            tooltip: 'Передать другому',
            onPressed: _showTransferSheet,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(children: [
            // Pipeline progress bar
            _PipelineBar(currentStep: _stepIndex, session: _session),

            Expanded(
              child: _result != null
                  ? _buildResult()
                  : _loading
                      ? _buildLoading()
                      : _buildInput(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _c.accent.withValues(alpha: 0.18),
              _c.accent.withValues(alpha: 0.04),
            ]),
            boxShadow: [BoxShadow(color: _c.accent.withValues(alpha: 0.1), blurRadius: 32, spreadRadius: -8)],
          ),
          child: Icon(_c.icon, size: 36, color: _c.accent),
        ),
        const SizedBox(height: 16),
        Text(_c.role, textAlign: TextAlign.center, style: TextStyle(color: _c.accent.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 24),
        TextField(
          controller: _ctrl,
          maxLines: 4, minLines: 2,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: _c.placeholder,
            hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.45)),
            filled: true,
            fillColor: AurixTokens.glass(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AurixTokens.stroke(0.12))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _c.accent.withValues(alpha: 0.4))),
            contentPadding: const EdgeInsets.all(16),
          ),
          onSubmitted: (_) => _generate(),
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
            ),
            child: Text(_error!, style: TextStyle(color: AurixTokens.danger.withValues(alpha: 0.9), fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _generate,
            icon: Icon(_c.icon, size: 20),
            label: const Text('Создать', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: _c.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AurixTokens.glass(0.1),
              disabledForegroundColor: AurixTokens.muted.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildLoading() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: _c.accent, strokeWidth: 3)),
      const SizedBox(height: 20),
      Text('${_c.name} работает...', style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Подождите несколько секунд', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 13)),
    ]);
  }

  Widget _buildResult() {
    final isLast = _stepIndex >= _pipelineOrder.length - 1;
    final nextIdx = _stepIndex + 1;
    final nextChar = !isLast ? aiCharacters.firstWhere((c) => c.id == _pipelineOrder[nextIdx]) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        AiResponseCard(content: _result!, accent: _c.accent, characterName: _c.name),
        const SizedBox(height: 20),

        // Action buttons
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _loading ? null : _refine,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Доработать'),
              style: FilledButton.styleFrom(
                backgroundColor: _c.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _reset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Заново'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AurixTokens.text,
                side: BorderSide(color: AurixTokens.stroke(0.15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Transfer to another specialist
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showTransferSheet,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Передать другому специалисту'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AurixTokens.aiAccent,
              side: BorderSide(color: AurixTokens.aiAccent.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Next step button
        _NextStepButton(
          isLast: isLast,
          nextCharacter: nextChar,
          onTap: _goToNext,
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Pipeline Progress Bar
// ══════════════════════════════════════════════════════════════

class _PipelineBar extends StatelessWidget {
  final int currentStep;
  final AiSession session;

  const _PipelineBar({required this.currentStep, required this.session});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.08))),
      ),
      child: Row(
        children: List.generate(aiCharacters.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepBefore = i ~/ 2;
            final done = stepBefore < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: done
                      ? aiCharacters[stepBefore].accent.withValues(alpha: 0.5)
                      : AurixTokens.stroke(0.12),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }

          final stepIdx = i ~/ 2;
          final c = aiCharacters[stepIdx];
          final isCurrent = stepIdx == currentStep;
          final isDone = stepIdx < currentStep;

          return _PipelineStep(
            character: c,
            isCurrent: isCurrent,
            isDone: isDone,
          );
        }),
      ),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final AiCharacter character;
  final bool isCurrent;
  final bool isDone;

  const _PipelineStep({
    required this.character,
    required this.isCurrent,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = isCurrent ? 1.0 : isDone ? 0.7 : 0.25;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCurrent
              ? character.accent.withValues(alpha: 0.2)
              : isDone
                  ? character.accent.withValues(alpha: 0.1)
                  : AurixTokens.glass(0.06),
          border: Border.all(
            color: character.accent.withValues(alpha: isCurrent ? 0.5 : isDone ? 0.3 : 0.08),
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: isCurrent
              ? [BoxShadow(color: character.accent.withValues(alpha: 0.15), blurRadius: 16, spreadRadius: -4)]
              : null,
        ),
        child: isDone
            ? Icon(Icons.check_rounded, size: 16, color: character.accent.withValues(alpha: 0.8))
            : Icon(character.icon, size: 16, color: character.accent.withValues(alpha: alpha)),
      ),
      const SizedBox(height: 4),
      Text(
        character.name,
        style: TextStyle(
          color: isCurrent
              ? character.accent
              : AurixTokens.muted.withValues(alpha: alpha),
          fontSize: 10,
          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Next Step Button
// ══════════════════════════════════════════════════════════════

class _NextStepButton extends StatefulWidget {
  final bool isLast;
  final AiCharacter? nextCharacter;
  final VoidCallback onTap;

  const _NextStepButton({required this.isLast, this.nextCharacter, required this.onTap});

  @override
  State<_NextStepButton> createState() => _NextStepButtonState();
}

class _NextStepButtonState extends State<_NextStepButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isLast
        ? AurixTokens.accent
        : widget.nextCharacter!.accent;

    final label = widget.isLast
        ? 'Отправить в Промо'
        : 'Передать → ${widget.nextCharacter!.name}';

    final icon = widget.isLast
        ? Icons.rocket_launch_rounded
        : widget.nextCharacter!.icon;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: _hovered ? 0.18 : 0.1),
                    accent.withValues(alpha: _hovered ? 0.08 : 0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: _hovered ? 0.4 : 0.2)),
                boxShadow: _hovered
                    ? [BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 24, spreadRadius: -6)]
                    : null,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  label,
                  style: TextStyle(color: accent, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 20, color: accent),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Transfer Option (bottom sheet item)
// ══════════════════════════════════════════════════════════════

class _TransferOption extends StatelessWidget {
  final AiCharacter character;
  final VoidCallback onTap;

  const _TransferOption({required this.character, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: character.accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: character.accent.withValues(alpha: 0.12)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: character.accent.withValues(alpha: 0.12),
            ),
            child: Icon(character.icon, size: 20, color: character.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                character.name,
                style: const TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                character.role,
                style: TextStyle(color: character.accent.withValues(alpha: 0.7), fontSize: 12),
              ),
            ]),
          ),
          Icon(Icons.arrow_forward_rounded, size: 18, color: character.accent.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }
}
