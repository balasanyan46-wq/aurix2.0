import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/features/main_shell/main_shell_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';

/// Главная (Dashboard): последний релиз, прогресс, задачи, быстрые кнопки, retention.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(releasesProvider).valueOrNull ?? [];
    final lastRelease = releases.isNotEmpty ? releases.first : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Главная',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          _RetentionBlock(releasesCount: releases.length),
          const SizedBox(height: 24),
          _LastReleaseCard(release: lastRelease),
          const SizedBox(height: 24),
          _ProgressBlock(release: lastRelease),
          const SizedBox(height: 24),
          _QuickActions(),
          const SizedBox(height: 24),
          _TasksBlock(),
        ],
      ),
    );
  }
}

class _RetentionBlock extends StatelessWidget {
  final int releasesCount;

  const _RetentionBlock({required this.releasesCount});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Твоя активность', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Free', style: TextStyle(color: AurixTokens.orange, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (releasesCount.clamp(0, 10) / 10).toDouble(),
            backgroundColor: AurixTokens.glass(0.15),
            valueColor: AlwaysStoppedAnimation(AurixTokens.orange),
          ),
          const SizedBox(height: 8),
          Text('Прогресс карьеры', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatChip(icon: Icons.album_outlined, label: 'Релизов', value: '$releasesCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AurixTokens.muted),
        const SizedBox(width: 8),
        Text('$value $label', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
      ],
    );
  }
}

class _LastReleaseCard extends StatelessWidget {
  final ReleaseModel? release;

  const _LastReleaseCard({this.release});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Последний релиз', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (release != null) ...[
            Text(release!.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${release!.releaseType} • ${release!.status}', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push('/releases/${release!.id}'),
              child: const Text('Открыть'),
            ),
          ] else
            Text('Пока нет релизов', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  final ReleaseModel? release;

  const _ProgressBlock({this.release});

  @override
  Widget build(BuildContext context) {
    final filled = release != null ? 60 : 0;
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Прогресс релиза', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              Text('$filled%', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: filled / 100,
            backgroundColor: AurixTokens.glass(0.15),
            valueColor: AlwaysStoppedAnimation(AurixTokens.orange),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Быстрые действия', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AurixButton(
                text: 'Создать релиз',
                icon: Icons.add_rounded,
                onPressed: () => context.push('/releases/create'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AurixButton(
                text: 'Studio AI',
                icon: Icons.auto_awesome_rounded,
                onPressed: () => ref.read(mainShellTabProvider.notifier).state = 2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TasksBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tasks = [
      'Заполнить профиль артиста',
      'Загрузить обложку релиза',
      'Добавить первый трек',
    ];
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Задачи недели', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...tasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_unchecked, size: 20, color: AurixTokens.muted),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t, style: TextStyle(color: AurixTokens.text, fontSize: 14))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
