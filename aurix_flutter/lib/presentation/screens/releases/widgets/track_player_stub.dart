/// Stub audio handle for non-web platforms.
class AudioHandle {
  AudioHandle(String url);

  VoidCallback? onEnded;
  VoidCallback? onError;
  VoidCallback? onCanPlay;

  double get duration => 0;
  double get currentTime => 0;

  void play() {}
  void pause() {}
  void seekTo(double t) {}
  void dispose() {}
}

typedef VoidCallback = void Function();

AudioHandle createAudioHandle(String url) => AudioHandle(url);
