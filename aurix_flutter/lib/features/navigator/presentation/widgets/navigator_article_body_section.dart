import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorArticleBodySection extends StatelessWidget {
  const NavigatorArticleBodySection({super.key, required this.block});

  final NavigatorBodyBlock block;

  @override
  Widget build(BuildContext context) {
    final kind = block.kind;
    final isMistakes = kind == 'mistakes';
    final isActions = kind == 'action_steps';
    final isKeyPoints = kind == 'key_points';
    final tint = isMistakes
        ? const Color(0xFFFF8A8A)
        : (isActions ? AurixTokens.orange : AurixTokens.textSecondary);
    return AurixGlassCard(
      radius: 14,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tint.withValues(alpha: 0.28)),
            ),
            child: Text(
              _title(block),
              style: TextStyle(
                color: tint,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            block.title.isNotEmpty ? block.title : _title(block),
            style: const TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            block.text,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              height: 1.45,
            ),
          ),
          if (block.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...block.items.map(
              (it) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isKeyPoints
                            ? AurixTokens.glass(0.08)
                            : tint.withValues(alpha: 0.08))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tint.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          isMistakes
                              ? Icons.warning_amber_rounded
                              : (isActions
                                  ? Icons.play_circle_fill_rounded
                                  : Icons.bolt_rounded),
                          color: tint,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          it,
                          style: const TextStyle(color: AurixTokens.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _title(NavigatorBodyBlock b) {
    switch (b.kind) {
      case 'hero':
        return 'Контекст';
      case 'why_it_matters':
        return 'Почему это важно';
      case 'key_points':
        return 'Ключевые мысли';
      case 'mistakes':
        return 'Где артисты теряют';
      case 'action_steps':
        return 'Что сделать сейчас';
      case 'aurix_next_step':
        return 'Следующий шаг в AURIX';
      default:
        return b.title;
    }
  }
}
