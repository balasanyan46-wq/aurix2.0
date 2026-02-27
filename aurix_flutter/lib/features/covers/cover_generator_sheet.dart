import 'dart:convert';
import 'dart:typed_data';

import 'package:aurix_flutter/ai/cover_ai_service.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/features/covers/cover_download.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CoverGeneratorSheet extends ConsumerStatefulWidget {
  const CoverGeneratorSheet({
    super.key,
    this.releaseId,
    this.initialArtistName,
    this.initialReleaseTitle,
    this.initialGenre,
    this.onApplied,
    this.onClosed,
  });

  final String? releaseId;
  final String? initialArtistName;
  final String? initialReleaseTitle;
  final String? initialGenre;
  final void Function(String coverUrl, String coverPath)? onApplied;
  final VoidCallback? onClosed;

  static Future<Uint8List?> open(
    BuildContext context, {
    String? releaseId,
    String? initialArtistName,
    String? initialReleaseTitle,
    String? initialGenre,
    void Function(String coverUrl, String coverPath)? onApplied,
  }) async {
    return await showModalBottomSheet<Uint8List?>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => CoverGeneratorSheet(
        releaseId: releaseId,
        initialArtistName: initialArtistName,
        initialReleaseTitle: initialReleaseTitle,
        initialGenre: initialGenre,
        onApplied: onApplied,
      ),
    );
  }

  @override
  ConsumerState<CoverGeneratorSheet> createState() => _CoverGeneratorSheetState();
}

class _CoverGeneratorSheetState extends ConsumerState<CoverGeneratorSheet> {
  late final _artistCtrl = TextEditingController(text: widget.initialArtistName ?? '');
  late final _titleCtrl = TextEditingController(text: widget.initialReleaseTitle ?? '');
  late final _genreCtrl = TextEditingController(text: widget.initialGenre ?? '');
  final _moodCtrl = TextEditingController();

  String _style = 'dark_minimal';
  bool _noText = true;
  String _size = '1024x1024';
  String _quality = 'high';

  bool _refineOpen = false;
  int _detailLevel = 1; // 0..2 => low/med/high
  int _accentLevel = 1; // 0..2 => subtle/med/strong
  bool _cinematicBoost = false;

  bool _loading = false;
  String? _error;
  Uint8List? _bytes;
  Map<String, dynamic>? _meta;

  @override
  void dispose() {
    _artistCtrl.dispose();
    _titleCtrl.dispose();
    _genreCtrl.dispose();
    _moodCtrl.dispose();
    super.dispose();
  }

  String _buildPrompt({required bool variant, required int variationToken}) {
    final artist = _artistCtrl.text.trim();
    final title = _titleCtrl.text.trim();
    final genre = _genreCtrl.text.trim();
    final mood = _moodCtrl.text.trim();

    final preset = switch (_style) {
      'dark_minimal' => 'dark minimal, sleek, modern, expensive, minimal typography-free design, moody lighting',
      'cinematic' => 'cinematic, film still vibe, dramatic lighting, depth, high contrast, premium',
      'futuristic' => 'futuristic, sci-fi, neon accents, clean geometry, premium, high detail',
      'street' => 'street, gritty, raw texture, urban night, flash photography vibe, premium',
      _ => 'luxury, glossy, high-end product photography vibe, minimal, premium',
    };

    final detail = switch (_detailLevel) {
      0 => 'minimal composition, lots of negative space, simple shapes, clean.',
      2 => 'rich detailed scene, intricate textures, high detail, layered depth.',
      _ => 'balanced detail, clean but textured, premium polish.',
    };

    final accent = switch (_accentLevel) {
      0 => 'subtle accent color, restrained highlights.',
      2 => 'strong accent highlight, bold accent color, striking focal accents.',
      _ => 'distinct accent highlight, tasteful contrast, premium accent.',
    };

    final cinematic = _cinematicBoost ? 'cinematic lighting, film still vibe, dramatic contrast.' : null;

    final forbidText = _noText
        ? 'No readable text, no typography, no logos, no watermarks, no brand names.'
        : 'No logos, no watermarks, no brand names.';

    final parts = <String>[
      'Square album cover (1:1), PNG.',
      'High-end, premium, professional album cover art.',
      preset,
      detail,
      accent,
      if (cinematic != null) cinematic,
      if (artist.isNotEmpty) 'Artist: $artist.',
      if (title.isNotEmpty) 'Release title: $title.',
      if (genre.isNotEmpty) 'Genre: $genre.',
      if (mood.isNotEmpty) 'Mood keywords: $mood.',
      forbidText,
      'No UI, no app screens, no mockups.',
      if (variant) 'Generate a distinctly different concept and composition from previous attempts while keeping the same mood and style.',
      if (variant) 'Variation token: $variationToken',
    ];
    return parts.join('\n');
  }

