// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool isTouchLikeDevice() {
  try {
    // IMPORTANT: Avoid using `maxTouchPoints` to classify touch devices.
    // On macOS trackpads, `maxTouchPoints` can be > 0 while the device still
    // supports hover and a fine pointer, which would incorrectly disable FX.
    final coarse = html.window.matchMedia('(pointer: coarse)').matches;
    final noHover = html.window.matchMedia('(hover: none)').matches;
    return coarse || noHover;
  } catch (_) {
    return false;
  }
}

