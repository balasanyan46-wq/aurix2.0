import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

class NavigatorArticleChecklist extends StatelessWidget {
  const NavigatorArticleChecklist({
    super.key,
    required this.items,
    required this.checkedIndexes,
    required this.onToggle,
  });

  final List<String> items;
  final Set<int> checkedIndexes;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: items.isEmpty ? 0 : (checkedIndexes.length / items.length).clamp(0, 1),
            minHeight: 6,
            backgroundColor: AurixTokens.glass(0.12),
            valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
          ),
          const SizedBox(height: 8),
          const Text(
            'Чек-лист выполнения',
            style: TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Отметь шаги — и преврати разбор в рабочее действие.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...items.asMap().entries.map(
            (entry) => CheckboxListTile(
              value: checkedIndexes.contains(entry.key),
              onChanged: (_) => onToggle(entry.key),
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                entry.value,
                style: TextStyle(
                  color: checkedIndexes.contains(entry.key)
                      ? AurixTokens.muted
                      : AurixTokens.textSecondary,
                  decoration: checkedIndexes.contains(entry.key)
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
