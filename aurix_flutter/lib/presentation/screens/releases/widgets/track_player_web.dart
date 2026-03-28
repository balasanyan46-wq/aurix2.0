// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Thin wrapper around HTML <audio> element for web.
class AudioHandle {
  final html.AudioElement _el;

  AudioHandle(String url) : _el = html.AudioElement(url) {
    _el.preload = 'metadata';
    _el.onEnded.listen((_) => onEnded?.call());
    _el.onError.listen((_) => onError?.call());
    _el.onCanPlay.listen((_) => onCanPlay?.call());
  }

  VoidCallback? onEnded;
  VoidCallback? onError;
  VoidCallback? onCanPlay;

  double get duration {
    final d = _el.duration.toDouble();
    return (d.isNaN || d.isInfinite) ? 0.0 : d;
  }

  double get currentTime => _el.currentTime.toDouble();

  void play() => _el.play();
  void pause() => _el.pause();
  void seekTo(double t) => _el.currentTime = t;

  void dispose() {
    _el.pause();
    _el.remove();
  }
}

typedef VoidCallback = void Function();

AudioHandle createAudioHandle(String url) => AudioHandle(url);
