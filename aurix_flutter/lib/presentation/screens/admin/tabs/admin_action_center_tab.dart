import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/presentation/screens/admin/widgets/confirm_dangerous_dialog.dart';

/// Action Center — единый экран "что сделать сегодня".
///
/// Группирует задачи по категориям: Срочно / Деньги / Релизы /
/// Поддержка / Возврат пользователей / Риски.
///
/// Каждая карточка имеет быстрые действия:
///   - Открыть пользователя
///   - Создать тикет
///   - Отправить уведомление
///   - Выдать бонус
///   - Отметить решённым (TODO: backend POST /admin/action-center/resolve)
///
/// Все опасные действия идут через showDangerousActionDialog.
class AdminActionCenterTab extends ConsumerWidget {
  const AdminActionCenterTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acAsync = ref.watch(adminActionCenterProvider);

    return acAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AurixTokens.accent),
      ),
      error: (e, _) => Center(
        child: Text('Ошибка загрузки: $e',
            style: const TextStyle(color: AurixTokens.muted)),
      ),
      data: (data) {
        if (data.total == 0) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminActionCenterProvider),
            child: ListView(
              children: const [
                SizedBox(height: 80),
                Center(
                  child: Text(
                    'Чисто. Сегодня ничего срочного.',
                    style: TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminActionCenterProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(total: data.total, possibleRevenue: data.possibleRevenueTotal),
              const SizedBox(height: 16),
              // "Мои продажи сегодня" — мини-дашборд менеджера. Показывается
              // только тем, у кого есть назначенные leads — иначе пустой блок
              // только захламляет UI.
              const _MySalesPanel(),
              const SizedBox(height: 16),
              if (data.urgent.isNotEmpty)
                _Group(
                  title: 'СРОЧНО',
                  icon: Icons.warning_rounded,
                  color: AurixTokens.danger,
                  items: data.urgent,
                ),
              if (data.money.isNotEmpty)
                _Group(
                  title: 'ДЕНЬГИ',
                  icon: Icons.monetization_on_rounded,
                  color: AurixTokens.orange,
                  items: data.money,
                ),
              if (data.releases.isNotEmpty)
                _Group(
                  title: 'РЕЛИЗЫ',
                  icon: Icons.album_rounded,
                  color: AurixTokens.accent,
                  items: data.releases,
                ),
              if (data.support.isNotEmpty)
                _Group(
                  title: 'ПОДДЕРЖКА',
                  icon: Icons.support_agent_rounded,
                  color: AurixTokens.aiAccent,
                  items: data.support,
                ),
              if (data.retention.isNotEmpty)
                _Group(
                  title: 'ВОЗВРАТ ПОЛЬЗОВАТЕЛЕЙ',
                  icon: Icons.person_add_alt_1_rounded,
                  color: AurixTokens.positive,
                  items: data.retention,
                ),
              if (data.risks.isNotEmpty)
                _Group(
                  title: 'РИСКИ',
                  icon: Icons.security_rounded,
                  color: AurixTokens.danger,
                  items: data.risks,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total, required this.possibleRevenue});
  final int total;
  final int possibleRevenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: 0.2),
            AurixTokens.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard_customize_rounded,
              size: 26, color: AurixTokens.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ЧТО СДЕЛАТЬ СЕГОДНЯ',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total задач · потенциал ${possibleRevenue} ₽',
                  style: const TextStyle(
                    color: AurixTokens.positive,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends ConsumerWidget {
  const _Group({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<ActionItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map((it) => _ActionCard(item: it)),
        ],
      ),
    );
  }
}

class _ActionCard extends ConsumerStatefulWidget {
  const _ActionCard({required this.item});
  final ActionItem item;

  @override
  ConsumerState<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends ConsumerState<_ActionCard> {
  bool _busy = false;

  Color get _priorityColor => switch (widget.item.priority) {
        'critical' => AurixTokens.danger,
        'high' => AurixTokens.orange,
        'medium' => AurixTokens.accent,
        _ => AurixTokens.muted,
      };

  Future<void> _openUser() async {
    final uid = widget.item.userId;
    if (uid == null) return;
    // Маршрут совпадает с тем, что используется в users tab.
    context.push('/admin/users/$uid');
  }

  Future<void> _sendNotification() async {
    final uid = widget.item.userId;
    if (uid == null) return;
    final res = await showDangerousActionDialog(
      context,
      title: 'Отправить уведомление?',
      description:
          'Текст уведомления + причина. Будет отправлено push в приложение и email если SMTP настроен.',
      confirmLabel: 'Отправить',
      destructiveColor: AurixTokens.accent,
    );
    if (res == null) return;
    setState(() => _busy = true);
    try {
      // POST /admin/notifications — body: { user_id, type (transport),
      // title, message, source, confirmed, reason }. Backend сам выбирает
      // dbType (sales/offer/internal) на основе source/meta.
      await ApiClient.post('/admin/notifications', data: {
        'user_id': uid,
        'title': widget.item.title,
        'message': res['reason'], // используем reason как тело
        'type': 'internal',
        'source': 'action_center',
        ...res, // confirmed + reason
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Уведомление отправлено'),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Написать" — отправить заранее подготовленное suggested_message.
  /// Если нет — показывает редактируемый шаблон.
  Future<void> _writeMessage() async {
    final uid = widget.item.userId;
    if (uid == null) return;
    final preset = widget.item.suggestedMessage ?? '';
    final res = await showDangerousActionDialog(
      context,
      title: 'Отправить сообщение артисту?',
      description: preset.isNotEmpty
          ? 'Готовый текст:\n\n$preset\n\nОтредактируйте при необходимости в поле ниже (это и будет тело сообщения).'
          : 'Введите текст сообщения в поле ниже.',
      confirmLabel: 'Отправить',
      destructiveColor: AurixTokens.aiAccent,
      defaultReason: preset,
    );
    if (res == null) return;
    setState(() => _busy = true);
    try {
      await ApiClient.post('/admin/notifications', data: {
        'user_id': uid,
        'title': widget.item.title,
        'message': res['reason'],
        'type': 'internal', // transport: внутренняя in-app
        'source': 'action_center',
        ...res, // confirmed + reason
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Сообщение отправлено'),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// "Отправить оффер" — на основе product_offer / next_action.
  /// Использует тот же notifications endpoint, но помечает type=offer.
  Future<void> _sendOffer() async {
    final uid = widget.item.userId;
    if (uid == null) return;
    final offer = widget.item.productOffer;
    final offerLabel = switch (offer) {
      'analysis_pro' => 'AI-анализ Pro (590 ₽)',
      'distribution' => 'Дистрибуция релиза (от 2990 ₽)',
      'promotion' => 'Promotion Pack (от 9900 ₽)',
      _ => 'Индивидуальный оффер',
    };
    final res = await showDangerousActionDialog(
      context,
      title: 'Отправить оффер: $offerLabel?',
      description: 'Запишите, какой оффер пошёл и что обсудили (для последующего трекинга конверсии).',
      confirmLabel: 'Отправить оффер',
      destructiveColor: AurixTokens.orange,
      defaultReason: widget.item.suggestedMessage,
    );
    if (res == null) return;
    setState(() => _busy = true);
    try {
      await ApiClient.post('/admin/notifications', data: {
        'user_id': uid,
        'title': 'Персональное предложение AURIX',
        'message': res['reason'],
        'type': 'internal', // transport
        'source': 'action_center_offer', // → backend выставит dbType='offer'
        'meta': {'product_offer': offer, 'action_item_id': widget.item.id},
        ...res, // confirmed + reason
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Оффер отправлен'),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createTicket() async {
    final uid = widget.item.userId;
    if (uid == null) return;
    setState(() => _busy = true);
    try {
      // POST /admin/support-tickets — admin endpoint, user_id из body.
      // (Обычный POST /support-tickets берёт user_id из JWT и создаёт тикет
      // от имени админа, что в Action Center неверно.)
      await ApiClient.post('/admin/support-tickets', data: {
        'user_id': uid,
        'subject': widget.item.title,
        'message': widget.item.description,
        'priority': widget.item.priority == 'critical' ? 'high' : 'medium',
        'source': 'action_center',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Тикет создан'),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Не удалось создать тикет: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _giveBonus() async {
    final uid = widget.item.userId;
    if (uid == null) return;
    final res = await showDangerousActionDialog(
      context,
      title: 'Выдать бонус 20 кредитов?',
      description:
          'Укажите причину для аудита. Бонус начисляется на баланс пользователя.',
      confirmLabel: 'Начислить',
      destructiveColor: AurixTokens.positive,
    );
    if (res == null) return;
    setState(() => _busy = true);
    try {
      await ApiClient.post('/admin/billing/bonus', data: {
        'user_id': uid,
        'amount': 20,
        'reason': res['reason'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Бонус начислен'),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg1.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.item.priority.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.title,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.item.description,
              style: const TextStyle(
                color: AurixTokens.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            // Next-action engine: показываем рекомендуемый шаг + потенциальный доход.
            if (widget.item.nextAction != null && widget.item.nextAction!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '→ ${widget.item.nextAction}',
                style: const TextStyle(
                  color: AurixTokens.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (widget.item.possibleRevenue > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Возможный доход: ${widget.item.possibleRevenue} ₽',
                style: const TextStyle(
                  color: AurixTokens.positive,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (widget.item.userId != null)
                  _MiniBtn(
                    label: 'Открыть',
                    icon: Icons.person_rounded,
                    color: AurixTokens.accent,
                    onTap: _busy ? null : _openUser,
                  ),
                if (widget.item.userId != null)
                  _MiniBtn(
                    label: 'Написать',
                    icon: Icons.chat_rounded,
                    color: AurixTokens.aiAccent,
                    onTap: _busy ? null : _writeMessage,
                  ),
                // Кнопка "Оффер" появляется только если есть product_offer
                // или suggested_message — иначе её нечем заполнить.
                if (widget.item.userId != null &&
                    (widget.item.productOffer != null ||
                     widget.item.suggestedMessage != null))
                  _MiniBtn(
                    label: 'Отправить оффер',
                    icon: Icons.local_offer_rounded,
                    color: AurixTokens.orange,
                    onTap: _busy ? null : _sendOffer,
                  ),
                if (widget.item.userId != null)
                  _MiniBtn(
                    label: 'Уведомить',
                    icon: Icons.notifications_rounded,
                    color: AurixTokens.muted,
                    onTap: _busy ? null : _sendNotification,
                  ),
                if (widget.item.userId != null)
                  _MiniBtn(
                    label: 'Тикет',
                    icon: Icons.support_agent_rounded,
                    color: AurixTokens.muted,
                    onTap: _busy ? null : _createTicket,
                  ),
                if (widget.item.userId != null)
                  _MiniBtn(
                    label: '+20 кредитов',
                    icon: Icons.card_giftcard_rounded,
                    color: AurixTokens.positive,
                    onTap: _busy ? null : _giveBonus,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 13),
        label: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.85),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Manager Dashboard — "Мои продажи сегодня"
//  Источник: GET /admin/my-sales-dashboard.
//  Показывается только если у менеджера есть активные leads, иначе пустой
//  блок захламляет Action Center.
// ════════════════════════════════════════════════════════════════════════

class _MySalesPanel extends ConsumerWidget {
  const _MySalesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(adminMySalesDashboardProvider);
    return dashAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (d) {
        // Не показываем, если ни активных, ни недавних действий нет.
        final hasAnything = d.myNewLeads.isNotEmpty ||
            d.myInProgress.isNotEmpty ||
            d.contacted7d > 0 ||
            d.converted7d > 0 ||
            d.lost7d > 0;
        if (!hasAnything) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AurixTokens.aiAccent.withValues(alpha: 0.15),
                AurixTokens.aiAccent.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.person_pin_rounded, color: AurixTokens.aiAccent, size: 20),
                const SizedBox(width: 8),
                const Text('МОИ ПРОДАЖИ СЕГОДНЯ', style: TextStyle(
                  color: AurixTokens.aiAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                )),
                const Spacer(),
                if (d.realRevenue7dRub > 0)
                  Text('${d.realRevenue7dRub} ₽ за 7 дней',
                      style: const TextStyle(
                        color: AurixTokens.positive,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      )),
              ]),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _kpi('NEW', d.myNewLeads.length, AurixTokens.accent),
                  _kpi('В РАБОТЕ', d.myInProgress.length, AurixTokens.orange),
                  _kpi('CONTACTED 7D', d.contacted7d, AurixTokens.aiAccent),
                  _kpi('CONVERTED 7D', d.converted7d, AurixTokens.positive),
                  _kpi('LOST 7D', d.lost7d, AurixTokens.muted),
                ],
              ),
              if (d.estimatedPossibleRevenue > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Потенциал в активных: ${d.estimatedPossibleRevenue} ₽',
                  style: const TextStyle(
                    color: AurixTokens.positive,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _kpi(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            color: AurixTokens.muted, fontSize: 9,
            fontWeight: FontWeight.w800, letterSpacing: 1,
          )),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
