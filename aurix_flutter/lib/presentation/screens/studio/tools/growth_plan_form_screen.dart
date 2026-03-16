import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/studio_ai_tool_wizard_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/growth_tool_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GrowthPlanFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const GrowthPlanFormScreen({super.key, required this.release});

  @override
  ConsumerState<GrowthPlanFormScreen> createState() => _GrowthPlanFormScreenState();
}

class _GrowthPlanFormScreenState extends ConsumerState<GrowthPlanFormScreen> {
  @override
  Widget build(BuildContext context) {
    return StudioAiToolWizardScreen(
      release: widget.release,
      config: growthToolConfig,
    );
  }
}
