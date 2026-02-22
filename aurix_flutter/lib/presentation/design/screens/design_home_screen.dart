import 'package:flutter/material.dart';
import 'package:aurix_flutter/presentation/theme/design_theme.dart';
import 'package:aurix_flutter/presentation/design/widgets/liquid_orb.dart';

class DesignHomeScreen extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onProfile;
  final VoidCallback onCreateRelease;

  const DesignHomeScreen({
    super.key,
    required this.onLogin,
    required this.onProfile,
    required this.onCreateRelease,
  });

  @override
  State<DesignHomeScreen> createState() => _DesignHomeScreenState();
}

class _DesignHomeScreenState extends State<DesignHomeScreen> {
  Offset? _cursor;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) => setState(() => _cursor = e.position),
      onExit: (_) => setState(() => _cursor = null),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    DesignTheme.darkBg,
                    Color(0xFF120E0C),
                    DesignTheme.darkBg,
                  ],
                ),
              ),
            ),
            const LiquidOrb(),
            if (_cursor != null) LiquidOrb(cursorOffset: _cursor),
            // Content
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          Text('AURIX', style: Theme.of(context).textTheme.headlineMedium?.copyWith(letterSpacing: 6, color: DesignTheme.textSecondary)),
                          const SizedBox(height: 80),
                          Text(
                            'Your Artist Cabinet',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                  height: 1.1,
                                  color: DesignTheme.accentAmber,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Premium control centre for your music career',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: DesignTheme.textSecondary),
                          ),
                          const SizedBox(height: 48),
                          Wrap(spacing: 16, runSpacing: 16, children: [
                            _GlowButton(label: 'Login UI', onTap: widget.onLogin),
                            _GlowButton(label: 'Profile UI', onTap: widget.onProfile, secondary: true),
                            _GlowButton(label: 'Create Release UI', onTap: widget.onCreateRelease),
                          ]),
                          const SizedBox(height: 64),
                          Text('Overview', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: DesignTheme.textSecondary)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _SectionCard(icon: Icons.album, title: 'Releases', subtitle: 'Manage your catalog')),
                              const SizedBox(width: 16),
                              Expanded(child: _SectionCard(icon: Icons.bar_chart, title: 'Analytics', subtitle: 'Insights & stats')),
                              const SizedBox(width: 16),
                              Expanded(child: _SectionCard(icon: Icons.folder, title: 'Files', subtitle: 'Covers & tracks')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool secondary;

  const _GlowButton({required this.label, required this.onTap, this.secondary = false});

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..translate(0, _hover ? -2 : 0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: widget.secondary
                    ? null
                    : LinearGradient(
                        colors: _hover
                            ? [DesignTheme.accentAmber, DesignTheme.primaryOrange]
                            : [DesignTheme.primaryOrange, DesignTheme.deepOrange],
                      ),
                color: widget.secondary ? DesignTheme.surfaceCard : null,
                border: widget.secondary ? Border.all(color: DesignTheme.borderSubtle) : null,
                boxShadow: !widget.secondary && _hover
                    ? [
                        BoxShadow(
                          color: DesignTheme.primaryOrange.withValues(alpha: 0.5),
                          blurRadius: 24,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Text(widget.label, style: TextStyle(color: widget.secondary ? DesignTheme.textPrimary : Colors.black, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionCard({required this.icon, required this.title, required this.subtitle});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        transform: Matrix4.identity()..translate(0, _hover ? -4 : 0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DesignTheme.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _hover ? DesignTheme.primaryOrange.withValues(alpha: 0.5) : DesignTheme.borderSubtle),
            boxShadow: _hover ? [BoxShadow(color: DesignTheme.primaryOrange.withValues(alpha: 0.15), blurRadius: 20)] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: DesignTheme.primaryOrange, size: 32),
              const SizedBox(height: 16),
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
