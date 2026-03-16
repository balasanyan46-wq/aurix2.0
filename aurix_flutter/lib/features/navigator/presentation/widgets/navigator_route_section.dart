import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_route_step_card.dart';

class NavigatorRouteSection extends StatelessWidget {
  const NavigatorRouteSection({
    super.key,
    required this.routeSteps,
  });

  final List<NavigatorRouteStep> routeSteps;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Твой маршрут на сейчас',
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: isDesktop ? 24 : 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AURIX ведет тебя от понимания к действию: этап за этапом, без информационного шума.',
          style: TextStyle(
            color: AurixTokens.textSecondary,
            fontSize: isDesktop ? 14 : 13,
            height: 1.35,
          ),
        ),
        SizedBox(height: isDesktop ? 14 : 12),
        ...routeSteps.take(6).toList().asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: isDesktop ? 12 : 10),
                child: NavigatorRouteStepCard(
                  step: entry.value,
                  revealDelay: Duration(milliseconds: 40 * entry.key),
                  onAction: () => context.go(entry.value.action.route),
                ),
              ),
            ),
      ],
    );
  }
}
