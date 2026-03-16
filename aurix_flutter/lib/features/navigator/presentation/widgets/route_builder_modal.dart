import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/features/navigator/presentation/widgets/navigator_route_builder_sheet.dart';

Future<void> showRouteBuilderModal(BuildContext context, WidgetRef ref) {
  return showNavigatorRouteBuilderSheet(context, ref);
}
