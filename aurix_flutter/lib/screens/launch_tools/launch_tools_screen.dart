import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/components/liquid_glass.dart';

/// Launch Tools — Smartlink, Pre-save, Content Kit, Countdown, Promo Checklist.
class LaunchToolsScreen extends ConsumerWidget {
  const LaunchToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.t(context, 'launchTools'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('Tools for release launch', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > 700;
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _SmartlinkCard()),
                    const SizedBox(width: 20),
                    Expanded(child: _PresaveCard()),
                  ],
                );
              }
              return Column(
                children: [
                  _SmartlinkCard(),
                  const SizedBox(height: 20),
                  _PresaveCard(),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _ContentKitCard(),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _CountdownCard()),
              const SizedBox(width: 20),
              Expanded(child: _PromoChecklistCard()),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmartlinkCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, color: AurixTokens.orange),
              const SizedBox(width: 12),
              Text('Smartlink Generator', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AurixTokens.glass(0.08), borderRadius: BorderRadius.circular(12)),
            child: Text('https://aurix.link/midnight-sessions', style: TextStyle(color: AurixTokens.orange, fontFamily: 'monospace', fontSize: 13)),
          ),
          const SizedBox(height: 12),
          Text('Mock preview page', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PresaveCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark_add_rounded, color: AurixTokens.orange),
              const SizedBox(width: 12),
              Text('Pre-save Toggle', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text('Enable pre-save', style: TextStyle(color: AurixTokens.text, fontSize: 14)),
            value: true,
            onChanged: (_) {},
          ),
        ],
      ),
    );
  }
}

class _ContentKitCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, color: AurixTokens.orange),
              const SizedBox(width: 12),
              Text(L10n.t(context, 'contentKit'), style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _KitItem(label: 'Press release template', icon: Icons.article),
              _KitItem(label: 'Captions', icon: Icons.format_quote),
              _KitItem(label: 'Link-in-bio', icon: Icons.link),
            ],
          ),
        ],
      ),
    );
  }
}

class _KitItem extends StatelessWidget {
  final String label;
  final IconData icon;

  const _KitItem({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AurixTokens.glass(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AurixTokens.stroke(0.1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: AurixTokens.muted),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: TextStyle(color: AurixTokens.text, fontSize: 14), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_rounded, color: AurixTokens.orange),
              const SizedBox(width: 12),
              Expanded(child: Text('Countdown Timer', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 16),
          Text('12d 4h 32m', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AurixTokens.orange, fontWeight: FontWeight.w800)),
          Text('Until release', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PromoChecklistCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final items = [('Post on social', true), ('Email list', false), ('Influencer outreach', false)];
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: AurixTokens.orange),
              const SizedBox(width: 12),
              Text('Promo Checklist', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(i.$2 ? Icons.check_circle : Icons.radio_button_unchecked, size: 20, color: i.$2 ? AurixTokens.orange : AurixTokens.muted),
                    const SizedBox(width: 12),
                    Text(i.$1, style: TextStyle(color: i.$2 ? AurixTokens.muted : AurixTokens.text, decoration: i.$2 ? TextDecoration.lineThrough : null)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
