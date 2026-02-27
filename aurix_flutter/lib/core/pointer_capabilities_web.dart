// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool isTouchLikeDevice() {
  try {
    final mm = html.window.matchMedia('(hover: none), (pointer: coarse)');
    if (mm.matches) return true;
    final mtp = html.window.navigator.maxTouchPoints ?? 0;
    return mtp > 0;
  } catch (_) {
    return false;
  }
}

