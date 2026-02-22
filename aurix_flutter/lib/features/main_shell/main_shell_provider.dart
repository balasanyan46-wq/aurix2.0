import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Текущая вкладка главного shell (0-4).
/// Используется для переключения вкладок из дочерних экранов.
final mainShellTabProvider = StateProvider<int>((ref) => 0);
