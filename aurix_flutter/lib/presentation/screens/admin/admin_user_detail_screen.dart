import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';

/// Admin user detail screen with profile, actions, sessions, timeline.
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final int userId;
  final String? userName;

  const AdminUserDetailScreen({super.key, required this.userId, this.userName});

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  bool _actionLoading = false;

  void _refresh() {
    ref.invalidate(adminUserDetailProvider(widget.userId));
    ref.invalidate(adminUserEventsProvider(widget.userId));
    ref.invalidate(adminUserSessionsProvider(widget.userId));
    ref.invalidate(adminUserBalanceProvider(widget.userId));
    ref.invalidate(adminUserAiMessagesProvider(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(adminUserDetailProvider(widget.userId));
    final eventsAsync = ref.watch(adminUserEventsProvider(widget.userId));
    final sessionsAsync = ref.watch(adminUserSessionsProvider(widget.userId));

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.userName ?? 'Пользователь #${widget.userId}',
          style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile card ─────────────────────────
            detailAsync.when(
              data: (data) => _buildProfileCard(data),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 20),

            // ── Admin actions row ────────────────────
            detailAsync.when(
              data: (data) => _buildActionButtons(data),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── Sessions ──────────────────────────────
            const Text('СЕССИИ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            sessionsAsync.when(
              data: (sessions) => _buildSessions(sessions),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),

            const SizedBox(height: 24),

            // ── Releases ─────────────────────────────
            detailAsync.when(
              data: (data) => _buildReleasesSection(data),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── Support tickets ──────────────────────
            detailAsync.when(
              data: (data) => _buildTicketsSection(data),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── AI Studio messages ──────────────────
            _buildAiMessagesSection(),

            const SizedBox(height: 24),

            // ── Recent actions (from detail) ─────────
            detailAsync.when(
              data: (data) {
                final actions = (data['recent_actions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                if (actions.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ПОСЛЕДНИЕ ДЕЙСТВИЯ (${actions.length})', style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    _buildTimeline(actions),
                    const SizedBox(height: 24),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            // ── Event timeline (full) ───────────────
            const Text('ПОЛНАЯ ИСТОРИЯ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            eventsAsync.when(
              data: (events) => _buildTimeline(events),
              loading: () => _loading(),
              error: (e, _) => _errorWidget(e.toString()),
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Studio messages section ───────────────────────────

  Widget _buildAiMessagesSection() {
    final aiAsync = ref.watch(adminUserAiMessagesProvider(widget.userId));

    return aiAsync.when(
      data: (messages) {
        if (messages.isEmpty) return const SizedBox.shrink();

        // Group messages by generativeType
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final m in messages) {
          final meta = m['meta'] is Map ? Map<String, dynamic>.from(m['meta'] as Map) : <String, dynamic>{};
          final type = meta['generativeType']?.toString() ?? 'chat';
          (grouped[type] ??= []).add(m);
        }

        final typeLabels = {
          'chat': 'Чат',
          'lyrics': 'Текст',
          'ideas': 'Идеи',
          'reels': 'Reels',
          'dnk': 'DNK',
          'image': 'Обложка',
          'analyze': 'Анализ',
        };

        final typeColors = {
          'chat': AurixTokens.accent,
          'lyrics': const Color(0xFF8B5CF6),
          'ideas': AurixTokens.warning,
          'reels': const Color(0xFFEC4899),
          'dnk': AurixTokens.positive,
          'image': AurixTokens.aiAccent,
          'analyze': AurixTokens.coolUndertone,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI STUDIO (${messages.length} сообщений)', style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 8),

            // Tool type chips
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: grouped.entries.map((e) {
                final color = typeColors[e.key] ?? AurixTokens.muted;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '${typeLabels[e.key] ?? e.key}: ${e.value.length}',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Message list
            _card(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  separatorBuilder: (_, __) => Divider(color: AurixTokens.stroke(0.08), height: 1),
                  itemBuilder: (ctx, i) {
                    final m = messages[i];
                    final role = m['role']?.toString() ?? '';
                    final content = m['content']?.toString() ?? '';
                    final created = DateTime.tryParse(m['created_at']?.toString() ?? '');
                    final meta = m['meta'] is Map ? Map<String, dynamic>.from(m['meta'] as Map) : <String, dynamic>{};
                    final type = meta['generativeType']?.toString() ?? 'chat';
                    final isUser = role == 'user';
                    final color = typeColors[type] ?? AurixTokens.muted;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(
                              color: isUser ? AurixTokens.accent.withValues(alpha: 0.12) : color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
                              size: 14,
                              color: isUser ? AurixTokens.accent : color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isUser ? 'Пользователь' : 'AI',
                                      style: TextStyle(color: isUser ? AurixTokens.accent : color, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: Text(typeLabels[type] ?? type, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
                                    ),
                                    const Spacer(),
                                    if (created != null)
                                      Text(DateFormat('dd.MM HH:mm').format(created), style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  content.length > 500 ? '${content.substring(0, 500)}...' : content,
                                  style: TextStyle(
                                    color: isUser ? AurixTokens.text : AurixTokens.textSecondary,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => _loading(),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  // ── Admin action buttons ─────────────────────────────────

  Widget _buildActionButtons(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>?;
    if (user == null) return const SizedBox.shrink();

    final balanceAsync = ref.watch(adminUserBalanceProvider(widget.userId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Credit balance row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AurixTokens.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 18, color: AurixTokens.orange),
              const SizedBox(width: 8),
              const Text('Кредиты:', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              const SizedBox(width: 6),
              balanceAsync.when(
                data: (b) => Text(b.toString(), style: const TextStyle(color: AurixTokens.orange, fontSize: 18, fontWeight: FontWeight.w800)),
                loading: () => const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
                error: (_, __) => const Text('—', style: TextStyle(color: AurixTokens.orange, fontSize: 18)),
              ),
              const Spacer(),
              SizedBox(
                height: 30,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreditBonusDialog(),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Начислить', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AurixTokens.orange.withValues(alpha: 0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 30,
                child: ElevatedButton.icon(
                  onPressed: () => _showDeductCreditsDialog(),
                  icon: const Icon(Icons.remove_rounded, size: 16),
                  label: const Text('Списать', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AurixTokens.danger.withValues(alpha: 0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionBtn(Icons.notifications_rounded, 'Уведомление', AurixTokens.accent, () => _showSendNotificationDialog()),
            _actionBtn(Icons.support_agent_rounded, 'Тикет', AurixTokens.orange, () => _showCreateTicketDialog()),
            _actionBtn(Icons.card_giftcard_rounded, 'Бонус', AurixTokens.positive, () => _showBonusDialog()),
            _actionBtn(Icons.restart_alt_rounded, 'Сброс лимитов', AurixTokens.muted, () => _doAction('Лимиты сброшены', () async {
              await ApiClient.post('/admin/users/${widget.userId}/reset-limits', data: {});
            })),
            _actionBtn(Icons.block_rounded, 'Заблокировать', AurixTokens.danger, () => _doAction('Пользователь заблокирован', () async {
              await ApiClient.post('/admin/users/${widget.userId}/block', data: {});
            })),
            _actionBtn(Icons.lock_open_rounded, 'Разблокировать', AurixTokens.positive, () => _doAction('Пользователь разблокирован', () async {
              await ApiClient.post('/admin/users/${widget.userId}/unblock', data: {});
            })),
          ],
        ),
      ],
    );
  }

  void _showCreditBonusDialog() {
    final amountCtrl = TextEditingController(text: '50');
    final reasonCtrl = TextEditingController(text: 'Бонус от администратора');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Начислить кредиты', style: TextStyle(color: AurixTokens.text, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(amountCtrl, 'Количество'),
            const SizedBox(height: 10),
            _dialogField(reasonCtrl, 'Причина'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              await _doAction('+$amount кредитов начислено', () async {
                await ApiClient.post('/admin/billing/bonus', data: {
                  'user_id': widget.userId,
                  'amount': amount,
                  'reason': reasonCtrl.text.trim(),
                });
              });
            },
            child: const Text('Начислить', style: TextStyle(color: AurixTokens.orange)),
          ),
        ],
      ),
    );
  }

  void _showDeductCreditsDialog() {
    final amountCtrl = TextEditingController(text: '50');
    final reasonCtrl = TextEditingController(text: 'Списание администратором');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Списать кредиты', style: TextStyle(color: AurixTokens.text, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(amountCtrl, 'Количество'),
            const SizedBox(height: 10),
            _dialogField(reasonCtrl, 'Причина'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount <= 0) return;
              await _doAction('-$amount кредитов списано', () async {
                await ApiClient.post('/admin/billing/deduct', data: {
                  'user_id': widget.userId,
                  'amount': amount,
                  'reason': reasonCtrl.text.trim(),
                });
              });
            },
            child: const Text('Списать', style: TextStyle(color: AurixTokens.danger)),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _actionLoading ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSendNotificationDialog() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String type = 'system';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AurixTokens.bg1,
          title: const Text('Отправить уведомление', style: TextStyle(color: AurixTokens.text, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(titleCtrl, 'Заголовок'),
              const SizedBox(height: 10),
              _dialogField(msgCtrl, 'Сообщение', maxLines: 3),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: AurixTokens.bg2,
                style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                decoration: _dialogDecoration('Тип'),
                items: ['system', 'promo', 'warning', 'success', 'ai'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setDialogState(() => type = v ?? 'system'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _doAction('Уведомление отправлено', () async {
                  await ApiClient.post('/admin/notifications/send', data: {
                    'user_id': widget.userId,
                    'title': titleCtrl.text.trim().isEmpty ? 'Уведомление' : titleCtrl.text.trim(),
                    'message': msgCtrl.text.trim(),
                    'type': type,
                  });
                });
              },
              child: const Text('Отправить', style: TextStyle(color: AurixTokens.accent)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTicketDialog() {
    final subjectCtrl = TextEditingController();
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Создать тикет', style: TextStyle(color: AurixTokens.text, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(subjectCtrl, 'Тема'),
            const SizedBox(height: 10),
            _dialogField(msgCtrl, 'Описание', maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _doAction('Тикет создан', () async {
                await ApiClient.post('/admin/notifications/send', data: {
                  'user_id': widget.userId,
                  'title': 'Создан тикет: ${subjectCtrl.text.trim()}',
                  'message': msgCtrl.text.trim(),
                  'type': 'system',
                });
              });
            },
            child: const Text('Создать', style: TextStyle(color: AurixTokens.accent)),
          ),
        ],
      ),
    );
  }

  void _showBonusDialog() {
    final titleCtrl = TextEditingController(text: 'Бонус от администратора');
    final msgCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Начислить бонус', style: TextStyle(color: AurixTokens.text, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(titleCtrl, 'Заголовок'),
            const SizedBox(height: 10),
            _dialogField(msgCtrl, 'Описание бонуса', maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _doAction('Бонус начислен', () async {
                await ApiClient.post('/admin/notifications/send', data: {
                  'user_id': widget.userId,
                  'title': titleCtrl.text.trim(),
                  'message': msgCtrl.text.trim(),
                  'type': 'success',
                });
              });
            },
            child: const Text('Начислить', style: TextStyle(color: AurixTokens.positive)),
          ),
        ],
      ),
    );
  }

  Future<void> _doAction(String successMsg, Future<void> Function() fn) async {
    setState(() => _actionLoading = true);
    try {
      await fn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ));
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: ${humanizeApiError(e)}'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Widget _dialogField(TextEditingController ctrl, String label, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: AurixTokens.text, fontSize: 13),
      decoration: _dialogDecoration(label),
    );
  }

  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AurixTokens.muted, fontSize: 12),
      filled: true,
      fillColor: AurixTokens.bg0,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.stroke(0.3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.stroke(0.3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AurixTokens.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // ── Sessions section ──────────────────────────────────────

  Widget _buildSessions(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return _emptyCard('Нет записанных сессий');

    return _card(
      child: Column(
        children: sessions.take(10).map((s) {
          final id = s['id'];
          final started = DateTime.tryParse(s['started_at']?.toString() ?? '');
          final duration = s['duration_s'] != null ? (s['duration_s'] is int ? s['duration_s'] as int : int.tryParse(s['duration_s'].toString())) : null;
          final device = s['device']?.toString() ?? '';
          final durStr = duration != null ? '${(duration / 60).toStringAsFixed(0)} мин' : 'активна';

          return ListTile(
            dense: true,
            leading: Icon(Icons.play_circle_outline_rounded, size: 20, color: duration != null ? AurixTokens.muted : AurixTokens.positive),
            title: Text(
              started != null ? DateFormat('dd.MM.yyyy HH:mm').format(started) : 'Сессия #$id',
              style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text('$durStr${device.isNotEmpty ? ' · $device' : ''}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
            trailing: id != null ? IconButton(
              icon: const Icon(Icons.replay_rounded, size: 18, color: AurixTokens.accent),
              tooltip: 'Replay',
              onPressed: () => _showSessionReplay(id is int ? id : int.tryParse(id.toString()) ?? 0),
            ) : null,
          );
        }).toList(),
      ),
    );
  }

  void _showSessionReplay(int sessionId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurixTokens.bg0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Consumer(
          builder: (ctx, ref, _) {
            final replayAsync = ref.watch(adminSessionReplayProvider(sessionId));
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AurixTokens.muted.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('SESSION REPLAY #$sessionId', style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
                const SizedBox(height: 16),
                Expanded(
                  child: replayAsync.when(
                    data: (events) {
                      if (events.isEmpty) return const Center(child: Text('Нет событий сессии', style: TextStyle(color: AurixTokens.muted)));
                      return ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: events.length,
                        itemBuilder: (ctx, i) {
                          final e = events[i];
                          final eventType = e['event_type']?.toString() ?? '';
                          final screen = e['screen']?.toString() ?? '';
                          final action = e['action']?.toString() ?? '';
                          final ts = DateTime.tryParse(e['created_at']?.toString() ?? '');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8, height: 8, margin: const EdgeInsets.only(top: 5),
                                  decoration: BoxDecoration(color: _replayEventColor(eventType), shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(eventType, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                                      if (screen.isNotEmpty) Text(screen, style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                                      if (action.isNotEmpty) Text(action, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                if (ts != null) Text(DateFormat('HH:mm:ss').format(ts), style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
                    error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger, fontSize: 13))),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _replayEventColor(String type) => switch (type) {
    'navigate' => AurixTokens.accent,
    'tap' || 'click' => AurixTokens.positive,
    'scroll' => AurixTokens.muted,
    'input' => AurixTokens.orange,
    'error' => AurixTokens.danger,
    _ => AurixTokens.textSecondary,
  };

  // ── Profile card (same as before) ─────────────────────────

  Widget _buildProfileCard(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>?;
    final profile = data['profile'] as Map<String, dynamic>?;

    if (user == null) return _emptyCard('Пользователь не найден');

    final email = user['email']?.toString() ?? '';
    final created = DateTime.tryParse(user['created_at']?.toString() ?? '');
    final lastLogin = DateTime.tryParse(user['last_login']?.toString() ?? '');
    final verified = user['email_verified'] == true;
    final role = profile?['role']?.toString() ?? 'artist';
    final plan = profile?['plan']?.toString() ?? 'none';
    final status = profile?['account_status']?.toString() ?? 'active';
    final displayName = profile?['display_name']?.toString() ?? profile?['name']?.toString() ?? '';
    final phone = profile?['phone']?.toString() ?? '';
    final city = profile?['city']?.toString() ?? '';

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AurixTokens.accent.withValues(alpha: 0.15),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : email.isNotEmpty ? email[0].toUpperCase() : '?',
                    style: const TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName.isNotEmpty ? displayName : email, style: const TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
                      if (displayName.isNotEmpty) Text(email, style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _badge(role.toUpperCase(), role == 'admin' ? AurixTokens.orange : AurixTokens.muted),
                _badge(_planLabel(plan), AurixTokens.positive),
                _badge(status.toUpperCase(), status == 'active' ? AurixTokens.positive : AurixTokens.danger),
                if (verified) _badge('VERIFIED', AurixTokens.accent) else _badge('UNVERIFIED', AurixTokens.danger),
              ],
            ),
            const SizedBox(height: 12),
            if (phone.isNotEmpty) _infoRow(Icons.phone_outlined, phone),
            if (city.isNotEmpty) _infoRow(Icons.location_on_outlined, city),
            if (created != null) _infoRow(Icons.calendar_today, 'Регистрация: ${DateFormat('dd.MM.yyyy HH:mm').format(created)}'),
            if (lastLogin != null) _infoRow(Icons.login_rounded, 'Последний вход: ${_timeAgo(lastLogin)}')
            else _infoRow(Icons.login_rounded, 'Последний вход: не заходил'),
            _infoRow(Icons.tag, 'ID: ${widget.userId}'),
          ],
        ),
      ),
    );
  }

  Widget _buildReleasesSection(Map<String, dynamic> data) {
    final releases = (data['releases'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (releases.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('РЕЛИЗЫ (${releases.length})', style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: releases.take(10).map((r) {
              final title = r['title']?.toString() ?? '';
              final status = r['status']?.toString() ?? '';
              final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
              return ListTile(
                dense: true,
                leading: Icon(Icons.album_rounded, size: 18, color: _statusColor(status)),
                title: Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _badge(status, _statusColor(status)),
                    if (created != null) ...[
                      const SizedBox(width: 8),
                      Text(DateFormat('dd.MM.yy').format(created), style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketsSection(Map<String, dynamic> data) {
    final tickets = (data['tickets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (tickets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ТИКЕТЫ (${tickets.length})', style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        _card(
          child: Column(
            children: tickets.take(5).map((t) {
              final subject = t['subject']?.toString() ?? '';
              final status = t['status']?.toString() ?? '';
              return ListTile(
                dense: true,
                leading: Icon(Icons.support_agent_rounded, size: 18, color: status == 'open' ? AurixTokens.orange : AurixTokens.muted),
                title: Text(subject, style: const TextStyle(color: AurixTokens.text, fontSize: 13)),
                trailing: _badge(status, status == 'open' ? AurixTokens.orange : AurixTokens.positive),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return _emptyCard('Нет событий');

    return _card(
      child: Column(
        children: events.take(50).map((e) {
          final event = e['event']?.toString() ?? '';
          final created = DateTime.tryParse(e['created_at']?.toString() ?? '');
          final targetType = e['target_type']?.toString() ?? '';
          final targetId = e['target_id']?.toString() ?? '';
          final meta = e['meta'] as Map<String, dynamic>? ?? {};

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AurixTokens.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_eventIcon(event), size: 16, color: AurixTokens.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (targetType.isNotEmpty || targetId.isNotEmpty)
                        Text('$targetType${targetId.isNotEmpty ? ' #$targetId' : ''}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                      if (meta.isNotEmpty)
                        Text(meta.entries.take(3).map((e) => '${e.key}: ${e.value}').join(', '), style: const TextStyle(color: AurixTokens.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (created != null)
                  Text(DateFormat('dd.MM HH:mm').format(created), style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  static IconData _eventIcon(String event) => switch (event) {
    'login' => Icons.login_rounded,
    'register' => Icons.person_add_rounded,
    'release_created' => Icons.album_rounded,
    'release_submitted' => Icons.send_rounded,
    'track_uploaded' => Icons.music_note_rounded,
    'ai_chat' => Icons.smart_toy_rounded,
    'subscription_changed' => Icons.workspace_premium_rounded,
    _ => Icons.bolt_rounded,
  };

  static Color _statusColor(String status) => switch (status) {
    'draft' => AurixTokens.muted,
    'submitted' || 'review' => AurixTokens.orange,
    'approved' || 'live' => AurixTokens.positive,
    'rejected' => AurixTokens.danger,
    _ => AurixTokens.textSecondary,
  };

  static String _planLabel(String plan) => switch (plan) {
    'none' => 'НЕТ ПЛАНА',
    'start' => 'СТАРТ',
    'breakthrough' => 'ПРОРЫВ',
    'empire' => 'ИМПЕРИЯ',
    _ => plan.toUpperCase(),
  };

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  static Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
  );

  static Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 14, color: AurixTokens.muted),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(color: AurixTokens.text, fontSize: 12))),
    ]),
  );

  static Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: AurixTokens.bg1.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AurixTokens.stroke(0.24)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: -10, offset: const Offset(0, 8))],
    ),
    child: child,
  );

  static Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AurixTokens.bg1.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AurixTokens.stroke(0.24)),
    ),
    child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
  );

  static Widget _loading() => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)));

  static Widget _errorWidget(String msg) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Text('Ошибка: $msg', style: const TextStyle(color: AurixTokens.danger, fontSize: 13)),
  );
}
