import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/beat_model.dart';
import 'dart:html' as html;

class BeatPlayerBar extends StatefulWidget {
  final BeatModel beat;
  final VoidCallback onClose;
  final VoidCallback onBuy;

  const BeatPlayerBar({
    super.key,
    required this.beat,
    required this.onClose,
    required this.onBuy,
  });

  @override
  State<BeatPlayerBar> createState() => _BeatPlayerBarState();
}

class _BeatPlayerBarState extends State<BeatPlayerBar> {
  late html.AudioElement _audio;
  bool _playing = false;
  double _progress = 0;
  double _duration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  @override
  void didUpdateWidget(BeatPlayerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beat.id != widget.beat.id) {
      _audio.pause();
      _timer?.cancel();
      _initAudio();
    }
  }

  void _initAudio() {
    final url = widget.beat.previewUrl ?? widget.beat.audioUrl;
    _audio = html.AudioElement(url);
    _audio.onLoadedMetadata.listen((_) {
      if (mounted) {
        setState(() => _duration = _audio.duration.toDouble());
      }
    });
    _audio.onEnded.listen((_) {
      if (mounted) setState(() => _playing = false);
      _timer?.cancel();
    });
    _audio.play();
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted && !_audio.paused) {
        setState(() => _progress = _audio.currentTime.toDouble());
      }
    });
  }

  @override
  void dispose() {
    _audio.pause();
    _timer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    if (_playing) {
      _audio.pause();
    } else {
      _audio.play();
    }
    setState(() => _playing = !_playing);
  }

  void _seek(double value) {
    _audio.currentTime = value;
    setState(() => _progress = value);
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border(top: BorderSide(color: AurixTokens.stroke(0.25))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Cover thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 40,
                height: 40,
                child: widget.beat.coverUrl != null
                    ? Image.network(widget.beat.coverUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _miniCover())
                    : _miniCover(),
              ),
            ),
            const SizedBox(width: 10),
            // Title + artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.beat.title,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontHeading,
                      color: AurixTokens.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.beat.sellerName ?? 'Producer',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Play/pause
            IconButton(
              onPressed: _togglePlay,
              icon: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AurixTokens.text,
              ),
              iconSize: 24,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            // Progress slider — desktop only
            if (isDesktop) ...[
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Text(_formatTime(_progress),
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderThemeData(
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                          trackHeight: 3,
                          activeTrackColor: AurixTokens.accent,
                          inactiveTrackColor: AurixTokens.surface2,
                          thumbColor: AurixTokens.accent,
                          overlayShape: SliderComponentShape.noOverlay,
                        ),
                        child: Slider(
                          value: _progress.clamp(0, _duration > 0 ? _duration : 1),
                          max: _duration > 0 ? _duration : 1,
                          onChanged: _seek,
                        ),
                      ),
                    ),
                    Text(_formatTime(_duration),
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Buy button
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: widget.onBuy,
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.accent,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 16 : 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                  ),
                ),
                child: const Text('Купить'),
              ),
            ),
            const SizedBox(width: 2),
            // Close
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded, color: AurixTokens.muted, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniCover() {
    return Container(
      color: AurixTokens.surface2,
      child: const Icon(Icons.audiotrack_rounded, color: AurixTokens.muted, size: 20),
    );
  }
}
