import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

class NavigatorArticleReasonBlock extends StatelessWidget {
  const NavigatorArticleReasonBlock({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'Контекст',
              style: TextStyle(
                color: AurixTokens.orange,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Почему это важно сейчас',
            style: TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
