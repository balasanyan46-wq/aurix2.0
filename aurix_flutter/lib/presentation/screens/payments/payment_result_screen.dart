import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/services/billing_service.dart';

/// Post-payment screen. T-Bank redirects here after payment.
///
/// Query params:
///   ?orderId=sub_1_start_1234567890&status=success
///
/// Flow:
///   1. Read orderId from URL
///   2. Poll GET /payments/check?orderId=...
///   3. Show confirmed / pending / failed state
class PaymentResultScreen extends ConsumerStatefulWidget {
  final String? orderId;
  final String? urlStatus;

  const PaymentResultScreen({super.key, this.orderId, this.urlStatus});

  @override
  ConsumerState<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends ConsumerState<PaymentResultScreen> {
  final _billing = BillingService();

  _ResultState _state = _ResultState.loading;
  String? _plan;
  String? _errorMessage;
  int _pollCount = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkPayment();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPayment() async {
    final orderId = widget.orderId;

    // No orderId — use the URL status hint
    if (orderId == null || orderId.isEmpty) {
      setState(() {
        _state = widget.urlStatus == 'success'
            ? _ResultState.confirmed
            : _ResultState.failed;
      });
      return;
    }

    final data = await _billing.checkPayment(orderId);
    if (!mounted) return;

    if (data == null) {
      setState(() {
        _state = _ResultState.failed;
        _errorMessage = 'Не удалось проверить статус платежа';
      });
      return;
    }

    final status = data['status'] as String? ?? '';
    _plan = _planLabel(data['plan'] as String?);

    if (status == 'confirmed') {
      setState(() => _state = _ResultState.confirmed);
    } else if (status == 'failed') {
      setState(() => _state = _ResultState.failed);
    } else {
      // pending — start polling
      setState(() => _state = _ResultState.pending);
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      _pollCount++;
      if (_pollCount > 5) {
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _state = _ResultState.pending;
            // Stay on pending — payment may still process via webhook
          });
        }
        return;
      }

      final data = await _billing.checkPayment(widget.orderId!);
      if (!mounted) return;

      final status = data?['status'] as String? ?? '';
      if (status == 'confirmed') {
        _pollTimer?.cancel();
        _plan = _planLabel(data?['plan'] as String?);
        setState(() => _state = _ResultState.confirmed);
      } else if (status == 'failed') {
        _pollTimer?.cancel();
        setState(() => _state = _ResultState.failed);
      }
    });
  }

  String _planLabel(String? plan) {
    switch (plan) {
      case 'start':
        return 'Старт';
      case 'breakthrough':
        return 'Прорыв';
      case 'empire':
        return 'Империя';
      case 'credits':
        return 'Кредиты';
      default:
        return plan ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AurixTokens.s24),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_state) {
      case _ResultState.loading:
        return _LoadingView();
      case _ResultState.pending:
        return _PendingView(pollCount: _pollCount, onRetry: _checkPayment);
      case _ResultState.confirmed:
        return _SuccessView(plan: _plan, onContinue: () => context.go('/home'));
      case _ResultState.failed:
        return _FailView(
          error: _errorMessage,
          onRetry: () => context.go('/subscription'),
          onHome: () => context.go('/home'),
        );
    }
  }
}

enum _ResultState { loading, pending, confirmed, failed }

// ── Loading ──────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AurixTokens.accent,
          ),
        ),
        const SizedBox(height: AurixTokens.s24),
        Text(
          'Проверяем оплату…',
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            fontSize: 16,
            color: AurixTokens.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Pending ──────────────────────────────────────────

class _PendingView extends StatelessWidget {
  final int pollCount;
  final VoidCallback onRetry;

  const _PendingView({required this.pollCount, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final stillPolling = pollCount <= 5;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AurixTokens.warning.withValues(alpha: 0.12),
          ),
          child: Icon(Icons.schedule_rounded, size: 40, color: AurixTokens.warning),
        ),
        const SizedBox(height: AurixTokens.s24),
        Text(
          'Платёж обрабатывается',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AurixTokens.text,
          ),
        ),
        const SizedBox(height: AurixTokens.s12),
        Text(
          stillPolling
              ? 'Ожидаем подтверждение от банка…'
              : 'Это может занять несколько минут.\nПодписка активируется автоматически.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            fontSize: 14,
            color: AurixTokens.muted,
            height: 1.5,
          ),
        ),
        if (stillPolling) ...[
          const SizedBox(height: AurixTokens.s24),
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AurixTokens.warning),
          ),
        ] else ...[
          const SizedBox(height: AurixTokens.s32),
          _ActionButton(
            label: 'Проверить снова',
            icon: Icons.refresh_rounded,
            color: AurixTokens.accent,
            onTap: onRetry,
          ),
        ],
      ],
    );
  }
}

// ── Success ──────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String? plan;
  final VoidCallback onContinue;

  const _SuccessView({this.plan, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AurixTokens.positive, AurixTokens.positiveGlow],
            ),
            boxShadow: [
              BoxShadow(
                color: AurixTokens.positive.withValues(alpha: 0.3),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.check_rounded, size: 48, color: Colors.white),
        ),
        const SizedBox(height: AurixTokens.s32),
        Text(
          'Оплата прошла!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AurixTokens.text,
          ),
        ),
        const SizedBox(height: AurixTokens.s12),
        if (plan != null && plan!.isNotEmpty)
          Text(
            'Тариф «$plan» активирован',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AurixTokens.fontBody,
              fontSize: 16,
              color: AurixTokens.positive,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: AurixTokens.s8),
        Text(
          'Все возможности тарифа доступны прямо сейчас.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            fontSize: 14,
            color: AurixTokens.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AurixTokens.s40),
        _ActionButton(
          label: 'Перейти в AURIX',
          icon: Icons.arrow_forward_rounded,
          color: AurixTokens.accent,
          onTap: onContinue,
          filled: true,
        ),
      ],
    );
  }
}

// ── Fail ─────────────────────────────────────────────

class _FailView extends StatelessWidget {
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const _FailView({this.error, required this.onRetry, required this.onHome});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AurixTokens.danger.withValues(alpha: 0.12),
          ),
          child: Icon(Icons.close_rounded, size: 48, color: AurixTokens.danger),
        ),
        const SizedBox(height: AurixTokens.s32),
        Text(
          'Оплата не прошла',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontHeading,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AurixTokens.text,
          ),
        ),
        const SizedBox(height: AurixTokens.s12),
        Text(
          error ?? 'Банк отклонил платёж.\nПроверьте данные карты или попробуйте позже.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            fontSize: 14,
            color: AurixTokens.muted,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AurixTokens.s40),
        _ActionButton(
          label: 'Попробовать снова',
          icon: Icons.refresh_rounded,
          color: AurixTokens.accent,
          onTap: onRetry,
          filled: true,
        ),
        const SizedBox(height: AurixTokens.s16),
        _ActionButton(
          label: 'На главную',
          icon: Icons.home_rounded,
          color: AurixTokens.muted,
          onTap: onHome,
        ),
      ],
    );
  }
}

// ── Button ───────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AurixTokens.radiusField),
                ),
                textStyle: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AurixTokens.radiusField),
                ),
                textStyle: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
    );
  }
}
