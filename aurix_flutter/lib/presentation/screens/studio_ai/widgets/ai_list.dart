import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Parsed AI result — either structured data or plain text.
sealed class AiParsedResult {}

class AiListResult extends AiParsedResult {
  final List<Map<String, dynamic>> items;
  final String mode; // 'ideas' | 'reels'
  AiListResult(this.items, this.mode);
}

class AiDnkResult extends AiParsedResult {
  final Map<String, dynamic> data;
  AiDnkResult(this.data);
}

class AiTextResult extends AiParsedResult {
  final String text;
  final bool isLyrics;
  AiTextResult(this.text, {this.isLyrics = false});
}

/// Try to parse AI response into structured result.
/// Strips ---follow_up--- block before parsing.
AiParsedResult parseAiResponse(String content, String mode) {
  // Strip follow_up block before any parsing
  final fuIdx = content.indexOf('---follow_up---');
  final cleaned = fuIdx != -1 ? content.substring(0, fuIdx).trim() : content;

  // Always try to parse JSON regardless of mode
  final trimmed = cleaned.trim();

  if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
    try {
      final parsed = jsonDecode(trimmed);

      if (parsed is List && parsed.isNotEmpty) {
        final items = parsed
            .whereType<Map<String, dynamic>>()
            .toList();
        if (items.isNotEmpty) {
          // Detect type from keys
          final guessedMode = _guessListMode(items.first, mode);
          return AiListResult(items, guessedMode);
        }
      }

      if (parsed is Map<String, dynamic>) {
        if (_isDnkShape(parsed)) {
          return AiDnkResult(parsed);
        }
        // Single object that looks like an idea/reel
        if (parsed.containsKey('title') || parsed.containsKey('hook')) {
          return AiListResult([parsed], _guessListMode(parsed, mode));
        }
      }
    } catch (_) {
      // Not valid JSON
    }
  }

  return AiTextResult(
    cleaned,
    isLyrics: mode == 'lyrics' || _looksLikeLyrics(cleaned),
  );
}

String _guessListMode(Map<String, dynamic> item, String fallback) {
  if (item.containsKey('caption')) return 'reels';
  if (item.containsKey('title') && item.containsKey('idea')) return 'ideas';
  if (fallback == 'ideas' || fallback == 'reels') return fallback;
  return 'ideas';
}

bool _isDnkShape(Map<String, dynamic> m) {
  return m.containsKey('audience') ||
      m.containsKey('triggers') ||
      m.containsKey('content_angles') ||
      m.containsKey('reels_ideas');
}

bool _looksLikeLyrics(String text) {
  final lines = text.split('\n');
  if (lines.length < 6) return false;
  final markers = ['куплет', 'припев', 'бридж', 'verse', 'chorus', 'bridge', 'hook'];
  int found = 0;
  for (final line in lines) {
    final lower = line.toLowerCase().trim();
    if (markers.any((m) => lower.contains(m))) found++;
  }
  return found >= 2;
}

/// Renders a parsed AI result as beautiful widgets.
class AiResultRenderer extends StatelessWidget {
  final AiParsedResult result;
  final void Function(String text) onCopy;

  const AiResultRenderer({
    super.key,
    required this.result,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      AiListResult r => _buildList(context, r),
      AiDnkResult r => AiDnkBlock(data: r.data),
      AiTextResult r => r.isLyrics ? _buildLyrics(r.text) : _buildPlainText(r.text),
    };
  }

