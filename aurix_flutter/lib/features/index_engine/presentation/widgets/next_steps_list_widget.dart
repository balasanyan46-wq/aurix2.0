import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/next_step.dart';

class NextStepsListWidget extends StatelessWidget {
  final NextStepPlan plan;
  final bool expanded;

  const NextStepsListWidget({super.key, required this.plan, this.expanded = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'СЛЕДУЮЩИЙ ШАГ',
          style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
        ),
        if (plan.forecast != null) ...[
          const SizedBox(height: 8),
          Text(
            plan.forecast!,
            style: TextStyle(color: AurixTokens.accent, fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 16),
        ...plan.steps.asMap().entries.map((e) {
          final step = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _NextStepCard(step: step, index: e.key + 1),
          );
        }),
      ],
    );
  }
}

class _NextStepCard extends StatelessWidget {
  final NextStep step;
  final int index;

  const _NextStepCard({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.12),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w700, fontSize: 13, fontFeatures: AurixTokens.tabularFigures),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
