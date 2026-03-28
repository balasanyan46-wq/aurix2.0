import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import '../models/ai_character.dart';

class CharacterCard extends StatefulWidget {
  final AiCharacter character;
  final VoidCallback onTap;

  const CharacterCard({super.key, required this.character, required this.onTap});

  @override
  State<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<CharacterCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered ? c.accent.withValues(alpha: 0.1) : AurixTokens.glass(0.05),
                AurixTokens.bg2.withValues(alpha: _hovered ? 0.45 : 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? c.accent.withValues(alpha: 0.35) : AurixTokens.stroke(0.1),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: c.accent.withValues(alpha: 0.1),
                      blurRadius: 36,
                      spreadRadius: -10,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Row(children: [
            // Avatar
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: RadialGradient(colors: [
                  c.accent.withValues(alpha: _hovered ? 0.25 : 0.14),
                  c.accent.withValues(alpha: 0.03),
                ]),
                border: Border.all(
                  color: c.accent.withValues(alpha: _hovered ? 0.3 : 0.12),
                ),
                boxShadow: _hovered
                    ? [BoxShadow(color: c.accent.withValues(alpha: 0.12), blurRadius: 20, spreadRadius: -6)]
                    : null,
              ),
              child: Icon(c.icon, size: 26, color: c.accent),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.role,
                    style: TextStyle(color: c.accent.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.description,
                    style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.65), fontSize: 13, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: _hovered ? c.accent : AurixTokens.muted.withValues(alpha: 0.35),
            ),
          ]),
        ),
      ),
    );
  }
}