  Widget _buildList(BuildContext context, AiListResult r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < r.items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildCard(context, r.items[i], i + 1, r.mode),
        ],
      ],
    );
  }

  Widget _buildCard(BuildContext ctx, Map<String, dynamic> item, int idx, String mode) {
    final copyText = item.entries.map((e) => '${e.key}: ${e.value}').join('\n');

    if (mode == 'reels') {
      return AiReelsCard(
        index: idx,
        idea: item['idea']?.toString() ?? '',
        hook: item['hook']?.toString() ?? '',
        caption: item['caption']?.toString() ?? '',
        onCopy: () => onCopy(copyText),
      );
    }

    return AiIdeaCard(
      index: idx,
      title: item['title']?.toString() ?? 'Идея $idx',
      idea: item['idea']?.toString() ?? '',
      hook: item['hook']?.toString() ?? '',
      onCopy: () => onCopy(copyText),
    );
  }

  Widget _buildLyrics(String text) {
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 10);

        final isSection = _isSectionHeader(trimmed);
        return Padding(
          padding: EdgeInsets.only(bottom: isSection ? 6 : 3),
          child: Text(
            trimmed,
            style: TextStyle(
              color: isSection ? AurixTokens.accent : AurixTokens.text,
              fontSize: isSection ? 15 : 14,
              fontWeight: isSection ? FontWeight.w700 : FontWeight.w400,
              height: 1.6,
              letterSpacing: isSection ? 0.5 : 0,
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _isSectionHeader(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('**') ||
        lower.startsWith('куплет') ||
        lower.startsWith('припев') ||
        lower.startsWith('бридж') ||
        lower.startsWith('финальн') ||
        lower.startsWith('verse') ||
        lower.startsWith('chorus') ||
        lower.startsWith('bridge') ||
        lower.startsWith('outro') ||
        lower.startsWith('intro');
  }

  Widget _buildPlainText(String text) {
    return SelectableText(
      text,
      style: TextStyle(
        color: AurixTokens.text,
        fontSize: 14,
        height: 1.6,
      ),
    );
  }
}

/// Skeleton shimmer for loading state.
class AiShimmerCards extends StatefulWidget {
  const AiShimmerCards({super.key});

  @override
  State<AiShimmerCards> createState() => _AiShimmerCardsState();
}

class _AiShimmerCardsState extends State<AiShimmerCards>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final shimmer = AurixTokens.bg2
            .withValues(alpha: 0.3 + (_controller.value * 0.3));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBlock(shimmer, height: 100),
            const SizedBox(height: 12),
            _shimmerBlock(shimmer, height: 80),
            const SizedBox(height: 12),
            _shimmerBlock(shimmer, height: 60),
          ],
        );
      },
    );
  }

  Widget _shimmerBlock(Color color, {required double height}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
    );
  }
}

// ── Inline card widgets (previously in separate files) ──────────

class AiIdeaCard extends StatelessWidget {
  final int index;
  final String title;
  final String idea;
  final String hook;
  final VoidCallback? onCopy;

  const AiIdeaCard({super.key, required this.index, required this.title, required this.idea, this.hook = '', this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 14, backgroundColor: AurixTokens.accent.withValues(alpha: 0.15),
            child: Text('$index', style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14))),
          if (onCopy != null) IconButton(icon: const Icon(Icons.copy_rounded, size: 16, color: AurixTokens.muted), onPressed: onCopy),
        ]),
        if (idea.isNotEmpty) ...[const SizedBox(height: 8), Text(idea, style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.5))],
        if (hook.isNotEmpty) ...[const SizedBox(height: 6), Text('Hook: $hook', style: TextStyle(color: AurixTokens.accent.withValues(alpha: 0.8), fontSize: 12, fontStyle: FontStyle.italic))],
      ]),
    );
  }
}

class AiReelsCard extends StatelessWidget {
  final int index;
  final String idea;
  final String hook;
  final String caption;
  final VoidCallback? onCopy;

  const AiReelsCard({super.key, required this.index, required this.idea, required this.hook, required this.caption, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.videocam_rounded, size: 18, color: AurixTokens.accent),
          const SizedBox(width: 8),
          Text('Reels #$index', style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14)),
          const Spacer(),
          if (onCopy != null) IconButton(icon: const Icon(Icons.copy_rounded, size: 16, color: AurixTokens.muted), onPressed: onCopy),
        ]),
        if (idea.isNotEmpty) ...[const SizedBox(height: 8), Text(idea, style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.5))],
        if (hook.isNotEmpty) ...[const SizedBox(height: 6), Text('Hook: $hook', style: TextStyle(color: AurixTokens.accent.withValues(alpha: 0.8), fontSize: 12))],
        if (caption.isNotEmpty) ...[const SizedBox(height: 6), Text('Caption: $caption', style: const TextStyle(color: AurixTokens.muted, fontSize: 12))],
      ]),
    );
  }
}

class AiDnkBlock extends StatelessWidget {
  final Map<String, dynamic> data;
  const AiDnkBlock({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final entry in data.entries) ...[
        const SizedBox(height: 8),
        Text(entry.key.replaceAll('_', ' ').toUpperCase(),
          style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        if (entry.value is List)
          ...((entry.value as List).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• ${item.toString()}', style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.5)),
          )))
        else
          Text(entry.value.toString(), style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.5)),
      ],
    ]);
  }
}
