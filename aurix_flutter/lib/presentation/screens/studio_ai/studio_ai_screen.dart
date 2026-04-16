import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_backdrop.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';
import 'package:aurix_flutter/design/components/liquid_glass.dart';
import 'package:aurix_flutter/features/covers/cover_generator_sheet.dart';
import 'ai_tool_config.dart';
import 'ai_tool_chat_screen.dart';
import 'generate_cover_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/track_analysis_screen.dart';

// ── Mode definition (keep for backward compat) ──────────────────

enum AiMode {
  chat(id: 'chat', label: 'Chat', icon: Icons.chat_rounded),
  analyze(id: 'analyze', label: 'Анализ', icon: Icons.graphic_eq_rounded),
  image(id: 'image', label: 'Обложка', icon: Icons.image_rounded),
  dnk(id: 'dnk', label: 'DNK', icon: Icons.fingerprint_rounded),
  reels(id: 'reels', label: 'Reels', icon: Icons.videocam_rounded),
  lyrics(id: 'lyrics', label: 'Текст', icon: Icons.edit_note_rounded),
  ideas(id: 'ideas', label: 'Идеи', icon: Icons.lightbulb_rounded);

  final String id;
  final String label;
  final IconData icon;
  const AiMode({required this.id, required this.label, required this.icon});

  bool get isGenerative => this == image;
  bool get isExternal => this == analyze;

  String get placeholder => switch (this) {
        AiMode.chat => 'Опиши идею, трек или задачу...',
        AiMode.analyze => '',
        AiMode.image => 'Опиши обложку или визуал...',
        AiMode.dnk => 'Опиши себя как артиста...',
        AiMode.reels => 'Опиши тему для Reels...',
        AiMode.lyrics => 'Опиши идею для текста...',
        AiMode.ideas => 'Опиши направление для идей...',
      };
}

// ── Main Screen: Tool Selector Grid ─────────────────────────────

class StudioAiScreen extends ConsumerStatefulWidget {
  const StudioAiScreen({super.key, this.initialPrompt, this.initialMode});
  final String? initialPrompt;
  final String? initialMode;

  @override
  ConsumerState<StudioAiScreen> createState() => _StudioAiScreenState();
}

class _StudioAiScreenState extends ConsumerState<StudioAiScreen> {
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-navigate to specific tool if mode provided
    if (!_navigated && widget.initialMode != null) {
      _navigated = true;
      final tool = aiTools.where((t) => t.mode.id == widget.initialMode).firstOrNull;
      if (tool != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _openTool(tool, initialPrompt: widget.initialPrompt);
        });
      }
    }
  }

  void _openTool(AiToolConfig tool, {String? initialPrompt}) {
    if (tool.isExternal) {
      if (tool.mode == AiMode.image) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GenerateCoverScreen()),
        );
        return;
      }
      if (tool.mode == AiMode.analyze) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TrackAnalysisScreen()),
        );
        return;
      }
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiToolChatScreen(tool: tool, initialPrompt: initialPrompt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return AurixBackdrop(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
                SectionOnboarding(tip: OnboardingTips.studioAi),

                // Header
                FadeInSlide(
                  child: Column(
                    children: [
                      // AI Avatar
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AurixTokens.accent, AurixTokens.accentWarm],
                          ),
                          boxShadow: [
                            BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.3), blurRadius: 20),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 12),
                      // Status
                      LiquidGlass(
                        level: GlassLevel.light,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        radius: 8,
                        hoverScale: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: AurixTokens.positive,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: AurixTokens.positive.withValues(alpha: 0.5), blurRadius: 6)],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'AI STUDIO ONLINE',
                              style: TextStyle(fontFamily: AurixTokens.fontMono, color: AurixTokens.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(colors: [AurixTokens.text, AurixTokens.accent]).createShader(bounds),
                        child: Text(
                          'Aurix Studio',
                          style: TextStyle(fontFamily: AurixTokens.fontHeading, fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Выбери инструмент — AI сделает остальное',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.muted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Tool grid
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth > 600 ? 3 : 2;
                    const spacing = 12.0;
                    final itemW = (c.maxWidth - spacing * (cols - 1)) / cols;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: aiTools.asMap().entries.map((e) {
                        final tool = e.value;
                        return FadeInSlide(
                          delayMs: 100 + e.key * 60,
                          child: SizedBox(
                            width: itemW,
                            child: _ToolCard(
                              tool: tool,
                              onTap: () => _openTool(tool),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Tool Card ───────────────────────────────────────────────────

class _ToolCard extends StatefulWidget {
  const _ToolCard({required this.tool, required this.onTap});
  final AiToolConfig tool;
  final VoidCallback onTap;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tool = widget.tool;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered ? tool.color.withValues(alpha: 0.08) : AurixTokens.bg1,
                AurixTokens.bg1.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: _hovered ? tool.color.withValues(alpha: 0.3) : AurixTokens.stroke(0.12),
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: tool.color.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: _hovered ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tool.color.withValues(alpha: 0.15)),
                    ),
                    child: Icon(tool.icon, size: 20, color: tool.color),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 16, color: _hovered ? tool.color : AurixTokens.micro),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                tool.title,
                style: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  color: AurixTokens.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tool.description,
                style: const TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (tool.examplePrompts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  tool.examplePrompts.first,
                  style: TextStyle(color: tool.color.withValues(alpha: 0.7), fontSize: 11, fontStyle: FontStyle.italic),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
