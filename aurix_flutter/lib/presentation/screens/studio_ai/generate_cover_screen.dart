import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/covers/cover_download.dart';

class GenerateCoverScreen extends StatefulWidget {
  const GenerateCoverScreen({super.key});

  @override
  State<GenerateCoverScreen> createState() => _GenerateCoverScreenState();
}

class _GenerateCoverScreenState extends State<GenerateCoverScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _hasText = false;
  String? _imageUrl;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final idea = _ctrl.text.trim();
    if (idea.isEmpty || _loading) return;

    setState(() { _loading = true; _error = null; _imageUrl = null; _imageBytes = null; });

    try {
      final resp = await ApiClient.post(
        '/api/ai/generate-cover',
        data: {'idea': idea},
        receiveTimeout: const Duration(minutes: 3),
      );

      if (!mounted) return;
      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
      final url = data['image'] as String?;
      if (url == null || url.isEmpty) {
        setState(() => _error = 'Не удалось получить изображение');
        return;
      }

      setState(() { _imageUrl = url; });

      // Загружаем байты через Dio (обходит CORS) — показываем из памяти
      try {
        final imgResp = await ApiClient.dio.get<List<int>>(url,
          options: Options(responseType: ResponseType.bytes));
        if (mounted && imgResp.data != null) {
          setState(() => _imageBytes = Uint8List.fromList(imgResp.data!));
        }
      } catch (_) {
        // Если не удалось загрузить — попробуем показать напрямую (Image.network)
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка генерации: ${e.toString().length > 80 ? '${e.toString().substring(0, 77)}...' : e}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    setState(() { _imageUrl = null; _imageBytes = null; _error = null; });
  }

  Future<void> _download() async {
    if (_imageBytes != null) {
      await downloadCoverPng(
        context: context,
        bytes: _imageBytes!,
        fileName: 'aurix-cover-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      return;
    }
    // Fallback: загружаем байты из URL и скачиваем
    if (_imageUrl == null) return;
    try {
      final resp = await ApiClient.dio.get<List<int>>(_imageUrl!,
        options: Options(responseType: ResponseType.bytes));
      if (resp.data != null && mounted) {
        await downloadCoverPng(
          context: context,
          bytes: Uint8List.fromList(resp.data!),
          fileName: 'aurix-cover-${DateTime.now().millisecondsSinceEpoch}.png',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось скачать: $e'), backgroundColor: AurixTokens.danger));
      }
    }
  }

  // ── Загрузить своё фото и доработать через AI ──
  Future<void> _uploadOwn() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;

    setState(() { _imageBytes = Uint8List.fromList(bytes); _imageUrl = null; _error = null; });
  }

  // ── Доработать через AI (refinement prompt) ──
  Future<void> _refineWithAi() async {
    if (_imageBytes == null && _imageUrl == null) return;
    final promptCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Доработать обложку', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Опиши, что изменить — AI сгенерирует новую обложку с учётом твоей идеи.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          TextField(
            controller: promptCtrl,
            maxLines: 3,
            autofocus: true,
            style: const TextStyle(color: AurixTokens.text, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Добавь звёзды и неон, сделай темнее...',
              hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.4)),
              filled: true,
              fillColor: AurixTokens.bg2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: AurixTokens.muted))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.accent),
            child: const Text('Доработать')),
        ],
      ),
    );
    if (confirmed != true || promptCtrl.text.trim().isEmpty) return;
    _ctrl.text = promptCtrl.text.trim();
    _generate();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageBytes != null || _imageUrl != null;
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Создать обложку',
          style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: hasImage && !_loading ? _buildResult() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Icon
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            AurixTokens.accent.withValues(alpha: 0.15),
            AurixTokens.accent.withValues(alpha: 0.04),
          ]),
        ),
        child: const Icon(Icons.palette_rounded, size: 32, color: AurixTokens.accent),
      ),
      const SizedBox(height: 20),
      Text('Опиши атмосферу или идею трека', textAlign: TextAlign.center,
        style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.4)),
      const SizedBox(height: 24),

      // Input
      TextField(
        controller: _ctrl,
        enabled: !_loading,
        maxLines: 3, minLines: 2,
        style: const TextStyle(color: AurixTokens.text, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Например: ночной город, грусть, неон, одиночество',
          hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.45)),
          filled: true,
          fillColor: AurixTokens.glass(0.06),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AurixTokens.stroke(0.12))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.4))),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      const SizedBox(height: 20),

      if (_error != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AurixTokens.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
          ),
          child: Text(_error!, style: TextStyle(color: AurixTokens.danger.withValues(alpha: 0.9), fontSize: 13)),
        ),
        const SizedBox(height: 16),
      ],

      if (_loading) ...[
        const SizedBox(height: 12),
        const CircularProgressIndicator(color: AurixTokens.accent, strokeWidth: 3),
        const SizedBox(height: 16),
        const Text('Создаём обложку...', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
        const SizedBox(height: 4),
        Text('Это может занять до минуты',
          style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 12)),
      ] else ...[
        // Кнопка генерации
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _hasText ? _generate : null,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('Сгенерировать', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AurixTokens.accent.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Кнопка «Загрузить своё»
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _uploadOwn,
            icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
            label: const Text('Загрузить своё фото', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AurixTokens.text,
              side: BorderSide(color: AurixTokens.stroke(0.15)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    ]);
  }

  Widget _buildResult() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Image — из памяти (bytes) или fallback через network
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 1,
          child: _imageBytes != null
            ? Image.memory(_imageBytes!, fit: BoxFit.cover)
            : Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(color: AurixTokens.bg2,
                    child: const Center(child: CircularProgressIndicator(color: AurixTokens.accent, strokeWidth: 2)));
                },
                errorBuilder: (_, __, ___) => Container(color: AurixTokens.bg2,
                  child: const Center(child: Icon(Icons.broken_image_rounded, color: AurixTokens.muted, size: 48))),
              ),
        ),
      ),
      const SizedBox(height: 20),

      // Action buttons
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
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _refineWithAi,
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text('Доработать'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AurixTokens.aiAccent,
              side: BorderSide(color: AurixTokens.aiAccent.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Сгенерировать ещё'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AurixTokens.text,
            side: BorderSide(color: AurixTokens.stroke(0.12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ]);
  }
}
