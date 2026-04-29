import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

/// Универсальный диалог подтверждения опасных админ-действий.
///
/// Возвращает Map { 'confirmed': true, 'reason': '<обоснование>' } если
/// админ подтвердил, иначе null.
///
/// Использовать для всех вызовов, которые на бэкенде требуют
/// confirmed=true + reason >= 5 символов:
///   block, unblock, refund, kill-sessions, role-change,
///   ai-actions/apply, mass-notify, reset-limits.
Future<Map<String, dynamic>?> showDangerousActionDialog(
  BuildContext context, {
  required String title,
  required String description,
  String confirmLabel = 'Подтвердить',
  String? defaultReason,
  Color? destructiveColor,
}) async {
  final reasonCtrl = TextEditingController(text: defaultReason ?? '');
  final formKey = GlobalKey<FormState>();
  bool submitting = false;

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text(
          title,
          style: const TextStyle(
            color: AurixTokens.text,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                description,
                style: const TextStyle(
                  color: AurixTokens.muted,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonCtrl,
                style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                maxLines: 2,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: 'Причина (минимум 5 символов)',
                  labelStyle: const TextStyle(color: AurixTokens.muted),
                  filled: true,
                  fillColor: AurixTokens.bg0,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 5) return 'Минимум 5 символов';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: submitting
                ? null
                : () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    setState(() => submitting = true);
                    Navigator.pop(ctx, {
                      'confirmed': true,
                      'reason': reasonCtrl.text.trim(),
                    });
                  },
            style: FilledButton.styleFrom(
              backgroundColor: destructiveColor ?? AurixTokens.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );

  return result;
}
