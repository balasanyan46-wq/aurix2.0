import 'package:flutter/material.dart';
import 'package:aurix_flutter/features/production/presentation/production_page.dart';

/// Backward-compatible route wrapper:
/// `/team` now opens Production control center.
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) => const ProductionPage();
}
