/// A single step in the producer flow.
class FlowStep {
  final String id;
  final String title;
  final String description;
  final String action;
  bool completed;

  FlowStep({
    required this.id,
    required this.title,
    required this.description,
    required this.action,
    this.completed = false,
  });
}

/// All possible flow actions.
abstract class FlowActions {
  static const improveSound = 'improve_sound';
  static const addDouble = 'add_double';
  static const fixTiming = 'fix_timing';
  static const enhanceHook = 'enhance_hook';
  static const autoMix = 'auto_mix';
  static const prepareRelease = 'prepare_release';
}
