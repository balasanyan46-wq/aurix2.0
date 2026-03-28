// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Inline HTML5 video preview for web.
Widget buildVideoPreview(String url) {
  final viewType = 'promo-video-${url.hashCode}';

  // Register the view factory (idempotent — same viewType is ignored on re-register).
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final video = html.VideoElement()
      ..src = url
      ..controls = true
      ..autoplay = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'contain'
      ..style.backgroundColor = 'black'
      ..setAttribute('playsinline', 'true');
    return video;
  });

  return AspectRatio(
    aspectRatio: 9 / 16,
    child: HtmlElementView(viewType: viewType),
  );
}
