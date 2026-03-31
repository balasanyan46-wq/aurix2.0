import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:url_launcher/url_launcher.dart';

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

    setState(() {
      _loading = true;
      _error = null;
      _imageUrl = null;
    });

    try {
      final resp = await ApiClient.post(
        '/api/ai/generate-cover',
        data: {'idea': idea},
        receiveTimeout: const Duration(minutes: 3),
      );

      if (!mounted) return;
      final data = resp.data is Map ? Map<String, dynamic>.from(resp.data as Map) : <String, dynamic>{};
      final url = data['image'] as String?;
      if (url != null && url.isNotEmpty) {
        setState(() => _imageUrl = url);
      } else {
        setState(() => _error = 'Не удалось получить изображение');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Ошибка генерации');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() {
    setState(() {
      _imageUrl = null;
      _error = null;
    });
  }

  void _download() {
    if (_imageUrl == null) return;
    launchUrl(Uri.parse(_imageUrl!), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Создать обложку',
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _imageUrl != null ? _buildResult() : _buildForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon
        Container(
          width: 72,
          height: 72,
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

        // Subtitle
        Text(
          'Опиши атмосферу или идею трека',
          textAlign: TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.4),
        ),
        const SizedBox(height: 24),

        // Input
        TextField(
          controller: _ctrl,
          enabled: !_loading,
          maxLines: 3,
          minLines: 2,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Например: ночной город, грусть, неон, одиночество',
            hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.45)),
            filled: true,
            fillColor: AurixTokens.glass(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AurixTokens.stroke(0.12)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.4)),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 20),

        // Error
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

        // Button / Loading
        if (_loading)
          Column(children: [
            const SizedBox(height: 12),
            const CircularProgressIndicator(color: AurixTokens.accent, strokeWidth: 3),
            const SizedBox(height: 16),
            Text(
              'Создаём обложку...',
              style: TextStyle(color: AurixTokens.muted, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Это может занять до минуты',
              style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 12),
            ),
          ])
        else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.palette_rounded, size: 20),
              label: const Text(
                '\u0421\u0433\u0435\u043d\u0435\u0440\u0438\u0440\u043e\u0432\u0430\u0442\u044c',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildResult() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              _imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AurixTokens.bg2,
                  child: const Center(
                    child: CircularProgressIndicator(color: AurixTokens.accent, strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: AurixTokens.bg2,
                child: const Center(
                  child: Icon(Icons.broken_image_rounded, color: AurixTokens.muted, size: 48),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Buttons
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
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Попробовать ещё'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AurixTokens.text,
                side: BorderSide(color: AurixTokens.stroke(0.15)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
