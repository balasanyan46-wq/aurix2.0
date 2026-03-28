import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class AccountDeletionRequestPage extends ConsumerStatefulWidget {
  const AccountDeletionRequestPage({super.key});

  @override
  ConsumerState<AccountDeletionRequestPage> createState() => _AccountDeletionRequestPageState();
}

class _AccountDeletionRequestPageState extends ConsumerState<AccountDeletionRequestPage> {
  final _reasonController = TextEditingController();
  bool _submitting = false;
  bool _confirmChecked = false;
  bool _submitted = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Запрос на удаление аккаунта',
                    style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w900, fontSize: 30),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'После подтверждения создается запрос со статусом pending. Удаление выполняется после проверки, часть данных может храниться по закону.',
                    style: TextStyle(color: AurixTokens.textSecondary, height: 1.6),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AurixTokens.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.24)),
                    ),
                    child: const Text(
                      'Важно: финансовые и технические данные могут храниться ограниченное время для бухгалтерии, антифрода и разрешения споров.',
                      style: TextStyle(color: AurixTokens.text, height: 1.5),
                    ),
                  ),
                  if (_submitted)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AurixTokens.positive.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.28)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Запрос успешно отправлен',
                            style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Статус запроса: pending. Мы уведомим вас после обработки обращения.',
                            style: TextStyle(color: AurixTokens.textSecondary, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context.go('/settings'),
                            child: const Text('Вернуться в настройки'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _reasonController,
                      minLines: 4,
                      maxLines: 7,
                      decoration: const InputDecoration(
                        labelText: 'Причина (необязательно)',
                        hintText: 'Например: больше не использую сервис, хочу закрыть аккаунт',
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: _confirmChecked,
                      onChanged: (value) => setState(() => _confirmChecked = value ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Подтверждаю, что понимаю последствия удаления аккаунта',
                        style: TextStyle(color: AurixTokens.text),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: (!_confirmChecked || _submitting) ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.text),
                            )
                          : const Icon(Icons.delete_forever_rounded),
                      label: Text(_submitting ? 'Отправляем...' : 'Отправить запрос'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AurixTokens.danger,
                        foregroundColor: AurixTokens.text,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref.read(accountDeletionRequestRepositoryProvider).createRequest(
            reason: _reasonController.text,
          );
      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось отправить запрос: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
