import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/beat_model.dart';

class BeatCard extends StatefulWidget {
  final BeatModel beat;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onLike;
  final VoidCallback onBuy;

  const BeatCard({
    super.key,
    required this.beat,
    required this.isPlaying,
    required this.onPlay,
    required this.onLike,
    required this.onBuy,
  });

  @override
  State<BeatCard> createState() => _BeatCardState();
}

class _BeatCardState extends State<BeatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final beat = widget.beat;
    final minPrice = beat.isFree ? 0 : beat.priceLease;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        curve: AurixTokens.cEase,
        transform: Matrix4.identity()..scale(_hovered ? 1.02 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          gradient: AurixTokens.cardGradient,
          border: Border.all(
            color: widget.isPlaying
                ? AurixTokens.accent.withValues(alpha: 0.5)
                : AurixTokens.stroke(0.18),
          ),
          boxShadow: [
            ...AurixTokens.subtleShadow,
            if (widget.isPlaying)
              BoxShadow(
                color: AurixTokens.accent.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: -8,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover + play button
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (beat.coverUrl != null && beat.coverUrl!.isNotEmpty)
                      Image.network(
                        beat.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultCover(),
                      )
                    else
                      _defaultCover(),
                    // Gradient overlay
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AurixTokens.bg0.withValues(alpha: 0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Play button
                    Center(
                      child: AnimatedOpacity(
                        opacity: _hovered || widget.isPlaying ? 1.0 : 0.0,
                        duration: AurixTokens.dFast,
                        child: GestureDetector(
                          onTap: widget.onPlay,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AurixTokens.accent,
                              boxShadow: AurixTokens.accentGlowShadow,
                            ),
                            child: Icon(
                              widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Like button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: widget.onLike,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AurixTokens.bg0.withValues(alpha: 0.6),
                          ),
                          child: Icon(
                            beat.isLiked == true ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: beat.isLiked == true ? AurixTokens.danger : AurixTokens.text,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    // Genre tag
                    if (beat.genre != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AurixTokens.accent.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(AurixTokens.radiusXs),
                          ),
                          child: Text(
                            beat.genre!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Info section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        beat.title,
                        style: TextStyle(
                          fontFamily: AurixTokens.fontHeading,
                          color: AurixTokens.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        beat.sellerName ?? 'Producer',
                        style: const TextStyle(
                          color: AurixTokens.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Meta row
                      Row(
                        children: [
                          if (beat.bpm != null) ...[
                            Icon(Icons.speed_rounded, size: 12, color: AurixTokens.muted),
                            const SizedBox(width: 3),
                            Text('${beat.bpm}', style: _metaStyle),
                            const SizedBox(width: 10),
                          ],
                          if (beat.key != null) ...[
                            Icon(Icons.music_note_rounded, size: 12, color: AurixTokens.muted),
                            const SizedBox(width: 3),
                            Text(beat.key!, style: _metaStyle),
                            const SizedBox(width: 10),
                          ],
                          Text(beat.formattedDuration, style: _metaStyle),
                          const Spacer(),
                          Icon(Icons.play_arrow_rounded, size: 12, color: AurixTokens.muted),
                          const SizedBox(width: 2),
                          Text('${beat.plays}', style: _metaStyle),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Price + buy button
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              beat.isFree ? 'Бесплатно' : 'от ${_formatPrice(minPrice)}',
                              style: TextStyle(
                                fontFamily: AurixTokens.fontHeading,
                                color: beat.isFree ? AurixTokens.positive : AurixTokens.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 32,
                            child: FilledButton(
                              onPressed: widget.onBuy,
                              style: FilledButton.styleFrom(
                                backgroundColor: AurixTokens.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                                ),
                              ),
                              child: const Text('Купить'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      color: AurixTokens.surface2,
      child: Center(
        child: Icon(Icons.audiotrack_rounded, size: 40, color: AurixTokens.muted),
      ),
    );
  }

  static const _metaStyle = TextStyle(
    color: AurixTokens.muted,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  String _formatPrice(int price) {
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}K \u20BD';
    }
    return '$price \u20BD';
  }
}
