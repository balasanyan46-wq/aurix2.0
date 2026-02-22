import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/enums.dart';

/// Legacy nav provider. Prefer AppState.navigateTo(AppScreen).
final navRouteProvider = StateProvider<AppScreen>((ref) => AppScreen.home);
