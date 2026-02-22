import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/features/legal/data/legal_template_model.dart';

class LegalTemplateCard extends StatelessWidget {
  const LegalTemplateCard({
    super.key,
    required this.template,
    required this.onOpen,
    this.compact = false,
  });

  final LegalTemplateModel template;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return AurixGlassCard(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_outlined, color: AurixTokens.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      template.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AurixTokens.text,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.description,
                      style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AurixTokens.muted),
            ],
          ),
        ),
      );
    }

    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_outlined, color: AurixTokens.orange, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            template.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AurixTokens.text,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              template.description,
              style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            template.category.label,
            style: TextStyle(color: AurixTokens.orange, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          AurixButton(
            text: 'Открыть',
            icon: Icons.open_in_new_rounded,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
