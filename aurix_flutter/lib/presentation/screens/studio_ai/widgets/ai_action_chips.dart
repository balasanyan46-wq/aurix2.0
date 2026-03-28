import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Data for a single action chip.
class AiAction {
  final String label;
  final IconData icon;
  final String prompt;
  final String? mode;

  const AiAction({
    required this.label,
    required this.icon,
    required this.prompt,
    this.mode,
  });
}

/// Default quick actions shown after AI responses.
const kDefaultActions = [
  AiAction(label: 'DNK', icon: Icons.fingerprint_rounded, prompt: 'Проанализируй мою аудиторию и дай стратегию', mode: 'dnk'),
  AiAction(label: 'Reels', icon: Icons.videocam_rounded, prompt: 'Придумай идеи для Reels на основе этого', mode: 'reels'),
  AiAction(label: 'Текст', icon: Icons.edit_note_rounded, prompt: 'Напиши текст песни на основе этого', mode: 'lyrics'),
  AiAction(label: 'Идеи', icon: Icons.lightbulb_rounded, prompt: 'Придумай 10 идей на основе этого', mode: 'ideas'),
  AiAction(label: 'Усилить', icon: Icons.bolt_rounded, prompt: 'Усиль это — сделай мощнее и конкретнее', mode: null),
];

/// Parses follow_up block from AI response.
class AiFollowUp {
  final String? question;
  final List<String> actions;

  const AiFollowUp({this.question, this.actions = const []});

  static AiFollowUp? parse(String content) {
    final idx = content.indexOf('---follow_up---');
    if (idx == -1) return null;

    final block = content.substring(idx + 15).trim();
    String? question;
    List<String> actions = [];

    for (final line in block.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('question:')) {
        question = trimmed.substring(9).trim();
      } else if (trimmed.startsWith('actions:')) {
        actions = trimmed
            .substring(8)
            .split('|')
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
      }
    }

    if (question == null && actions.isEmpty) return null;
    return AiFollowUp(question: question, actions: actions);
  }

  /// Remove the follow_up block from content for display.
  static String stripFollowUp(String content) {
    final idx = content.indexOf('---follow_up---');
    if (idx == -1) return content;
    return content.substring(0, idx).trim();
  }
}

/// Horizontal scrolling action chips with glow.
class AiActionChips extends StatelessWidget {
  final List<AiAction>? actions;
  final AiFollowUp? followUp;
  final void Function(String prompt, String? mode) onAction;

  const AiActionChips({
    super.key,
    this.actions,
    this.followUp,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    // Build chip list from follow-up actions or defaults
    final List<Widget> chips = [];

    // AI follow-up question
    if (followUp?.question != null && followUp!.question!.isNotEmpty) {
      chips.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            followUp!.question!,
            style: TextStyle(
              color: AurixTokens.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    // Dynamic actions from AI
    if (followUp != null && followUp!.actions.isNotEmpty) {
      chips.add(
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: followUp!.actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final action = followUp!.actions[i];
              return _ActionChip(
                label: action,
                icon: _guessIcon(action),
                onTap: () => onAction(action, null),
              );
            },
          ),
        ),
      );
    } else {
      // Default action chips
      final defaultActions = actions ?? kDefaultActions;
      chips.add(
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: defaultActions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final a = defaultActions[i];
              return _ActionChip(
                label: a.label,
                icon: a.icon,
                onTap: () => onAction(a.prompt, a.mode),
              );
            },
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: chips,
      ),
    );
  }

  IconData _guessIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('reels') || lower.contains('видео')) return Icons.videocam_rounded;
    if (lower.contains('текст') || lower.contains('написать')) return Icons.edit_note_rounded;
    if (lower.contains('идеи') || lower.contains('придумать')) return Icons.lightbulb_rounded;
    if (lower.contains('аудитори') || lower.contains('dnk') || lower.contains('анализ')) return Icons.fingerprint_rounded;
    if (lower.contains('усилить') || lower.contains('мощн')) return Icons.bolt_rounded;
    if (lower.contains('хук') || lower.contains('припев')) return Icons.music_note_rounded;
    if (lower.contains('продвиж') || lower.contains('стратег')) return Icons.rocket_launch_rounded;
    return Icons.auto_awesome_rounded;
  }
}

class _ActionChip extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_ActionChip> createState() => _ActionChipState();
}

class _ActionChipState extends State<_ActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AurixTokens.accent.withValues(alpha: 0.12),
                AurixTokens.accentWarm.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AurixTokens.accent.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: AurixTokens.accentGlow.withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: AurixTokens.accent),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: AurixTokens.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
