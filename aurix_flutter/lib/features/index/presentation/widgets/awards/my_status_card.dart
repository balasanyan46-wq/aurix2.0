import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_data.dart';

class MyStatusCard extends StatelessWidget {
  final int? myIndex;
  final int? myRank;
  final int? toTop10;
  final VoidCallback? onHowToRise;

  const MyStatusCard({
    super.key,
    this.myIndex,
    this.myRank,
    this.toTop10,
    this.onHowToRise,
  });

  @override
  Widget build(BuildContext context) {
    final hasStatus = myIndex != null || myRank != null;

    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (myIndex != null) ...[
                _Stat('Твой индекс', formatNumber(myIndex!), AurixTokens.orange),
                const SizedBox(width: 32),
              ],
              if (myRank != null) ...[
                _Stat('Место', '#$myRank', AurixTokens.text),
                const SizedBox(width: 32),
              ],
              if (toTop10 != null && toTop10! > 0) ...[
                _Stat('До Top-10', '+$toTop10', Colors.green),
                const SizedBox(width: 32),
              ],
              const Spacer(),
              if (onHowToRise != null)
                FilledButton(
                  onPressed: onHowToRise,
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Как подняться в рейтинге'),
                ),
            ],
          ),
          if (!hasStatus)
            Text(
              'Выберите артиста в разделе Профиль, чтобы увидеть свой статус',
              style: TextStyle(color: AurixTokens.muted, fontSize: 14),
            ),
          const SizedBox(height: 16),
          Text(
            'Индекс обновляется еженедельно. Итог сезона фиксируется 31 декабря.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _Stat(this.label, this.value, this.valueColor);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
