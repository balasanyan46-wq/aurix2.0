import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'video_preview_stub.dart'
    if (dart.library.html) 'video_preview_web.dart' as preview;

const _styleLabels = {
  'zoom': 'Zoom',
  'night': 'Night City',
  'energy': 'Energy',
  'sad': 'Sad / Emotional',
};

class VideoResult extends StatelessWidget {
  final String videoUrl;
  final String? styleUsed;
  final VoidCallback onCreateAnother;

  const VideoResult({
    super.key,
    required this.videoUrl,
    this.styleUsed,
    required this.onCreateAnother,
  });

  void _download() {
    final url = ApiClient.fixUrl(videoUrl);
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final fixedUrl = ApiClient.fixUrl(videoUrl);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AurixTokens.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.check_circle_rounded, color: AurixTokens.accent, size: 36),
        ),
        const SizedBox(height: 16),
        const Text('Видео готово!', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          '1080×1920 MP4 · Готово для Reels / Stories'
          '${styleUsed != null ? ' · Стиль: ${_styleLabels[styleUsed] ?? styleUsed}' : ''}',
          style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.7), fontSize: 13),
        ),
        const SizedBox(height: 20),

        // Video preview
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: preview.buildVideoPreview(fixedUrl),
          ),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _download,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Скачать'),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCreateAnother,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Создать ещё'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AurixTokens.text,
                side: BorderSide(color: AurixTokens.stroke(0.15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
