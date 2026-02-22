import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

class FilesScreen extends ConsumerWidget {
  const FilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Files', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Upload and manage your assets', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
          const SizedBox(height: 32),
          AurixGlassCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(Icons.folder_rounded, size: 64, color: AurixTokens.orange.withValues(alpha: 0.6)),
                const SizedBox(height: 16),
                Text('No files yet', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Upload cover art, stems, or other assets', style: TextStyle(color: AurixTokens.muted)),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.upload_rounded, size: 20),
                  label: const Text('Upload'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AurixTokens.orange,
                    side: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
