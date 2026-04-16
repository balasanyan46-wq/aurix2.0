import 'package:flutter/material.dart';
import 'package:aurix_flutter/features/production/presentation/production_page.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

/// Backward-compatible route wrapper:
/// `/team` now opens Production control center.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SectionOnboarding(tip: OnboardingTips.team),
          ),
          const Expanded(child: ProductionPage()),
        ],
      );
}
