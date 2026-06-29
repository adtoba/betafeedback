import 'package:flutter/material.dart';

/// Breakpoints and layout helpers for phones, tablets, and resizable iPad windows.
abstract final class AppLayout {
  /// Width at which we treat the layout as tablet-sized (iPad portrait, etc.).
  static const double tabletBreakpoint = 600;

  /// Width at which content gets a fixed max width and extra side margin.
  static const double expandedBreakpoint = 840;

  /// Max width for primary reading / form content on large screens.
  static const double contentMaxWidth = 720;

  /// Max width for auth and narrow flows.
  static const double narrowMaxWidth = 420;

  static double widthOf(BuildContext context) => MediaQuery.sizeOf(context).width;

  static bool isTablet(BuildContext context) =>
      widthOf(context) >= tabletBreakpoint;

  static bool isExpanded(BuildContext context) =>
      widthOf(context) >= expandedBreakpoint;

  /// Outer horizontal inset for screen bodies on larger displays.
  static double horizontalInset(BuildContext context) {
    final width = widthOf(context);
    if (width >= expandedBreakpoint) {
      return (width - contentMaxWidth) / 2;
    }
    if (width >= tabletBreakpoint) {
      return 32;
    }
    return 0;
  }

  /// Grid tile width cap — allows more columns as the window grows.
  static double projectGridMaxExtent(BuildContext context) {
    final width = widthOf(context);
    if (width >= expandedBreakpoint) return 260;
    if (width >= tabletBreakpoint) return 240;
    return 220;
  }

  /// Centers and constrains [child] on tablet+ screens.
  static Widget adaptiveBody(BuildContext context, Widget child) {
    final inset = horizontalInset(context);
    if (inset <= 0) return child;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: contentMaxWidth),
          child: child,
        ),
      ),
    );
  }
}
