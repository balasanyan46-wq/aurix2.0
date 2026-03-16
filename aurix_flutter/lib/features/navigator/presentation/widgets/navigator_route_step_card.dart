import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_reveal.dart';

class NavigatorRouteStepCard extends StatefulWidget {
  const NavigatorRouteStepCard({
    super.key,
    required this.step,
    required this.onAction,
    this.revealDelay = Duration.zero,
  });

  final NavigatorRouteStep step;
  final VoidCallback onAction;
  final Duration revealDelay;

  @override
  State<NavigatorRouteStepCard> createState() => _NavigatorRouteStepCardState();
}

class _NavigatorRouteStepCardState extends State<NavigatorRouteStepCard> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final step = widget.step;
    final isCurrent = step.status == NavigatorRouteStepStatus.inProgress;
    final isDone = step.status == NavigatorRouteStepStatus.done;
    final statusText = isDone
        ? 'завершено'
        : (isCurrent ? 'в процессе' : 'не начато');

    return NavigatorReveal(
      delay: widget.revealDelay,
      child: MouseRegion(
        onEnter: (_) {
          if (!isDesktop) return;
          setState(() => _hover = true);
        },
        onExit: (_) {
          if (!isDesktop) return;
          setState(() {
            _hover = false;
            _pressed = false;
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (_) {
            if (!isDesktop) return;
            setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (!isDesktop) return;
            setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (!isDesktop) return;
            setState(() => _pressed = false);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: Matrix4.identity()
              ..translateByDouble(0.0, _hover ? -2.0 : 0.0, 0.0, 1.0)
              ..scaleByDouble(_pressed ? 0.995 : 1.0, _pressed ? 0.995 : 1.0, 1.0, 1.0),
            child: AurixGlassCard(
            radius: 16,
            padding: EdgeInsets.all(
              isDesktop ? 16 : 13,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isCurrent)
                  Container(
                    width: 4,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AurixTokens.orange.withValues(alpha: 0.9),
                          AurixTokens.orange.withValues(alpha: 0.1),
                        ],
                      ),
                    ),
                  ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isDone
                        ? AurixTokens.positive.withValues(alpha: 0.18)
                        : (isCurrent
                            ? AurixTokens.orange.withValues(alpha: 0.2)
                            : AurixTokens.glass(0.08)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${step.index}',
                    style: TextStyle(
                      color: isDone ? AurixTokens.positive : AurixTokens.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              step.title,
                              style: TextStyle(
                                color: isCurrent
                                    ? AurixTokens.text
                                    : AurixTokens.textSecondary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _pill(
                            statusText,
                            isDone ? AurixTokens.positive : AurixTokens.orange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.description,
                        style: const TextStyle(
                          color: AurixTokens.textSecondary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Почему: ${step.whyRecommended}',
                        style:
                            const TextStyle(color: AurixTokens.muted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill('~${step.etaMinutes} мин', AurixTokens.textSecondary),
                          FilledButton.icon(
                            onPressed: widget.onAction,
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: Text(
                              isDone ? 'Открыть' : (isCurrent ? 'Продолжить' : 'Начать'),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
