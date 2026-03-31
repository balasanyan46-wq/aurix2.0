import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/billing_providers.dart';

class CreditsScreen extends ConsumerStatefulWidget {
  const CreditsScreen({super.key});

  @override
  ConsumerState<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends ConsumerState<CreditsScreen> {
  bool _purchasing = false;
  String? _purchaseError;

  void _refresh() {
    ref.invalidate(creditBalanceProvider);
    ref.invalidate(creditTransactionsProvider);
  }

  /// Purchase credits via T-Bank: create payment → redirect to T-Bank → webhook confirms.
  Future<void> _purchase(String packageId) async {
    setState(() {
      _purchasing = true;
      _purchaseError = null;
    });

    try {
      final res = await ApiClient.post('/payments/credits', data: {
        'package': packageId,
      });
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

      if (body['success'] == true && body['data'] != null) {
        final data = Map<String, dynamic>.from(body['data'] as Map);
        final url = data['paymentUrl'] as String?;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception('Не удалось получить ссылку на оплату');
        }
      } else {
        throw Exception(body['error']?.toString() ?? 'Ошибка создания платежа');
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (mounted) setState(() => _purchaseError = msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: $msg'),
          backgroundColor: AurixTokens.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceAsync = ref.watch(creditBalanceProvider);
    final txAsync = ref.watch(creditTransactionsProvider);
    final costsAsync = ref.watch(creditCostsProvider);

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('КРЕДИТЫ', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text), onPressed: _refresh),
        ],
      ),
      body: RefreshIndicator(
        color: AurixTokens.orange,
        onRefresh: () async => _refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Balance card ────────────────────────────
              balanceAsync.when(
                data: (balance) => _BalanceCard(balance: balance),
                loading: () => const _BalanceCard(balance: null),
                error: (_, __) => const _BalanceCard(balance: 0),
              ),

              const SizedBox(height: 24),

              // ── Purchase packages ─────────────────────
              const Text('КУПИТЬ КРЕДИТЫ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              _buildPackages(),

              const SizedBox(height: 24),

              // ── Credit costs ──────────────────────────
              const Text('СТОИМОСТЬ ДЕЙСТВИЙ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              costsAsync.when(
                data: (costs) => _buildCostsCard(costs),
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
                error: (_, __) => _emptyCard('Ошибка загрузки'),
              ),

              const SizedBox(height: 24),

              // ── Transactions ──────────────────────────
              const Text('ИСТОРИЯ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              txAsync.when(
                data: (txs) => _buildTransactions(txs),
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
                error: (_, __) => _emptyCard('Ошибка загрузки'),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPackages() {
    final packages = [
      (id: 'small', credits: 100, price: '490 ₽', label: 'Старт', icon: Icons.flash_on_rounded, color: AurixTokens.muted),
      (id: 'medium', credits: 500, price: '1 990 ₽', label: 'Прорыв', icon: Icons.rocket_launch_rounded, color: AurixTokens.orange),
      (id: 'large', credits: 1000, price: '3 490 ₽', label: 'Империя', icon: Icons.diamond_rounded, color: AurixTokens.accent),
    ];

    return Row(
      children: packages.map((p) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _purchasing ? null : () => _purchase(p.id),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedOpacity(
                opacity: _purchasing ? 0.5 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AurixTokens.bg1.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.color.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(p.icon, size: 28, color: p.color),
                      const SizedBox(height: 8),
                      Text(p.label, style: TextStyle(color: p.color, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${p.credits}', style: const TextStyle(color: AurixTokens.text, fontSize: 24, fontWeight: FontWeight.w800)),
                      const Text('кредитов', style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: p.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _purchasing
                            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.color))
                            : Text(p.price, style: TextStyle(color: p.color, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCostsCard(List<Map<String, dynamic>> costs) {
    if (costs.isEmpty) return _emptyCard('Нет данных');

    return _card(
      child: Column(
        children: costs.map((c) {
          final key = c['action_key']?.toString() ?? '';
          final cost = c['cost'] as int? ?? 0;
          final label = c['label']?.toString() ?? key;
          final icon = switch (key) {
            'ai_chat' => Icons.chat_rounded,
            'ai_cover' => Icons.image_rounded,
            'ai_video' => Icons.videocam_rounded,
            'ai_music' => Icons.music_note_rounded,
            _ => Icons.bolt_rounded,
          };

          return ListTile(
            dense: true,
            leading: Icon(icon, size: 20, color: AurixTokens.accent),
            title: Text(label, style: const TextStyle(color: AurixTokens.text, fontSize: 13)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AurixTokens.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('-$cost', style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactions(List<Map<String, dynamic>> txs) {
    if (txs.isEmpty) return _emptyCard('Нет транзакций');

    return _card(
      child: Column(
        children: txs.take(50).map((t) {
          final amount = t['amount'] as int? ?? 0;
          final balanceAfter = t['balance_after'] as int? ?? 0;
          final reason = t['reason']?.toString() ?? '';
          final created = DateTime.tryParse(t['created_at']?.toString() ?? '');
          final isSpend = amount < 0;

          return ListTile(
            dense: true,
            leading: Icon(
              isSpend ? Icons.remove_circle_outline : Icons.add_circle_outline,
              size: 20,
              color: isSpend ? AurixTokens.danger : AurixTokens.positive,
            ),
            title: Text(reason, style: const TextStyle(color: AurixTokens.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${created != null ? DateFormat('dd.MM HH:mm').format(created) : ''} · Баланс: $balanceAfter',
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
            trailing: Text(
              '${amount > 0 ? '+' : ''}$amount',
              style: TextStyle(
                color: isSpend ? AurixTokens.danger : AurixTokens.positive,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

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
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final int? balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: 0.15),
            AurixTokens.orange.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('БАЛАНС', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          balance == null
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.accent))
            : Text(
                balance.toString(),
                style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          const Text('кредитов', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
