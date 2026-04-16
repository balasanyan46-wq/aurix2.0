import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/providers/beats_provider.dart';

class BeatUploadScreen extends ConsumerStatefulWidget {
  const BeatUploadScreen({super.key});

  @override
  ConsumerState<BeatUploadScreen> createState() => _BeatUploadScreenState();
}

class _BeatUploadScreenState extends ConsumerState<BeatUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _bpmCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _leaseCtrl = TextEditingController(text: '2500');
  final _unlimitedCtrl = TextEditingController(text: '10000');
  final _exclusiveCtrl = TextEditingController(text: '25000');

  String? _genre;
  String? _mood;
  bool _isFree = false;
  bool _uploading = false;
  String? _error;
  double _uploadProgress = 0;

  // File state
  String? _audioFileName;
  Uint8List? _audioBytes;
  String? _coverFileName;
  Uint8List? _coverBytes;
  String? _audioUrl;
  String? _audioPath;
  String? _coverUrl;

  static const _genres = [
    'Trap', 'Hip-Hop', 'R&B', 'Pop', 'Drill', 'Lo-Fi',
    'Rage', 'Phonk', 'Boom Bap', 'Afrobeat', 'Reggaeton',
  ];

  static const _moods = [
    'Dark', 'Aggressive', 'Chill', 'Sad', 'Energetic',
    'Romantic', 'Uplifting', 'Dreamy', 'Hard',
  ];

  static const _keys = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
    'Cm', 'C#m', 'Dm', 'D#m', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'A#m', 'Bm',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _bpmCtrl.dispose();
    _keyCtrl.dispose();
    _tagsCtrl.dispose();
    _leaseCtrl.dispose();
    _unlimitedCtrl.dispose();
    _exclusiveCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _audioFileName = result.files.first.name;
        _audioBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _coverFileName = result.files.first.name;
        _coverBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audioBytes == null) {
      setState(() => _error = 'Загрузите аудио файл');
      return;
    }

    setState(() { _uploading = true; _error = null; _uploadProgress = 0; });

    try {
      // 1. Upload audio
      setState(() => _uploadProgress = 0.2);
      final audioRes = await ApiClient.uploadFile(
        '/upload/audio', _audioBytes!, _audioFileName ?? 'beat.mp3', fieldName: 'file',
      );
      final audioBody = _asMap(audioRes.data);
      _audioUrl = (audioBody['url'] ?? '').toString();
      _audioPath = (audioBody['path'] ?? audioBody['key'] ?? '').toString();

      // 2. Upload cover (if provided)
      if (_coverBytes != null) {
        setState(() => _uploadProgress = 0.5);
        final coverRes = await ApiClient.uploadFile(
          '/upload/cover', _coverBytes!, _coverFileName ?? 'cover.jpg', fieldName: 'file',
        );
        final coverBody = _asMap(coverRes.data);
        _coverUrl = (coverBody['url'] ?? '').toString();
      }

      // 3. Create beat
      setState(() => _uploadProgress = 0.8);
      final tags = _tagsCtrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      await ref.read(beatRepositoryProvider).createBeat({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'genre': _genre,
        'mood': _mood,
        'bpm': int.tryParse(_bpmCtrl.text),
        'key': _keyCtrl.text.trim().isEmpty ? null : _keyCtrl.text.trim(),
        'tags': tags,
        'audio_url': _audioUrl,
        'audio_path': _audioPath,
        'cover_url': _coverUrl,
        'price_lease': _isFree ? 0 : int.tryParse(_leaseCtrl.text) ?? 0,
        'price_unlimited': _isFree ? 0 : int.tryParse(_unlimitedCtrl.text) ?? 0,
        'price_exclusive': _isFree ? 0 : int.tryParse(_exclusiveCtrl.text) ?? 0,
        'is_free': _isFree,
        'status': 'active',
      });

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ref.invalidate(myBeatsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Бит успешно загружен!'),
            backgroundColor: AurixTokens.positive,
          ),
        );
        context.go('/beats');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    return PremiumPageScaffold(
      title: 'Загрузить бит',
      subtitle: 'Добавь бит в маркетплейс и начни зарабатывать',
      systemLabel: 'BEAT UPLOAD',
      systemColor: AurixTokens.accent,
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Audio file
              PremiumSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSectionHeader(title: 'Аудио файл', subtitle: 'MP3, WAV, FLAC — до 100 МБ'),
                    const SizedBox(height: 12),
                    _FilePickerButton(
                      icon: Icons.audiotrack_rounded,
                      label: _audioFileName ?? 'Выбрать аудио',
                      hasFile: _audioBytes != null,
                      onTap: _pickAudio,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Cover
              PremiumSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSectionHeader(title: 'Обложка', subtitle: 'JPG, PNG — до 10 МБ (необязательно)'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_coverBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_coverBytes!, width: 80, height: 80, fit: BoxFit.cover),
                          ),
                        if (_coverBytes != null) const SizedBox(width: 12),
                        Expanded(
                          child: _FilePickerButton(
                            icon: Icons.image_rounded,
                            label: _coverFileName ?? 'Выбрать обложку',
                            hasFile: _coverBytes != null,
                            onTap: _pickCover,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Beat details
              PremiumSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PremiumSectionHeader(title: 'Информация о бите'),
                    const SizedBox(height: 12),
                    _field('Название *', _titleCtrl, validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Введите название' : null),
                    const SizedBox(height: 10),
                    _field('Описание', _descCtrl, maxLines: 3),
                    const SizedBox(height: 10),
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(child: _dropdown('Жанр', _genre, _genres, (v) => setState(() => _genre = v))),
                          const SizedBox(width: 10),
                          Expanded(child: _dropdown('Настроение', _mood, _moods, (v) => setState(() => _mood = v))),
                        ],
                      )
                    else ...[
                      _dropdown('Жанр', _genre, _genres, (v) => setState(() => _genre = v)),
                      const SizedBox(height: 10),
                      _dropdown('Настроение', _mood, _moods, (v) => setState(() => _mood = v)),
                    ],
                    const SizedBox(height: 10),
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(child: _field('BPM', _bpmCtrl, keyboardType: TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(child: _dropdown('Тональность', _keyCtrl.text.isEmpty ? null : _keyCtrl.text, _keys, (v) {
                            setState(() => _keyCtrl.text = v ?? '');
                          })),
                        ],
                      )
                    else ...[
                      _field('BPM', _bpmCtrl, keyboardType: TextInputType.number),
                      const SizedBox(height: 10),
                      _dropdown('Тональность', _keyCtrl.text.isEmpty ? null : _keyCtrl.text, _keys, (v) {
                        setState(() => _keyCtrl.text = v ?? '');
                      }),
                    ],
                    const SizedBox(height: 10),
                    _field('Теги (через запятую)', _tagsCtrl, hintText: 'trap, dark, 808, bass'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Pricing
              PremiumSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: PremiumSectionHeader(title: 'Цены', subtitle: 'Укажи цену для каждой лицензии')),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Бесплатный', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                            const SizedBox(width: 6),
                            Switch(
                              value: _isFree,
                              activeColor: AurixTokens.accent,
                              onChanged: (v) => setState(() => _isFree = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (!_isFree) ...[
                      const SizedBox(height: 12),
                      if (isDesktop)
                        Row(
                          children: [
                            Expanded(child: _priceField('Лизинг \u20BD', _leaseCtrl)),
                            const SizedBox(width: 10),
                            Expanded(child: _priceField('Безлимит \u20BD', _unlimitedCtrl)),
                            const SizedBox(width: 10),
                            Expanded(child: _priceField('Эксклюзив \u20BD', _exclusiveCtrl)),
                          ],
                        )
                      else ...[
                        _priceField('Лизинг \u20BD', _leaseCtrl),
                        const SizedBox(height: 8),
                        _priceField('Безлимит \u20BD', _unlimitedCtrl),
                        const SizedBox(height: 8),
                        _priceField('Эксклюзив \u20BD', _exclusiveCtrl),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Вы получаете 85% от каждой продажи',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Upload progress
              if (_uploading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: AurixTokens.surface2,
                    valueColor: const AlwaysStoppedAnimation(AurixTokens.accent),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
                const SizedBox(height: 8),
              ],
              // Submit
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _uploading ? null : _submit,
                  icon: _uploading
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: Text(_uploading ? 'Загрузка...' : 'Опубликовать бит'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AurixTokens.accent.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AurixTokens.radiusButton),
                    ),
                    textStyle: TextStyle(
                      fontFamily: AurixTokens.fontHeading,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        labelStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
        hintStyle: const TextStyle(color: AurixTokens.micro, fontSize: 13),
        filled: true,
        fillColor: AurixTokens.surface1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusField),
          borderSide: BorderSide(color: AurixTokens.stroke(0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusField),
          borderSide: BorderSide(color: AurixTokens.stroke(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusField),
          borderSide: const BorderSide(color: AurixTokens.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _priceField(String label, TextEditingController ctrl) {
    return _field(label, ctrl, keyboardType: TextInputType.number);
  }

  Widget _dropdown(String label, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 13)),
      icon: const Icon(Icons.expand_more, color: AurixTokens.muted, size: 18),
      dropdownColor: AurixTokens.bg1,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
        filled: true,
        fillColor: AurixTokens.surface1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusField),
          borderSide: BorderSide(color: AurixTokens.stroke(0.18)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusField),
          borderSide: BorderSide(color: AurixTokens.stroke(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AurixTokens.radiusField),
          borderSide: const BorderSide(color: AurixTokens.accent),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}

class _FilePickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasFile;
  final VoidCallback onTap;

  const _FilePickerButton({
    required this.icon,
    required this.label,
    required this.hasFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: hasFile ? AurixTokens.positive.withValues(alpha: 0.08) : AurixTokens.surface1,
          borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
          border: Border.all(
            color: hasFile ? AurixTokens.positive.withValues(alpha: 0.3) : AurixTokens.stroke(0.18),
            style: hasFile ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasFile ? Icons.check_circle_rounded : icon,
              color: hasFile ? AurixTokens.positive : AurixTokens.muted, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: hasFile ? AurixTokens.positive : AurixTokens.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
