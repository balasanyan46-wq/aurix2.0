import 'package:flutter/material.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';

/// Модал формы заявки на услугу (mock).
class ServiceOrderFormModal extends StatefulWidget {
  final String serviceName;

  const ServiceOrderFormModal({super.key, required this.serviceName});

  @override
  State<ServiceOrderFormModal> createState() => _ServiceOrderFormModalState();
}

class _ServiceOrderFormModalState extends State<ServiceOrderFormModal> {
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _descController = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) Navigator.pop(context);
    });
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
              Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 20),
              Text(L10n.t(context, 'submitted'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }
    return Dialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${L10n.t(context, 'submitRequest')}: ${widget.serviceName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Имя / Name',
                  filled: true,
                  fillColor: AurixTokens.glass(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contactController,
                decoration: InputDecoration(
                  labelText: 'Email / Telegram',
                  filled: true,
                  fillColor: AurixTokens.glass(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Описание / Description',
                  filled: true,
                  fillColor: AurixTokens.glass(0.06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Файл (опц.) / File (optional)',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AurixTokens.glass(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.stroke(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, color: AurixTokens.muted),
                    const SizedBox(width: 12),
                    Text('Перетащите файл или выберите',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AurixButton(
                text: L10n.t(context, 'submitted'),
                icon: Icons.send_rounded,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
