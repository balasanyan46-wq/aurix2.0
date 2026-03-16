import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/production/data/production_models.dart';
import 'package:aurix_flutter/features/production/data/production_service.dart';

class ProductionItemDetailSheet extends StatefulWidget {
  final ProductionOrderItem item;
  final String currentUserId;
  final String currentUserRole; // artist/admin/assignee
  final ProductionService service;
  final VoidCallback? onChanged;

  const ProductionItemDetailSheet({
    super.key,
    required this.item,
    required this.currentUserId,
    required this.currentUserRole,
    required this.service,
    this.onChanged,
  });

  @override
  State<ProductionItemDetailSheet> createState() => _ProductionItemDetailSheetState();
}

class _ProductionItemDetailSheetState extends State<ProductionItemDetailSheet> {
  final _commentCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<ProductionComment> _comments = const [];
  List<ProductionFile> _files = const [];
  List<ProductionEvent> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.service.getItemDetails(widget.item.id);
      if (!mounted) return;
      setState(() {
        _comments = res.$1;
        _files = res.$2;
        _events = res.$3;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addComment() async {
    final msg = _commentCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.service.addComment(
        orderItemId: widget.item.id,
        authorUserId: widget.currentUserId,
        authorRole: widget.currentUserRole,
        message: msg,
      );
      _commentCtrl.clear();
      await _load();
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upload(String kind) async {
    final pick = await FilePicker.platform.pickFiles(withData: true);
    if (pick == null || pick.files.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.service.uploadOrderFile(
        orderItemId: widget.item.id,
        uploadedBy: widget.currentUserId,
        kind: kind,
        file: pick.files.first,
      );
      await _load();
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _download(ProductionFile f) async {
    final link = await widget.service.getSignedDownloadUrl(f.path);
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AurixTokens.bg0,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.service?.title ?? 'Услуга',
                            style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ),
                        _StatusChip(status: widget.item.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.item.brief['what_needed_from_artist'] != null)
                      _box(
                        'Что нужно от тебя',
                        Text(
                          widget.item.brief['what_needed_from_artist'].toString(),
                          style: const TextStyle(color: AurixTokens.textSecondary),
                        ),
                      ),
                    _box(
                      'Таймлайн',
                      _events.isEmpty
                          ? const Text('Пока нет событий', style: TextStyle(color: AurixTokens.muted))
                          : Column(
                              children: _events
                                  .map((e) => Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Icon(Icons.bolt_rounded, size: 16, color: AurixTokens.accent),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _eventTitle(e),
                                                style: const TextStyle(color: AurixTokens.textSecondary),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            ),
                    ),
                    _box(
                      'Файлы',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('От тебя', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _saving ? null : () => _upload('input'),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('Загрузить'),
                              ),
                            ],
                          ),
                          ..._files.where((f) => f.kind == 'input').map((f) => _fileRow(f)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('Результат', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              if (widget.currentUserRole != 'artist')
                                TextButton.icon(
                                  onPressed: _saving ? null : () => _upload('output'),
                                  icon: const Icon(Icons.upload_file_rounded),
                                  label: const Text('Загрузить'),
                                ),
                            ],
                          ),
                          ..._files.where((f) => f.kind == 'output').map((f) => _fileRow(f)),
                        ],
                      ),
                    ),
                    _box(
                      'Комментарии',
                      Column(
                        children: [
                          ..._comments.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Align(
                                  alignment: c.authorUserId == widget.currentUserId
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AurixTokens.bg2,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      c.message,
                                      style: const TextStyle(color: AurixTokens.textSecondary),
                                    ),
                                  ),
                                ),
                              )),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentCtrl,
                                  decoration: const InputDecoration(hintText: 'Оставить комментарий'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _saving ? null : _addComment,
                                icon: const Icon(Icons.send_rounded, color: AurixTokens.accent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _box(String title, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );

  Widget _fileRow(ProductionFile f) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(f.fileName, style: const TextStyle(color: AurixTokens.textSecondary), overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          onPressed: () => _download(f),
          icon: const Icon(Icons.download_rounded, color: AurixTokens.accent),
        ),
      );

  String _eventTitle(ProductionEvent e) {
    switch (e.eventType) {
      case 'status_changed':
        return 'Статус изменён: ${productionStatusLabel((e.payload['status'] ?? '').toString())}';
      case 'assigned':
        return 'Назначен исполнитель';
      case 'file_uploaded':
        return 'Загружен файл: ${(e.payload['file_name'] ?? '').toString()}';
      case 'deadline_changed':
        return 'Обновлён дедлайн';
      case 'comment_added':
        return 'Добавлен комментарий';
      default:
        return 'Событие процесса';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'done' => const Color(0xFF22C55E),
      'review' => const Color(0xFF06B6D4),
      'in_progress' => AurixTokens.accent,
      'waiting_artist' => const Color(0xFFF59E0B),
      'canceled' => AurixTokens.negative,
      _ => AurixTokens.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        productionStatusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
