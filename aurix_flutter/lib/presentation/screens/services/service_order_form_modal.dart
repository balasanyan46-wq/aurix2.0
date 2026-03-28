import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/features/production/data/production_models.dart';

class ServiceOrderFormModal extends ConsumerStatefulWidget {
  final String serviceName;

  const ServiceOrderFormModal({super.key, required this.serviceName});

  @override
  ConsumerState<ServiceOrderFormModal> createState() => _ServiceOrderFormModalState();
}

class _ServiceOrderFormModalState extends ConsumerState<ServiceOrderFormModal> {
  final _descController = TextEditingController();
  bool _submitted = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'Не авторизован');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final production = ref.read(productionServiceProvider);
      final catalog = await production.getCatalog();
      final matched = _matchService(catalog, widget.serviceName);
      if (matched == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Эта услуга пока не подключена в Продакшн. Обратитесь к администратору для настройки каталога услуг.';
        });
        return;
      }

      await production.createOrder(
        userId: user.id,
        title: 'Заказ услуги: ${matched.title}',
        serviceIds: [matched.id],
      );
      if (!mounted) return;
      setState(() { _submitted = true; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Ошибка: $e'; _loading = false; });
    }
  }

  ProductionServiceCatalog? _matchService(
    List<ProductionServiceCatalog> catalog,
    String serviceName,
  ) {
    if (catalog.isEmpty) return null;
    final target = _norm(serviceName);

    for (final s in catalog) {
      if (_norm(s.title) == target) return s;
    }
    for (final s in catalog) {
      final t = _norm(s.title);
      if (t.contains(target) || target.contains(t)) return s;
    }
    return null;
  }

  String _norm(String v) {
    final lower = v.toLowerCase().trim();
    return lower
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-я0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Dialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AurixTokens.positive, size: 64),
              const SizedBox(height: 20),
              Text('Услуга добавлена в Продакшн', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AurixTokens.text)),
              const SizedBox(height: 8),
              Text(
                'Проверяйте статус в разделе «Продакшн». Там будут этапы, дедлайны, файлы и комментарии.',
                style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (mounted) context.push('/production');
                    },
                    icon: const Icon(Icons.factory_outlined, size: 18),
                    label: const Text('Открыть Продакшн'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AurixTokens.accent,
                      foregroundColor: AurixTokens.text,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Заказать: ${widget.serviceName}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: AurixTokens.text)),
              const SizedBox(height: 8),
              Text('После заказа услуга появится в разделе «Продакшн».', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: AurixTokens.danger, fontSize: 13)),
                ),
              TextField(
                controller: _descController,
                maxLines: 4,
                style: const TextStyle(color: AurixTokens.text),
                decoration: InputDecoration(
                  hintText: 'Опишите, что вам нужно (необязательно)',
                  hintStyle: TextStyle(color: AurixTokens.muted, fontSize: 14),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.bg0))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Заказать услугу'),
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.orange,
                  foregroundColor: AurixTokens.bg0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
