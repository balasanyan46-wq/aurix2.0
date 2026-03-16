import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/studio_ai_tool_wizard_screen.dart';
import 'package:aurix_flutter/presentation/screens/studio/tools/tool_configs/pitch_pack_tool_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PitchPackFormScreen extends ConsumerStatefulWidget {
  final ReleaseModel release;
  const PitchPackFormScreen({super.key, required this.release});

  @override
  ConsumerState<PitchPackFormScreen> createState() => _PitchPackFormScreenState();
}

class _PitchPackFormScreenState extends ConsumerState<PitchPackFormScreen> {
  @override
  Widget build(BuildContext context) {
    return StudioAiToolWizardScreen(
      release: widget.release,
      config: pitchPackToolConfig,
    );
  }
}
