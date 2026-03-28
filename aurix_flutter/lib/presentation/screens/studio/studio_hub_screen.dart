import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/presentation/providers/artist_provider.dart';
import 'models/ai_character.dart';
import 'models/artist_profile.dart';
import 'character_screen.dart';
import 'track_analysis_screen.dart';

/// Studio AI hub — "Выбери с кем работать".
/// No onboarding gate — characters are the primary entry point.
class StudioHubScreen extends ConsumerWidget {
  const StudioHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(artistProfileProvider);
    final hasProfile = !profile.isEmpty;

    return PremiumPageScaffold(
      title: 'Выбери с кем работать',
      subtitle: 'AI-команда специалистов для твоей музыки',
      children: [
        // ── Characters — primary entry ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              for (int i = 0; i < aiCharacters.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _TeamMemberCard(
                  character: aiCharacters[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CharacterScreen(character: aiCharacters[i]),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Section: Инструменты ──
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'ИНСТРУМЕНТЫ',
            style: TextStyle(
              color: AurixTokens.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Track Analysis card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _ToolCard(
            icon: Icons.insights_rounded,
            accent: AurixTokens.accent,
            title: 'Анализ трека',
            subtitle: 'Загрузи аудио — AI покажет, что работает и что исправить',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrackAnalysisScreen()),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // AI Profile card — optional
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _ToolCard(
            icon: Icons.person_rounded,
            accent: AurixTokens.aiAccent,
            title: hasProfile ? 'Профиль артиста' : 'Настроить профиль',
            subtitle: hasProfile
                ? '${profile.name} · ${profile.genre}'
                : 'Расскажи о себе — AI будет давать персональные советы',
            onTap: () => context.push('/artist'),
          ),
        ),

        // ── DNA block — collapsible, only if profile exists ──
        if (hasProfile) ...[
          const SizedBox(height: 24),
          _DnaBlock(profile: profile),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AURIX DNA Block
// ══════════════════════════════════════════════════════════════

class _DnaBlock extends StatefulWidget {
  final ArtistProfile profile;
  const _DnaBlock({required this.profile});

  @override
  State<_DnaBlock> createState() => _DnaBlockState();
}

class _DnaBlockState extends State<_DnaBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final level = p.level;
    final accent = _levelColor(level);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withValues(alpha: 0.08),
              AurixTokens.bg2.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Text(level.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      'AURIX DNA',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        level.label,
                        style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    p.name.isNotEmpty ? p.name : 'Артист',
                    style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                ]),
              ),
              Icon(
                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AurixTokens.muted.withValues(alpha: 0.5),
                size: 22,
              ),
            ]),

            // XP bar
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: p.levelProgress,
                    minHeight: 4,
                    backgroundColor: AurixTokens.glass(0.1),
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${p.xp} XP',
                style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ]),

            // Expanded DNA details
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Divider(color: AurixTokens.stroke(0.08), height: 1),
                    const SizedBox(height: 14),

                    // Style
                    if (p.genre.isNotEmpty) ...[
                      _DnaRow(label: 'Жанр', value: '${p.genre}${p.mood.isNotEmpty ? ' · ${p.mood}' : ''}'),
                      const SizedBox(height: 8),
                    ],

                    // Sound description
                    if (p.styleDescription.isNotEmpty) ...[
                      _DnaRow(label: 'Звучание', value: p.styleDescription),
                      const SizedBox(height: 8),
                    ],

                    // References
                    if (p.references.isNotEmpty) ...[
                      _DnaRow(label: 'Вдохновение', value: p.references.join(', ')),
                      const SizedBox(height: 8),
                    ],

                    // Goals
                    if (p.goals.isNotEmpty)
                      _DnaRow(label: 'Цели', value: p.goals.join(', ')),

                    const SizedBox(height: 14),
                    // Edit button
                    GestureDetector(
                      onTap: () => context.go('/artist'),
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 14, color: accent.withValues(alpha: 0.6)),
                        const SizedBox(width: 6),
                        Text(
                          'Редактировать профиль',
                          style: TextStyle(color: accent.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _levelColor(ArtistLevel l) => switch (l) {
    ArtistLevel.beginner => AurixTokens.muted,
    ArtistLevel.growing => AurixTokens.positive,
    ArtistLevel.breakthrough => AurixTokens.accent,
    ArtistLevel.artist => AurixTokens.aiAccent,
  };
}

class _DnaRow extends StatelessWidget {
  final String label;
  final String value;
  const _DnaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 90,
        child: Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.3)),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Team Member Card — with "what" and "why"
