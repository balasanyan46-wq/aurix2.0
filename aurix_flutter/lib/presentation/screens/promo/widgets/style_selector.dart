import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class VideoStyleOption {
  final String id;
  final String label;
  final IconData icon;
  final String description;

  const VideoStyleOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
  });
}

const videoStyles = [
  VideoStyleOption(id: 'zoom', label: 'Zoom', icon: Icons.zoom_in_rounded, description: 'Плавный зум'),
  VideoStyleOption(id: 'night', label: 'Night', icon: Icons.nightlight_round, description: 'Тёмные тона'),
  VideoStyleOption(id: 'energy', label: 'Energy', icon: Icons.bolt_rounded, description: 'Контраст + вспышки'),
  VideoStyleOption(id: 'sad', label: 'Sad', icon: Icons.water_drop_rounded, description: 'Мягкое затухание'),
];

class StyleSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const StyleSelector({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Стиль видео', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: videoStyles.map((s) => _StyleChip(
              style: s,
              isSelected: selected == s.id,
              onTap: () => onSelect(s.id),
            )).toList(),
      ),
    ]);
  }
}

class _StyleChip extends StatelessWidget {
  final VideoStyleOption style;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleChip({required this.style, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AurixTokens.accent.withValues(alpha: 0.12) : AurixTokens.glass(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AurixTokens.accent.withValues(alpha: 0.5) : AurixTokens.stroke(0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(style.icon, size: 24, color: isSelected ? AurixTokens.accent : AurixTokens.muted),
          const SizedBox(height: 6),
          Text(style.label, style: TextStyle(
            color: isSelected ? AurixTokens.accent : AurixTokens.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 2),
          Text(style.description, style: TextStyle(
            color: AurixTokens.muted.withValues(alpha: 0.6),
            fontSize: 10,
          )),
        ]),
      ),
    );
  }
}
