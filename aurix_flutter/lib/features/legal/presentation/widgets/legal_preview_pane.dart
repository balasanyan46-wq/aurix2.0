import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

class LegalPreviewPane extends StatelessWidget {
  const LegalPreviewPane({
    super.key,
    required this.title,
    required this.previewText,
    this.onBack,
  });

  final String title;
  final String previewText;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scrollContent = SingleChildScrollView(
            child: SelectableText(
              previewText,
              style: TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.7),
            ),
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (onBack != null)
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
                      onPressed: onBack,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AurixTokens.text,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              if (onBack != null) const SizedBox(height: 24),
              if (constraints.maxHeight != double.infinity)
                Expanded(child: scrollContent)
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 200, maxHeight: 500),
                  child: scrollContent,
                ),
            ],
          );
        },
      ),
    );
  }
}
