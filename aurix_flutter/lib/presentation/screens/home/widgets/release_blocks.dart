import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'home_shared.dart';

class CreateFirstReleaseBlock extends StatelessWidget {
  const CreateFirstReleaseBlock({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(24),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Создать первый релиз',
            style: TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Начни с трека, обложки и базовых метаданных.',
            style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Создать первый релиз'),
          ),
        ],
      ),
    );
  }
}

class CurrentReleaseBlock extends StatelessWidget {
  const CurrentReleaseBlock({
    super.key,
    required this.release,
    required this.progress,
    required this.hasCover,
    required this.hasMaterial,
    required this.hasLaunch,
    required this.onContinue,
  });

  final ReleaseModel release;
  final double progress;
  final bool hasCover;
  final bool hasMaterial;
  final bool hasLaunch;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final statusColor = release.isLive
        ? AurixTokens.positive
        : release.isSubmitted
            ? AurixTokens.warning
            : AurixTokens.orange;
    final status = releaseStatusFromString(release.status).label;

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CoverThumb(url: release.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Текущий релиз',
                      style: TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      release.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AurixTokens.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AurixTokens.glass(0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(AurixTokens.orange),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StageChip(label: 'Образ', done: hasCover),
              _StageChip(label: 'Материал', done: hasMaterial),
              _StageChip(label: 'Запуск', done: hasLaunch),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: done ? AurixTokens.orange.withValues(alpha: 0.12) : AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done ? AurixTokens.orange.withValues(alpha: 0.28) : AurixTokens.stroke(0.13),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: done ? AurixTokens.orange : AurixTokens.muted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: done ? AurixTokens.text : AurixTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url!,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.14)),
        color: AurixTokens.bg2.withValues(alpha: 0.92),
      ),
      child: const Icon(Icons.music_note_rounded, color: AurixTokens.textSecondary),
    );
  }
}
