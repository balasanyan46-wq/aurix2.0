import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

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
      await ref.read(supportTicketRepositoryProvider).createTicket(
        userId: user.id,
        subject: 'Заявка на услугу: ${widget.serviceName}',
        message: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : 'Хочу заказать услугу "${widget.serviceName}".',
        priority: 'medium',
      );
      setState(() { _submitted = true; _loading = false; });
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      setState(() { _error = 'Ошибка: $e'; _loading = false; });
    }
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
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 20),
              Text('Заявка отправлена!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: AurixTokens.text)),
              const SizedBox(height: 8),
              Text('Мы свяжемся с вами в ближайшее время.', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
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
              Text('Заявка будет отправлена в поддержку.', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: TextStyle(color: Colors.redAccent, fontSize: 13)),
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
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.send_rounded, size: 18),
                label: const Text('Отправить заявку'),
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.orange,
                  foregroundColor: Colors.black,
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
