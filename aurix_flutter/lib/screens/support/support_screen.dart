import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';

/// Поддержка — FAQ + вход в чат помощника (FAB на экране).
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqs = [
      (L10n.t(context, 'createRelease'), 'Перейдите в «Релизы» → «Загрузить релиз» или нажмите кнопку в разделе Релизы.'),
      (L10n.t(context, 'importCsv'), 'Откройте «Статистика» и нажмите «Импортировать CSV». Загрузите отчёт от дистрибьютора.'),
      (L10n.t(context, 'subscription'), 'Раздел «Подписка» — выберите план и оплатите. Доступны Basic, Pro, Studio.'),
      (L10n.t(context, 'services'), 'Раздел «Услуги» — дополнительная поддержка Wide Star: биты, сведение, мастеринг и др.'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.t(context, 'support'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'Часто задаваемые вопросы и помощь',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          FadeInSlide(
            delayMs: 50,
            child: AurixGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: AurixTokens.orange, size: 28),
                      const SizedBox(width: 12),
                      Text('FAQ',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ...faqs.asMap().entries.map((e) {
                    final (q, a) = e.value;
                    return Padding(
                      padding: EdgeInsets.only(bottom: e.key < faqs.length - 1 ? 20 : 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q, style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text(a, style: TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.5)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          FadeInSlide(
            delayMs: 100,
            child: Text(
              'Используйте плавающую кнопку в правом нижнем углу для чата с AURIX Assistant.',
              style: TextStyle(color: AurixTokens.muted, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
