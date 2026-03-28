import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/track_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class TrackWithRelease {
  final TrackModel track;
  final ReleaseModel release;
  const TrackWithRelease({required this.track, required this.release});
}

class TrackSelector extends StatelessWidget {
  final List<TrackWithRelease> tracks;
  final TrackWithRelease? selected;
  final ValueChanged<TrackWithRelease> onSelect;

  const TrackSelector({
    super.key,
    required this.tracks,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.stroke(0.08)),
        ),
        child: Column(children: [
          Icon(Icons.music_off_rounded, size: 40, color: AurixTokens.muted.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('Нет треков', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
          const SizedBox(height: 4),
          Text('Загрузите треки в раздел Релизы',
              style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 12)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Выберите трек', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...tracks.map((t) => _TrackTile(
              item: t,
              isSelected: selected?.track.id == t.track.id,
              onTap: () => onSelect(t),
            )),
      ],
    );
  }
}

class _TrackTile extends StatelessWidget {
  final TrackWithRelease item;
  final bool isSelected;
  final VoidCallback onTap;

  const _TrackTile({required this.item, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final coverUrl = ApiClient.fixUrl(item.release.coverUrl);
    final hasAudio = item.track.audioUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasAudio ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? AurixTokens.accent.withValues(alpha: 0.08) : AurixTokens.glass(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AurixTokens.accent.withValues(alpha: 0.4) : AurixTokens.stroke(0.08),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: coverUrl.isNotEmpty
                    ? Image.network(coverUrl, width: 48, height: 48, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    item.track.title ?? 'Трек ${item.track.trackNumber}',
                    style: TextStyle(
                      color: hasAudio ? AurixTokens.text : AurixTokens.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.release.artist ?? ''} · ${item.release.title ?? ''}',
                    style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.7), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!hasAudio)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Нет аудио', style: TextStyle(color: AurixTokens.warning.withValues(alpha: 0.7), fontSize: 11)),
                    ),
                ]),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: AurixTokens.accent, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.album_rounded, color: AurixTokens.muted, size: 24),
    );
  }
}
