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
            '\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u043f\u0435\u0440\u0432\u044b\u0439 \u0440\u0435\u043b\u0438\u0437',
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontWeight: FontWeight.w700,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\u041d\u0430\u0447\u043d\u0438 \u0441 \u0442\u0440\u0435\u043a\u0430, \u043e\u0431\u043b\u043e\u0436\u043a\u0438 \u0438 \u0431\u0430\u0437\u043e\u0432\u044b\u0445 \u043c\u0435\u0442\u0430\u0434\u0430\u043d\u043d\u044b\u0445.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
            label: const Text('\u0421\u043e\u0437\u0434\u0430\u0442\u044c \u0440\u0435\u043b\u0438\u0437'),
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
            : AurixTokens.orange;
    final status = releaseStatusFromString(release.status).label;

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CoverThumb(url: release.coverUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\u0422\u0415\u041a\u0423\u0429\u0418\u0419 \u0420\u0415\u041b\u0418\u0417',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.micro,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AurixTokens.glass(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AurixTokens.accent, AurixTokens.accentWarm],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AurixTokens.accent.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Stage chips
          Row(
            children: [
              Expanded(child: _StageChip(label: '\u041e\u0431\u0440\u0430\u0437', done: hasCover, icon: Icons.image_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _StageChip(label: '\u041c\u0430\u0442\u0435\u0440\u0438\u0430\u043b', done: hasMaterial, icon: Icons.music_note_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _StageChip(label: '\u0417\u0430\u043f\u0443\u0441\u043a', done: hasLaunch, icon: Icons.rocket_launch_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: Colors.white,
                textStyle: TextStyle(fontFamily: AurixTokens.fontBody, fontWeight: FontWeight.w700),
              ),
              child: const Text('\u041f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.done, required this.icon});
  final String label;
  final bool done;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: done ? AurixTokens.accent.withValues(alpha: 0.08) : AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        border: Border.all(
          color: done ? AurixTokens.accent.withValues(alpha: 0.22) : AurixTokens.stroke(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : icon,
            size: 14,
            color: done ? AurixTokens.accent : AurixTokens.micro,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                color: done ? AurixTokens.text : AurixTokens.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
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
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        child: Image.network(
          url!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        border: Border.all(color: AurixTokens.stroke(0.12)),
        color: AurixTokens.surface1,
      ),
      child: const Icon(Icons.music_note_rounded, color: AurixTokens.micro, size: 24),
    );
  }
}
