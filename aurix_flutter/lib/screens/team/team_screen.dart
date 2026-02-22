import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';

/// Команда — участники, роли, сплиты.
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockMembers = [
      ('Вы', 'Артист', '100%'),
      ('Producer B', 'Продюсер', '—'),
      ('Mix Engineer', 'Звукорежиссёр', '—'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(L10n.t(context, 'team'),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Участники, роли и сплиты',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 16)),
                  ],
                ),
                AurixButton(
                  text: 'Добавить участника',
                  icon: Icons.person_add_rounded,
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Добавление участника (mock)'))),
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
                  Text('Участники команды',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  ...mockMembers.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AurixTokens.orange.withValues(alpha: 0.3),
                                border: Border.all(color: AurixTokens.stroke(0.2)),
                              ),
                              child: Icon(Icons.person, color: AurixTokens.orange, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.$1, style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600)),
                                  Text(m.$2, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                                ],
                              ),
                            ),
                            if (m.$3 != '—')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AurixTokens.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.4)),
                                ),
                                child: Text(m.$3, style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
                              ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Icon(Icons.more_vert, color: AurixTokens.muted),
                              onPressed: () {},
                            ),
                          ],
                        ),
                      )),
                  TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавить участника (mock)'))),
                    icon: Icon(Icons.add, size: 18, color: AurixTokens.orange),
                    label: Text('Пригласить', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeInSlide(
            delayMs: 100,
            child: AurixGlassCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Сплиты (доли)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600)),
                      TextButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Управление сплитами (mock)'))),
                        icon: Icon(Icons.edit, size: 16, color: AurixTokens.orange),
                        label: Text('Редактировать', style: TextStyle(color: AurixTokens.orange, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SplitRow(name: 'Артист', percent: 60),
                  _SplitRow(name: 'Продюсер', percent: 30),
                  _SplitRow(name: 'Звукорежиссёр', percent: 10),
                  const SizedBox(height: 12),
                  Text('Итого: 100%', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final String name;
  final int percent;

  const _SplitRow({required this.name, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(name, style: TextStyle(color: AurixTokens.text))),
          Text('$percent%', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
