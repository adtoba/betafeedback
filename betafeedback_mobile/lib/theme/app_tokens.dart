/// Design tokens shared by every screen.
///
/// Layout uses a 4pt base with a deliberately short scale — fewer choices keeps
/// vertical rhythm consistent across screens.
abstract final class AppSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;

  /// Horizontal page gutter for screen content.
  static const double gutter = 16;

  /// Extra bottom padding so scroll content clears a floating action button.
  static const double fabClearance = 96;
}

/// Corner radii. Radius grows with the size of the surface it belongs to, which
/// is what keeps a small pill and a full-width sheet looking related.
abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;

  /// Effectively a pill for any control under ~200pt tall.
  static const double pill = 999;
}

/// Border and separator weights. Hairlines are what read as "drawn" rather
/// than "generated" — they stay under 1pt on every surface.
abstract final class AppStroke {
  static const double hairline = 0.5;
  static const double thin = 1;
  static const double focus = 2;
}

abstract final class AppDuration {
  static const fast = Duration(milliseconds: 140);
  static const medium = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 380);
}
