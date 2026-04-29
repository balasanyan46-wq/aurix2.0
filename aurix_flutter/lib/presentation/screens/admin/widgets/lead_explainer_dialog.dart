import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';

/// Lead Explainer — диалог "Почему этот лид горячий?".
///
/// Источник: GET /admin/leads/:id/explain.
/// Показывает: score breakdown, recent events, next action, AI signal.
///
/// Используется как из Leads tab, так и из user detail screen.
class LeadExplainerDialog extends ConsumerWidget {
  const LeadExplainerDialog({super.key, required this.leadId});
  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminLeadExplainProvider(leadId));

    return Dialog(
      backgroundColor: AurixTokens.bg1,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: dataAsync.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.danger)),
          ),
          data: (data) {
            if (data == null) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Lead не найден', style: TextStyle(color: AurixTokens.muted)),
              );
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(data: data),
                  const SizedBox(height: 20),
                  _ScoreSection(data: data),
                  const SizedBox(height: 20),
                  _NextActionSection(data: data),
                  const SizedBox(height: 20),
                  if (data.aiSignal != null) ...[
                    _AiSignalSection(data: data),
                    const SizedBox(height: 20),
                  ],
                  _EventsSection(data: data),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final LeadExplain data;

  @override
  Widget build(BuildContext context) {
    final color = switch (data.bucket) {
      'hot' => AurixTokens.danger,
      'warm' => AurixTokens.orange,
      _ => AurixTokens.muted,
    };
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.psychology_rounded, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ПОЧЕМУ ЭТОТ ЛИД ГОРЯЧИЙ', style: TextStyle(
                color: AurixTokens.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              )),
              const SizedBox(height: 4),
              Text(
                data.profile?['email']?.toString() ?? 'user#${data.lead.userId}',
                style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              if (data.profile?['plan'] != null)
                Text(
                  'План: ${data.profile?['plan']} · подписка: ${data.profile?['subscription_status'] ?? 'none'}',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${data.score}',
              style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900),
            ),
            Text(
              data.bucket.toUpperCase(),
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScoreSection extends StatelessWidget {
  const _ScoreSection({required this.data});
  final LeadExplain data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('РАЗБИВКА SCORE', style: TextStyle(
          color: AurixTokens.muted, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.5,
        )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AurixTokens.bg0.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: data.reasons.map((r) {
              final detected = r['detected'] == true;
              final pts = (r['points'] as num?)?.toInt() ?? 0;
              final rule = r['rule']?.toString() ?? '';
              final color = !detected
                  ? AurixTokens.muted
                  : (pts > 0 ? AurixTokens.positive : AurixTokens.danger);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      detected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 14,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rule,
                        style: TextStyle(
                          color: detected ? AurixTokens.text : AurixTokens.muted,
                          fontSize: 12,
                          fontWeight: detected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                    Text(
                      pts > 0 ? '+$pts' : '$pts',
                      style: TextStyle(
                        color: detected ? color : AurixTokens.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        fontFeatures: AurixTokens.tabularFigures,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _NextActionSection extends StatelessWidget {
  const _NextActionSection({required this.data});
  final LeadExplain data;

  @override
  Widget build(BuildContext context) {
    final next = data.nextAction;
    if (next == null || next.action == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('РЕКОМЕНДОВАННОЕ ДЕЙСТВИЕ', style: TextStyle(
          color: AurixTokens.muted, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.5,
        )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AurixTokens.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(next.action!, style: const TextStyle(
                color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 4),
              Text(next.reason, style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
              if (next.possibleRevenue > 0) ...[
                const SizedBox(height: 6),
                Text('Возможный доход: ${next.possibleRevenue} ₽',
                    style: const TextStyle(color: AurixTokens.positive, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
              if (next.suggestedMessage != null && next.suggestedMessage!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AurixTokens.bg0.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(next.suggestedMessage!, style: const TextStyle(
                    color: AurixTokens.textSecondary, fontSize: 12, height: 1.4,
                  )),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AiSignalSection extends StatelessWidget {
  const _AiSignalSection({required this.data});
  final LeadExplain data;

  @override
  Widget build(BuildContext context) {
    final s = data.aiSignal!;
    final signal = s['sales_signal']?.toString() ?? 'low';
    final offer = s['product_offer']?.toString();
    final color = switch (signal) {
      'high' => AurixTokens.danger,
      'medium' => AurixTokens.orange,
      _ => AurixTokens.muted,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('AI SALES СИГНАЛ', style: TextStyle(
            color: AurixTokens.muted, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.5,
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(signal.toUpperCase(), style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w800,
            )),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AurixTokens.bg0.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s['insight'] != null)
                Text(s['insight'].toString(), style: const TextStyle(
                  color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600,
                )),
              if (s['recommendation'] != null) ...[
                const SizedBox(height: 6),
                Text(s['recommendation'].toString(), style: const TextStyle(
                  color: AurixTokens.textSecondary, fontSize: 12, height: 1.4,
                )),
              ],
              if (offer != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AurixTokens.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Оффер: $offer', style: const TextStyle(
                    color: AurixTokens.orange, fontSize: 10, fontWeight: FontWeight.w800,
                  )),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EventsSection extends StatelessWidget {
  const _EventsSection({required this.data});
  final LeadExplain data;

  @override
  Widget build(BuildContext context) {
    if (data.recentEvents.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ПОСЛЕДНИЕ СОБЫТИЯ', style: TextStyle(
          color: AurixTokens.muted, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.5,
        )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AurixTokens.bg0.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: data.recentEvents.take(10).map((e) {
              final event = e['event']?.toString() ?? '';
              final created = e['created_at']?.toString() ?? '';
              final dateStr = created.split('T').first;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(dateStr,
                        style: const TextStyle(
                          color: AurixTokens.muted,
                          fontSize: 11,
                          fontFeatures: AurixTokens.tabularFigures,
                        )),
                    const SizedBox(width: 10),
                    Expanded(child: Text(event, style: const TextStyle(
                      color: AurixTokens.text, fontSize: 12,
                    ))),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
