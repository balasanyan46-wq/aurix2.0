import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/studio_ai_tool_wizard_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/content_plan_tool_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ContentPlanFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const ContentPlanFormScreen({super.key, required this.release});

  @override
  ConsumerState<ContentPlanFormScreen> createState() => _ContentPlanFormScreenState();
}

class _ContentPlanFormScreenState extends ConsumerState<ContentPlanFormScreen> {
  @override
  Widget build(BuildContext context) {
    return StudioAiToolWizardScreen(
      release: widget.release,
      config: contentPlanToolConfig,
    );
  }
}
