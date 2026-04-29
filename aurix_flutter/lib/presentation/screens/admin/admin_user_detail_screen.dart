import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/presentation/screens/admin/widgets/confirm_dangerous_dialog.dart';
import 'package:aurix_flutter/presentation/screens/admin/widgets/lead_explainer_dialog.dart';

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
    ref.invalidate(adminUserActivitySummaryProvider(widget.userId));
    ref.invalidate(adminUserLastSessionProvider(widget.userId));
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

            // ── Lead Info ─────────────────────────
            _LeadInfoSection(userId: widget.userId),

            const SizedBox(height: 20),

            // ── AI Dossier ─────────────────────────
            _AiDossierSection(userId: widget.userId),

            const SizedBox(height: 20),

            // ── Admin actions row ────────────────────
            detailAsync.when(
              data: (data) => _buildActionButtons(data),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // ── Activity summary cards ──────────────────
            const Text('АКТИВНОСТЬ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _ActivitySummarySection(userId: widget.userId),

            const SizedBox(height: 24),

            // ── Last session detail ─────────────────────
            const Text('ПОСЛЕДНИЙ ЗАХОД', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 12),
            _LastSessionSection(userId: widget.userId),

            const SizedBox(height: 24),

            // ── Sessions ──────────────────────────────
            const Text('ВСЕ СЕССИИ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
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
            _actionBtn(Icons.restart_alt_rounded, 'Сброс лимитов', AurixTokens.muted, () => _confirmResetLimits()),
            _actionBtn(Icons.block_rounded, 'Заблокировать', AurixTokens.danger, () => _confirmBlock()),
            _actionBtn(Icons.lock_open_rounded, 'Разблокировать', AurixTokens.positive, () => _confirmUnblock()),
            _actionBtn(Icons.edit_rounded, 'Редактировать', AurixTokens.accent, () => _showEditUserDialog(data)),
            _actionBtn(Icons.logout_rounded, 'Выкинуть со всех устройств', AurixTokens.danger, _confirmKillSessions),
          ],
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SAFETY: все опасные действия теперь идут через
  //  showDangerousActionDialog, который требует reason >= 5 символов.
  //  Бэкенд тоже валидирует confirmed=true + reason — диалог обязателен.
  // ════════════════════════════════════════════════════════════════

  Future<void> _confirmKillSessions() async {
    final res = await showDangerousActionDialog(
      context,
      title: 'Выкинуть со всех устройств?',
      description: 'Пользователя разлогинит во всех браузерах и приложениях. Ему нужно будет заново ввести пароль.',
      confirmLabel: 'Выкинуть',
    );
    if (res == null) return;
    await _doAction('Все сессии пользователя завершены', () async {
      await ApiClient.post('/admin/users/${widget.userId}/kill-sessions', data: res);
    });
  }

  Future<void> _confirmBlock() async {
    final res = await showDangerousActionDialog(
      context,
      title: 'Заблокировать пользователя?',
      description: 'Аккаунт будет помечен как suspended. Пользователь не сможет войти в систему.',
      confirmLabel: 'Заблокировать',
    );
    if (res == null) return;
    await _doAction('Пользователь заблокирован', () async {
      await ApiClient.post('/admin/users/${widget.userId}/block', data: res);
    });
  }

  Future<void> _confirmUnblock() async {
    final res = await showDangerousActionDialog(
      context,
      title: 'Разблокировать пользователя?',
      description: 'Аккаунт снова станет активным. Укажите причину разблокировки для аудита.',
      confirmLabel: 'Разблокировать',
      destructiveColor: AurixTokens.positive,
    );
    if (res == null) return;
    await _doAction('Пользователь разблокирован', () async {
      await ApiClient.post('/admin/users/${widget.userId}/unblock', data: res);
    });
  }

  Future<void> _confirmResetLimits() async {
    final res = await showDangerousActionDialog(
      context,
      title: 'Сбросить дневные лимиты?',
      description: 'Дневные лимиты использования сбросятся. Юзер сможет снова потреблять кредиты в обычном объёме.',
      confirmLabel: 'Сбросить',
      destructiveColor: AurixTokens.muted,
    );
    if (res == null) return;
    await _doAction('Лимиты сброшены', () async {
      await ApiClient.post('/admin/users/${widget.userId}/reset-limits', data: res);
    });
  }

  void _showEditUserDialog(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>?;
    final profile = data['profile'] as Map<String, dynamic>?;
    final nameCtrl = TextEditingController(text: profile?['display_name']?.toString() ?? profile?['name']?.toString() ?? user?['name']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: user?['email']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: profile?['phone']?.toString() ?? '');
    String plan = (profile?['plan']?.toString() ?? 'free');
    String role = (profile?['role']?.toString() ?? 'artist');
    String subStatus = (profile?['subscription_status']?.toString() ?? 'none');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          backgroundColor: AurixTokens.bg1,
          title: const Text('Редактировать пользователя', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(nameCtrl, 'Имя / отображаемое имя'),
                const SizedBox(height: 10),
                _dialogField(emailCtrl, 'Email'),
                const SizedBox(height: 10),
                _dialogField(phoneCtrl, 'Телефон'),
                const SizedBox(height: 14),
                _dialogDropdown(
                  label: 'План',
                  value: plan,
                  items: const ['free', 'start', 'breakthrough', 'empire'],
                  onChanged: (v) => setDialog(() => plan = v ?? plan),
                ),
                const SizedBox(height: 10),
                _dialogDropdown(
                  label: 'Статус подписки',
                  value: subStatus,
                  items: const ['none', 'active', 'trial', 'expired', 'canceled'],
                  onChanged: (v) => setDialog(() => subStatus = v ?? subStatus),
                ),
                const SizedBox(height: 10),
                _dialogDropdown(
                  label: 'Роль (только super_admin)',
                  value: role,
                  // Расширенный список ролей под новую модель.
                  // На бэкенде смену роли разрешит только super_admin.
                  items: const [
                    'user', 'artist', 'support', 'moderator',
                    'analyst', 'finance_admin', 'admin', 'super_admin',
                  ],
                  onChanged: (v) => setDialog(() => role = v ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AurixTokens.accent, foregroundColor: Colors.white),
              onPressed: () async {
                final originalRole = (profile?['role']?.toString() ?? 'artist');
                final roleChanged = role != originalRole;

                // Если меняется роль — требуем reason + confirmed.
                Map<String, dynamic>? confirm;
                if (roleChanged) {
                  Navigator.pop(ctx);
                  confirm = await showDangerousActionDialog(
                    context,
                    title: 'Сменить роль на $role?',
                    description: 'Смена роли с "$originalRole" на "$role". Доступно только super_admin. Укажите причину для аудита.',
                    confirmLabel: 'Сменить роль',
                  );
                  if (confirm == null) return;
                } else {
                  Navigator.pop(ctx);
                }

                await _doAction('Профиль обновлён', () async {
                  await ApiClient.dio.patch('/admin/users/${widget.userId}', data: {
                    'name': nameCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'plan': plan,
                    'role': role,
                    'subscriptionStatus': subStatus,
                    if (confirm != null) ...confirm,
                  });
                });
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isDense: true,
      style: const TextStyle(color: AurixTokens.text, fontSize: 13),
      dropdownColor: AurixTokens.bg2,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurixTokens.muted, fontSize: 12),
        filled: true,
        fillColor: AurixTokens.bg2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
      onChanged: onChanged,
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
                // Must match DB CHECK constraint notifications_type_check.
                // Extend here + via migration when adding new categories.
                items: ['system', 'promo', 'warning', 'success', 'ai', 'retention', 'announcement']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
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

// ═══════════════════════════════════════════════════════════════════
// AI Dossier section — admin view of AI-generated artist summary
// ═══════════════════════════════════════════════════════════════════

class _AiDossierSection extends StatefulWidget {
  const _AiDossierSection({required this.userId});
  final int userId;

  @override
  State<_AiDossierSection> createState() => _AiDossierSectionState();
}

class _AiDossierSectionState extends State<_AiDossierSection> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dossier;
  Map<String, dynamic>? _snapshot;
  bool _cached = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await ApiClient.dio.get(
        '/api/ai/admin/artist-dossier/${widget.userId}',
        queryParameters: refresh ? {'refresh': '1'} : null,
      );
      if (!mounted) return;
      final data = resp.data is Map
          ? Map<String, dynamic>.from(resp.data as Map)
          : <String, dynamic>{};
      setState(() {
        _dossier = data['dossier'] is Map
            ? Map<String, dynamic>.from(data['dossier'] as Map)
            : null;
        _snapshot = data['snapshot'] is Map
            ? Map<String, dynamic>.from(data['snapshot'] as Map)
            : null;
        _cached = data['cached'] == true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            AurixTokens.aiAccent.withValues(alpha: 0.16),
            AurixTokens.bg1,
            AurixTokens.accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          if (_loading)
            _buildLoading()
          else if (_error != null)
            _buildError()
          else if (_dossier != null)
            _buildContent()
          else
            _buildEmpty(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [
              AurixTokens.aiAccent,
              AurixTokens.aiAccent.withValues(alpha: 0.6),
            ]),
          ),
          child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'AI Досье',
                    style: TextStyle(
                      color: AurixTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_loading && _cached)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AurixTokens.muted.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'CACHED',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                ],
              ),
              const Text(
                'AI-сводка по артисту на основе всех действий на AURIX',
                style: TextStyle(color: AurixTokens.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Перегенерить',
          onPressed: _loading ? null : () => _load(refresh: true),
          icon: Icon(
            Icons.refresh_rounded,
            color: _loading ? AurixTokens.micro : AurixTokens.aiAccent,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(color: AurixTokens.aiAccent, strokeWidth: 2)),
            SizedBox(height: 10),
            Text('AI собирает досье...', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AurixTokens.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error ?? 'Ошибка',
              style: const TextStyle(color: AurixTokens.danger, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => _load(refresh: true),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Text('Нет данных', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
    );
  }

  Widget _buildContent() {
    final d = _dossier!;
    final summary = (d['summary'] ?? '').toString();
    final narrative = (d['narrative'] ?? '').toString();
    final nextAction = (d['next_action'] ?? '').toString();
    final signals = (d['signals'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final risks = (d['risks'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final kpis = (d['kpis'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AurixTokens.bg2.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: AurixTokens.aiAccent, width: 3)),
            ),
            child: Text(
              summary,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // KPIs
        if (kpis.isNotEmpty) ...[
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 600 ? 4 : 2;
            const gap = 8.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: kpis.map((k) => SizedBox(width: w, child: _kpiCard(k))).toList(),
            );
          }),
          const SizedBox(height: 14),
        ],

        // Narrative
        if (narrative.isNotEmpty) ...[
          const _SectionLabel(text: 'НАРРАТИВ'),
          const SizedBox(height: 6),
          Text(
            narrative,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Signals + Risks side by side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (signals.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'СИГНАЛЫ'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: signals
                          .map((s) => _tag(s, AurixTokens.aiAccent))
                          .toList(),
                    ),
                  ],
                ),
              ),
            if (signals.isNotEmpty && risks.isNotEmpty)
              const SizedBox(width: 16),
            if (risks.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel(text: 'РИСКИ'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: risks
                          .map((s) => _tag(s, AurixTokens.danger))
                          .toList(),
                    ),
                  ],
                ),
              ),
          ],
        ),

        if (nextAction.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AurixTokens.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flag_rounded, color: AurixTokens.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'СЛЕДУЮЩИЙ ШАГ',
                        style: TextStyle(
                          color: AurixTokens.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextAction,
                        style: const TextStyle(
                          color: AurixTokens.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // Activity timeline (collapsible)
        if (_snapshot != null) ...[
          const SizedBox(height: 16),
          _buildTimelineExpander(),
        ],
      ],
    );
  }

  Widget _kpiCard(Map<String, dynamic> k) {
    final kind = (k['kind'] ?? 'neutral').toString();
    final color = switch (kind) {
      'good' => AurixTokens.positive,
      'warn' => AurixTokens.warning,
      'bad' => AurixTokens.danger,
      _ => AurixTokens.muted,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (k['value'] ?? '').toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            (k['label'] ?? '').toString(),
            style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTimelineExpander() {
    final timeline = (_snapshot!['activity_timeline'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        const <Map<String, dynamic>>[];
    if (timeline.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text(
          'Timeline активности',
          style: TextStyle(
            color: AurixTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        iconColor: AurixTokens.muted,
        collapsedIconColor: AurixTokens.muted,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.bg2.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: timeline.take(15).map((e) {
                final at = (e['at'] ?? '').toString();
                DateTime? dt;
                try { dt = DateTime.parse(at).toLocal(); } catch (_) {}
                final type = (e['type'] ?? '').toString();
                final summary = (e['summary'] ?? '').toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          dt != null ? DateFormat('d MMM', 'ru_RU').format(dt) : '',
                          style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(
                        _iconForType(type),
                        color: _colorForType(type),
                        size: 13,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          summary,
                          style: const TextStyle(color: AurixTokens.text, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    return switch (type) {
      'release' => Icons.album_rounded,
      'analysis' => Icons.graphic_eq_rounded,
      'budget_plan' => Icons.savings_rounded,
      'improved' => Icons.auto_fix_high_rounded,
      _ => Icons.circle,
    };
  }

  Color _colorForType(String type) {
    return switch (type) {
      'release' => AurixTokens.accent,
      'analysis' => AurixTokens.aiAccent,
      'budget_plan' => const Color(0xFF22C55E),
      'improved' => AurixTokens.warning,
      _ => AurixTokens.muted,
    };
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AurixTokens.muted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Activity Summary — stat cards + top screens + top actions
// ═══════════════════════════════════════════════════════════════════

class _ActivitySummarySection extends ConsumerWidget {
  final int userId;
  const _ActivitySummarySection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUserActivitySummaryProvider(userId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
      ),
      error: (e, _) => Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
      data: (data) {
        final totals = (data['totals'] as Map?)?.cast<String, dynamic>() ?? {};
        final topScreens = ((data['top_screens'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        final topActions = ((data['top_actions'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
        final daily = ((data['daily_30d'] as List?) ?? [])
            .cast<Map<String, dynamic>>();

        if (totals.isEmpty || (totals['total_sessions'] ?? 0) == 0) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AurixTokens.bg1.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AurixTokens.stroke(0.24)),
            ),
            child: const Center(
              child: Text('Нет данных об активности',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
            ),
          );
        }

        final totalTime = (totals['total_time_s'] as num?)?.toInt() ?? 0;
        final avgSession = (totals['avg_session_s'] as num?)?.toInt() ?? 0;
        final totalSessions = (totals['total_sessions'] as num?)?.toInt() ?? 0;
        final activeDays30 = (totals['active_days_30d'] as num?)?.toInt() ?? 0;
        final lastLogin = DateTime.tryParse(totals['last_login_at']?.toString() ?? '');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 4 stat cards ──
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _statCard('Последний вход', _formatRelative(lastLogin)),
                _statCard('Всего времени', _formatDuration(totalTime)),
                _statCard('Сессий', totalSessions.toString()),
                _statCard('Активных дней (30д)', '$activeDays30 / 30'),
                _statCard('Средняя сессия', _formatDuration(avgSession)),
              ],
            ),
            const SizedBox(height: 16),

            // ── 30-day histogram ──
            if (daily.isNotEmpty) ...[
              _miniBarChart(daily),
              const SizedBox(height: 16),
            ],

            // ── Top screens + top actions in row ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _topList('ЧАЩЕ ВСЕГО ОТКРЫВАЛ', topScreens, 'screen')),
                const SizedBox(width: 10),
                Expanded(child: _topList('ЧАЩЕ ВСЕГО ДЕЛАЛ', topActions, 'action')),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value) => Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg1.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.stroke(0.24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AurixTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: AurixTokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _topList(String label, List<Map<String, dynamic>> items, String keyName) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('—',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
            )
          else
            ...items.take(8).map((e) {
              final name = e[keyName]?.toString() ?? '';
              final hits = (e['hits'] as num?)?.toInt() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AurixTokens.text, fontSize: 12)),
                    ),
                    Text('$hits',
                        style: const TextStyle(
                            color: AurixTokens.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _miniBarChart(List<Map<String, dynamic>> daily) {
    // Build a 30-day array: fill missing days with 0.
    final now = DateTime.now();
    final byDay = <String, int>{};
    for (final row in daily) {
      final d = row['day']?.toString() ?? '';
      final ts = (row['time_s'] as num?)?.toInt() ?? 0;
      final key = d.split('T').first; // yyyy-mm-dd
      byDay[key] = ts;
    }
    final bars = <int>[];
    for (int i = 29; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      bars.add(byDay[key] ?? 0);
    }
    final maxVal = bars.fold<int>(0, (a, b) => b > a ? b : a);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('АКТИВНОСТЬ 30 ДНЕЙ (ВРЕМЯ)',
              style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((v) {
                final frac = maxVal == 0 ? 0.0 : v / maxVal;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: (frac * 46).clamp(v > 0 ? 2 : 0, 46).toDouble(),
                      decoration: BoxDecoration(
                        color: v > 0 ? AurixTokens.accent : AurixTokens.muted.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}с';
    if (seconds < 3600) return '${(seconds / 60).round()}м';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m > 0 ? '${h}ч ${m}м' : '${h}ч';
  }

  String _formatRelative(DateTime? dt) {
    if (dt == null) return '—';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'сейчас';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays < 30) return '${diff.inDays} дн назад';
    return DateFormat('dd.MM.yyyy').format(dt);
  }
}

// ═══════════════════════════════════════════════════════════════════
// Last Session — detailed event-by-event timeline of the last session
// ═══════════════════════════════════════════════════════════════════

class _LastSessionSection extends ConsumerWidget {
  final int userId;
  const _LastSessionSection({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUserLastSessionProvider(userId));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
      ),
      error: (e, _) => Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
      data: (data) {
        final session = (data['session'] as Map?)?.cast<String, dynamic>();
        final events = ((data['events'] as List?) ?? []).cast<Map<String, dynamic>>();

        if (session == null) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AurixTokens.bg1.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AurixTokens.stroke(0.24)),
            ),
            child: const Center(
              child: Text('Пользователь ещё ни разу не заходил',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
            ),
          );
        }

        final started = DateTime.tryParse(session['started_at']?.toString() ?? '');
        final duration = (session['duration_s'] as num?)?.toInt();
        final device = session['device']?.toString() ?? '';
        final ip = session['ip']?.toString() ?? '';

        // Filter out heartbeats for the visible timeline — they're noise.
        final visible = events
            .where((e) => e['event_type'] != 'heartbeat')
            .toList();

        return Container(
          decoration: BoxDecoration(
            color: AurixTokens.bg1.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AurixTokens.stroke(0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Session header
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      duration == null ? Icons.radio_button_checked : Icons.history_rounded,
                      size: 18,
                      color: duration == null ? AurixTokens.positive : AurixTokens.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            started != null ? DateFormat('dd.MM.yyyy HH:mm').format(started) : '—',
                            style: const TextStyle(
                                color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              if (duration != null) _formatDur(duration) else 'в процессе',
                              if (device.isNotEmpty) device,
                              if (ip.isNotEmpty) ip,
                            ].join(' · '),
                            style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text('${visible.length} событий',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                  ],
                ),
              ),
              Divider(color: AurixTokens.stroke(0.15), height: 1),
              // Event timeline
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: Text('Нет событий в этом заходе',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    children: visible.map((e) => _eventTile(e)).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _eventTile(Map<String, dynamic> e) {
    final type = e['event_type']?.toString() ?? '';
    final screen = e['screen']?.toString() ?? '';
    final action = e['action']?.toString() ?? '';
    final ts = DateTime.tryParse(e['created_at']?.toString() ?? '');
    final meta = e['meta'];

    final color = _colorForType(type);
    final label = action.isNotEmpty ? action : (screen.isNotEmpty ? screen : type);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              type,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500)),
                if (type == 'action' && screen.isNotEmpty)
                  Text('на $screen',
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                if (meta != null && meta is Map && meta.isNotEmpty)
                  Text(
                    meta.entries.map((kv) => '${kv.key}: ${kv.value}').join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (ts != null)
            Text(DateFormat('HH:mm:ss').format(ts),
                style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Color _colorForType(String type) => switch (type) {
        'screen' => AurixTokens.accent,
        'screen_exit' => AurixTokens.muted,
        'action' => AurixTokens.positive,
        'error' => AurixTokens.danger,
        _ => AurixTokens.textSecondary,
      };

  String _formatDur(int seconds) {
    if (seconds < 60) return '${seconds}с';
    if (seconds < 3600) return '${(seconds / 60).round()}м';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m > 0 ? '${h}ч ${m}м' : '${h}ч';
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Lead Info section — показывает данные из leads + next_action engine.
//  Источники:
//    - GET /admin/leads (фильтрация по user_id) → активный lead
//    - GET /admin/users/:id/next-action → рекомендованное действие
// ════════════════════════════════════════════════════════════════════════

class _LeadInfoSection extends ConsumerWidget {
  const _LeadInfoSection({required this.userId});
  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leadAsync = ref.watch(adminUserActiveLeadProvider(userId));
    final nextActionAsync = ref.watch(adminUserNextActionProvider(userId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AurixTokens.orange.withValues(alpha: 0.12),
            AurixTokens.orange.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, color: AurixTokens.orange, size: 18),
              const SizedBox(width: 8),
              const Text('LEAD INFO', style: TextStyle(
                color: AurixTokens.orange,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              )),
              const Spacer(),
              // Кнопка "Объяснить" — показывает score breakdown + AI signal.
              // Отображается только если есть активный lead (см. ниже в data builder).
              Builder(builder: (ctx) {
                final lead = ref.watch(adminUserActiveLeadProvider(userId)).valueOrNull;
                if (lead == null) return const SizedBox.shrink();
                return TextButton.icon(
                  icon: const Icon(Icons.psychology_rounded, size: 14, color: AurixTokens.aiAccent),
                  label: const Text('Объяснить', style: TextStyle(color: AurixTokens.aiAccent, fontSize: 11, fontWeight: FontWeight.w700)),
                  onPressed: () => showDialog(
                    context: ctx,
                    builder: (_) => LeadExplainerDialog(leadId: lead.id),
                  ),
                );
              }),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 16, color: AurixTokens.muted),
                onPressed: () {
                  ref.invalidate(adminUserActiveLeadProvider(userId));
                  ref.invalidate(adminUserNextActionProvider(userId));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          leadAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
            ),
            error: (_, __) => const Text('Lead info недоступна', style: TextStyle(color: AurixTokens.muted)),
            data: (lead) {
              if (lead == null) {
                return const Text(
                  'Активного lead\'а нет (score < 70 или уже converted/lost)',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                );
              }
              final bucketColor = switch (lead.leadBucket) {
                'hot' => AurixTokens.danger,
                'warm' => AurixTokens.orange,
                _ => AurixTokens.muted,
              };
              final statusColor = switch (lead.status) {
                'converted' => AurixTokens.positive,
                'in_progress' => AurixTokens.orange,
                'contacted' => AurixTokens.aiAccent,
                _ => AurixTokens.accent,
              };
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _kvBadge('SCORE', '${lead.leadScore}', bucketColor),
                      const SizedBox(width: 8),
                      _kvBadge('BUCKET', lead.leadBucket.toUpperCase(), bucketColor),
                      const SizedBox(width: 8),
                      _kvBadge('STATUS', lead.status, statusColor),
                    ],
                  ),
                  if (lead.assignedTo != null) ...[
                    const SizedBox(height: 8),
                    Text('Менеджер: admin#${lead.assignedTo}',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ],
                  if (lead.nextAction != null && lead.nextAction!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('→ ${lead.nextAction}',
                        style: const TextStyle(
                          color: AurixTokens.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AurixTokens.stroke(0.2)),
          const SizedBox(height: 10),
          // Next Action engine (рекомендация даже если lead'а нет)
          const Text('РЕКОМЕНДАЦИЯ', style: TextStyle(
            color: AurixTokens.muted, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 6),
          nextActionAsync.when(
            loading: () => const SizedBox(height: 16),
            error: (_, __) => const SizedBox.shrink(),
            data: (next) {
              if (next == null || next.action == null) {
                return const Text('Триггеров нет — пользователь в простое',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 12));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    next.action!,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(next.reason,
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                  if (next.possibleRevenue > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Возможный доход: ${next.possibleRevenue} ₽',
                      style: const TextStyle(
                        color: AurixTokens.positive,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (next.suggestedMessage != null && next.suggestedMessage!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AurixTokens.bg0.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        next.suggestedMessage!,
                        style: const TextStyle(
                          color: AurixTokens.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kvBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1,
          )),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w800,
          )),
        ],
      ),
    );
  }
}