// ══════════════════════════════════════════════════════════════

class _TeamMemberCard extends StatefulWidget {
  final AiCharacter character;
  final VoidCallback onTap;

  const _TeamMemberCard({required this.character, required this.onTap});

  @override
  State<_TeamMemberCard> createState() => _TeamMemberCardState();
}

class _TeamMemberCardState extends State<_TeamMemberCard> {
  bool _hovered = false;

  static const _whatDoesMap = {
    'producer': 'Придумает идею, определит хук и выстроит структуру трека',
    'writer': 'Напишет текст с сильными рифмами, припевом и подачей',
    'visual': 'Создаст обложку, подберёт стиль и визуальную концепцию',
    'smm': 'Придумает Reels, подписи и контент-план для продвижения',
  };

  static const _whyNeedMap = {
    'producer': 'Когда есть идея, но нет чёткой структуры',
    'writer': 'Когда нужен текст или хочется усилить рифмы',
    'visual': 'Когда нужна обложка или стиль для релиза',
    'smm': 'Когда трек готов — и нужно его продвинуть',
  };

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
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered ? c.accent.withValues(alpha: 0.1) : AurixTokens.glass(0.04),
                AurixTokens.bg2.withValues(alpha: _hovered ? 0.4 : 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? c.accent.withValues(alpha: 0.3) : AurixTokens.stroke(0.08),
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: c.accent.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: -8, offset: const Offset(0, 8))]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: avatar + name + arrow
              Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: RadialGradient(colors: [
                      c.accent.withValues(alpha: _hovered ? 0.22 : 0.12),
                      c.accent.withValues(alpha: 0.02),
                    ]),
                    border: Border.all(color: c.accent.withValues(alpha: _hovered ? 0.25 : 0.1)),
                  ),
                  child: Icon(c.icon, size: 22, color: c.accent),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    c.name,
                    style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.role,
                    style: TextStyle(color: c.accent.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ])),
                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _hovered ? c.accent : AurixTokens.muted.withValues(alpha: 0.3)),
              ]),
              const SizedBox(height: 12),

              // What does
              _InfoLine(
                icon: Icons.bolt_rounded,
                iconColor: c.accent,
                text: _whatDoesMap[c.id] ?? c.description,
              ),
              const SizedBox(height: 6),
              // Why need
              _InfoLine(
                icon: Icons.lightbulb_outline_rounded,
                iconColor: AurixTokens.muted,
                text: _whyNeedMap[c.id] ?? '',
                muted: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;
  final bool muted;

  const _InfoLine({required this.icon, required this.iconColor, required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 14, color: iconColor.withValues(alpha: muted ? 0.5 : 0.7)),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            color: muted ? AurixTokens.muted.withValues(alpha: 0.6) : AurixTokens.textSecondary,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════
// Tool Card
// ══════════════════════════════════════════════════════════════

class _ToolCard extends StatefulWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({required this.icon, required this.accent, required this.title, required this.subtitle, required this.onTap});

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _hovered ? widget.accent.withValues(alpha: 0.1) : AurixTokens.glass(0.04),
                AurixTokens.bg2.withValues(alpha: _hovered ? 0.4 : 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hovered ? widget.accent.withValues(alpha: 0.3) : AurixTokens.stroke(0.08),
            ),
            boxShadow: _hovered
                ? [BoxShadow(color: widget.accent.withValues(alpha: 0.08), blurRadius: 30, spreadRadius: -8, offset: const Offset(0, 8))]
                : null,
          ),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(colors: [
                  widget.accent.withValues(alpha: _hovered ? 0.22 : 0.12),
                  widget.accent.withValues(alpha: 0.02),
                ]),
                border: Border.all(color: widget.accent.withValues(alpha: _hovered ? 0.25 : 0.1)),
              ),
              child: Icon(widget.icon, size: 22, color: widget.accent),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 12.5, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _hovered ? widget.accent : AurixTokens.muted.withValues(alpha: 0.3)),
          ]),
        ),
      ),
    );
  }
}
