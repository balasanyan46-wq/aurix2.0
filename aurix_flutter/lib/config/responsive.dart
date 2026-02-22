import 'package:flutter/material.dart';

/// Breakpoint для переключения desktop/mobile layout.
/// < 900: mobile (drawer, compact UI)
/// >= 900: desktop (sidebar, wide layout)
const double kDesktopBreakpoint = 900;

/// Горизонтальный padding для mobile.
const double kMobileHorizontalPadding = 16;

/// Горизонтальный padding для desktop.
const double kDesktopHorizontalPadding = 24;

/// Max width для диалогов на desktop.
const double kDialogMaxWidth = 520;

bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

bool isDesktopWidth(double width) => width >= kDesktopBreakpoint;

double horizontalPadding(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint
        ? kDesktopHorizontalPadding
        : kMobileHorizontalPadding;
