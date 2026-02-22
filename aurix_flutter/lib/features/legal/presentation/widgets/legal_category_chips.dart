import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';

class LegalCategoryChips extends StatelessWidget {
  const LegalCategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final LegalCategory selected;
  final void Function(LegalCategory) onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LegalCategory.values.map((cat) {
        final isSelected = selected == cat;
        return FilterChip(
          label: Text(cat.label, style: const TextStyle(fontSize: 13)),
          selected: isSelected,
          onSelected: (_) => onSelected(cat),
          selectedColor: AurixTokens.orange.withValues(alpha: 0.25),
          checkmarkColor: AurixTokens.orange,
          labelStyle: TextStyle(
            color: isSelected ? AurixTokens.orange : AurixTokens.muted,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        );
      }).toList(),
    );
  }
}
