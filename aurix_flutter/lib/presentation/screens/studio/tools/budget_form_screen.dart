import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/studio_ai_tool_wizard_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/budget_tool_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BudgetFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const BudgetFormScreen({super.key, required this.release});

  @override
  ConsumerState<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends ConsumerState<BudgetFormScreen> {
  @override
  Widget build(BuildContext context) {
    return StudioAiToolWizardScreen(
      release: widget.release,
      config: budgetToolConfig,
    );
  }
}
