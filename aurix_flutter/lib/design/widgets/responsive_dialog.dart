import 'package:flutter/material.dart';
import 'package:aurix_flutter/config/responsive.dart';

/// Wrapper for dialogs that adapts to screen size.
/// Desktop: maxWidth 520, centered.
/// Mobile: width = screenWidth - 32, scrollable.
Widget responsiveDialogContent({
  required BuildContext context,
  required Widget child,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
  return ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: isDesktop ? kDialogMaxWidth : (MediaQuery.sizeOf(context).width - 32),
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    child: SingleChildScrollView(
      child: child,
    ),
  );
}