  Future<void> _generate({required bool variant}) async {
    final token = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = ref.read(currentUserProvider)?.id;
      final resp = await CoverAiService.generate(
        prompt: _buildPrompt(variant: variant, variationToken: token),
        size: _size,
        quality: _quality,
        outputFormat: 'png',
        background: 'opaque',
        releaseId: widget.releaseId,
        userId: userId,
      );
      if (!mounted) return;
      setState(() {
        _bytes = resp.bytes;
        _meta = resp.meta;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _applyToRelease() async {
    final bytes = _bytes;
    if (bytes == null || bytes.isEmpty) return;
    final releaseId = widget.releaseId;
    if (releaseId == null) return;
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fileRepo = ref.read(fileRepositoryProvider);
      final releaseRepo = ref.read(releaseRepositoryProvider);
      final uploaded = await fileRepo.uploadCoverBytes(userId, releaseId, bytes, 'generated_cover.png');
      await releaseRepo.updateRelease(releaseId, coverUrl: uploaded.publicUrl, coverPath: uploaded.coverPath);
      widget.onApplied?.call(uploaded.publicUrl, uploaded.coverPath);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);
    final inset = MediaQuery.viewInsetsOf(context);
    final canApply = widget.releaseId != null;
    final canUseInForm = !canApply;

    return Padding(
      padding: EdgeInsets.only(left: pad, right: pad, bottom: inset.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.97,
        builder: (ctx, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: AurixTokens.bg1,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border.all(color: AurixTokens.stroke(0.18)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AurixTokens.muted.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.image_rounded, color: AurixTokens.orange, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Обложки',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AurixTokens.muted,
                        tooltip: 'Закрыть',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                          ),
                          child: Text(_error!, style: const TextStyle(color: AurixTokens.text, fontSize: 13, height: 1.35)),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _field('Артист', _artistCtrl),
                      const SizedBox(height: 10),
                      _field('Релиз', _titleCtrl),
                      const SizedBox(height: 10),
                      _field('Жанр', _genreCtrl),
                      const SizedBox(height: 10),
                      _field('Mood keywords (через запятую)', _moodCtrl, maxLines: 2),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _chip(
                            title: 'Dark minimal',
                            selected: _style == 'dark_minimal',
                            onTap: _loading ? null : () => setState(() => _style = 'dark_minimal'),
                          ),
                          _chip(
                            title: 'Cinematic',
                            selected: _style == 'cinematic',
                            onTap: _loading ? null : () => setState(() => _style = 'cinematic'),
                          ),
                          _chip(
                            title: 'Futuristic',
                            selected: _style == 'futuristic',
                            onTap: _loading ? null : () => setState(() => _style = 'futuristic'),
                          ),
                          _chip(
                            title: 'Street',
                            selected: _style == 'street',
                            onTap: _loading ? null : () => setState(() => _style = 'street'),
                          ),
                          _chip(
                            title: 'Luxury',
                            selected: _style == 'luxury',
                            onTap: _loading ? null : () => setState(() => _style = 'luxury'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _noText,
                        onChanged: _loading ? null : (v) => setState(() => _noText = v),
                        title: const Text('Без текста (рекомендуется)'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _size,
                              items: const [
                                DropdownMenuItem(value: '1024x1024', child: Text('1024')),
                                DropdownMenuItem(value: '1536x1536', child: Text('1536')),
                              ],
                              onChanged: _loading ? null : (v) => setState(() => _size = v ?? '1024x1024'),
                              decoration: const InputDecoration(labelText: 'Size'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _quality,
                              items: const [
                                DropdownMenuItem(value: 'high', child: Text('High')),
                                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                              ],
                              onChanged: _loading ? null : (v) => setState(() => _quality = v ?? 'high'),
                              decoration: const InputDecoration(labelText: 'Quality'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AurixButton(
                        text: _bytes == null ? 'Сгенерировать' : 'Регенерировать',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: _loading ? null : () => _generate(variant: false),
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2))),
                      if (_bytes != null) ...[
                        AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(_bytes!, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_meta != null)
                          Text(
                            jsonEncode(_meta),
                            style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.75), fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : () => _generate(variant: true),
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Перегенерировать (новый вариант)'),
                                style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading
                                    ? null
                                    : () {
                                        setState(() => _refineOpen = !_refineOpen);
                                      },
                                icon: const Icon(Icons.tune_rounded, size: 18),
                                label: Text(_refineOpen ? 'Скрыть уточнения' : 'Уточнить'),
                                style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: _refineOpen
                              ? Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AurixTokens.glass(0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AurixTokens.stroke(0.14)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Уточнения', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 10),
                                      _field('Mood keywords (через запятую)', _moodCtrl, maxLines: 2),
                                      const SizedBox(height: 10),
                                      DropdownButtonFormField<String>(
                                        value: _style,
                                        items: const [
                                          DropdownMenuItem(value: 'dark_minimal', child: Text('Dark minimal')),
                                          DropdownMenuItem(value: 'cinematic', child: Text('Cinematic')),
                                          DropdownMenuItem(value: 'futuristic', child: Text('Futuristic')),
                                          DropdownMenuItem(value: 'street', child: Text('Street')),
                                          DropdownMenuItem(value: 'luxury', child: Text('Luxury')),
                                        ],
                                        onChanged: _loading ? null : (v) => setState(() => _style = v ?? 'dark_minimal'),
                                        decoration: const InputDecoration(labelText: 'Style preset'),
                                      ),
                                      const SizedBox(height: 10),
                                      Text('Минимализм / детали', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          _miniChip('Больше минимализма', selected: _detailLevel == 0, onTap: _loading ? null : () => setState(() => _detailLevel = 0)),
                                          _miniChip('Баланс', selected: _detailLevel == 1, onTap: _loading ? null : () => setState(() => _detailLevel = 1)),
                                          _miniChip('Больше деталей', selected: _detailLevel == 2, onTap: _loading ? null : () => setState(() => _detailLevel = 2)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text('Темнее / ярче акцент', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: [
                                          _miniChip('Сдержанно', selected: _accentLevel == 0, onTap: _loading ? null : () => setState(() => _accentLevel = 0)),
                                          _miniChip('Выразительно', selected: _accentLevel == 1, onTap: _loading ? null : () => setState(() => _accentLevel = 1)),
                                          _miniChip('Яркий акцент', selected: _accentLevel == 2, onTap: _loading ? null : () => setState(() => _accentLevel = 2)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SwitchListTile(
                                        value: _cinematicBoost,
                                        onChanged: _loading ? null : (v) => setState(() => _cinematicBoost = v),
                                        title: const Text('Больше кинематографичности'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      const SizedBox(height: 6),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: _loading ? null : () => _generate(variant: false),
                                          icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                                          label: const Text('Сгенерировать по уточнениям'),
                                          style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _loading ? null : () => downloadCoverPng(context: context, bytes: _bytes!, fileName: 'cover.png'),
                                icon: const Icon(Icons.download_rounded, size: 18),
                                label: const Text('Скачать (HQ)'),
                                style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                              ),
                            ),
                            if (canUseInForm) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          Navigator.of(context).pop(_bytes);
                                        },
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: const Text('Использовать'),
                                  style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
                                ),
                              ),
                            ],
                            if (canApply) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _applyToRelease,
                                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                                  label: const Text('Применить к релизу'),
                                  style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Важно: генератор старается избегать текста/логотипов. Если модель всё равно рисует текст — просто сделайте регенерацию.',
                        style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      enabled: !_loading,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AurixTokens.glass(0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _chip({required String title, required bool selected, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.orange.withValues(alpha: 0.16) : AurixTokens.glass(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AurixTokens.orange.withValues(alpha: 0.45) : AurixTokens.stroke(0.14)),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? AurixTokens.orange : AurixTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String title, {required bool selected, required VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.orange.withValues(alpha: 0.16) : AurixTokens.glass(0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AurixTokens.orange.withValues(alpha: 0.45) : AurixTokens.stroke(0.14)),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? AurixTokens.orange : AurixTokens.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

