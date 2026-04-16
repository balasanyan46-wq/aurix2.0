import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'home_shared.dart';

class CreateFirstReleaseBlock extends StatelessWidget {
  const CreateFirstReleaseBlock({super.key, required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      glowColor: AurixTokens.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AurixTokens.accent.withValues(alpha: 0.2),
                  AurixTokens.accentWarm.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.add_rounded, color: AurixTokens.accent, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            'Создать первый релиз',
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Загрузи трек и обложку — мы разместим на всех платформах.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
            label: const Text('Создать релиз'),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.accent,
              foregroundColor: Colors.white,
              textStyle: TextStyle(fontFamily: AurixTokens.fontBody, fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
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
            : AurixTokens.accent;
    final status = releaseStatusFromString(release.status).label;

    // Fix cover URL (IP → domain)
    final coverUrl = ApiClient.fixUrl(release.coverUrl ?? '');
    final coverPath = release.coverPath ?? '';
    final hasCoverImage = coverUrl.isNotEmpty || coverPath.isNotEmpty;
    final displayUrl = coverUrl.isNotEmpty ? coverUrl : coverPath;

    // Figure out what's the next step
    final nextStep = !hasCover
        ? 'Добавь обложку'
        : !hasMaterial
            ? 'Загрузи треки'
            : !hasLaunch
                ? 'Отправь на модерацию'
                : release.isLive
                    ? 'Релиз на платформах'
                    : 'Ожидает проверки';

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cover image
              _CoverThumb(url: hasCoverImage ? displayUrl : null),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      release.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontHeading,
                        color: AurixTokens.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    if (release.artist != null && release.artist!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        release.artist!,
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: AurixTokens.glass(0.08)),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentWarm]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Next step hint
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AurixTokens.accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(
                  hasLaunch ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                  size: 16,
                  color: hasLaunch ? AurixTokens.positive : AurixTokens.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nextStep,
                    style: TextStyle(
                      color: hasLaunch ? AurixTokens.positive : AurixTokens.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // CTA
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: TextStyle(fontFamily: AurixTokens.fontBody, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              child: Text(release.isLive ? 'Открыть релиз' : 'Продолжить'),
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
    final fixedUrl = url != null && url!.isNotEmpty ? ApiClient.fixUrl(url!) : null;

    if (fixedUrl != null && fixedUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          fixedUrl,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.08),
            AurixTokens.surface1,
          ],
        ),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: const Icon(Icons.music_note_rounded, color: AurixTokens.micro, size: 28),
    );
  }
}
