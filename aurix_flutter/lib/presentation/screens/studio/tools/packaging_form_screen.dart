import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/studio_ai_tool_wizard_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/packaging_tool_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PackagingFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const PackagingFormScreen({super.key, required this.release});

  @override
  ConsumerState<PackagingFormScreen> createState() => _PackagingFormScreenState();
}

class _PackagingFormScreenState extends ConsumerState<PackagingFormScreen> {
  @override
  Widget build(BuildContext context) {
    return StudioAiToolWizardScreen(
      release: widget.release,
      config: packagingToolConfig,
    );
  }
}
