import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Brand palette.
///
/// The neutrals are deliberately warm — paper in light mode, soot in dark —
/// so the blue reads as ink on paper rather than as a stock system accent.
abstract final class AppColors {
  // Brand blue: deeper and slightly cooler than the platform default.
  static const Color blue = Color(0xFF1256E0);
  static const Color blueDark = Color(0xFF5C97FF);

  static const Color violet = Color(0xFF5B4BE1);
  static const Color violetDark = Color(0xFF9B8CFF);

  static const Color green = Color(0xFF16875A);
  static const Color greenDark = Color(0xFF3FCB84);

  static const Color amber = Color(0xFFB0700C);
  static const Color amberDark = Color(0xFFE7A93F);

  static const Color red = Color(0xFFD23F31);
  static const Color redDark = Color(0xFFFF6B5E);

  // Light neutrals.
  static const Color paper = Color(0xFFF5F4F1);
  static const Color card = Color(0xFFFFFFFF);
  static const Color sunken = Color(0xFFEBE9E4);
  static const Color ink = Color(0xFF16171A);
  static const Color inkMuted = Color(0xFF6C6F76);
  static const Color hairline = Color(0xFFE0DED8);

  // Dark neutrals.
  static const Color soot = Color(0xFF0B0C0E);
  static const Color cardDark = Color(0xFF16181C);
  static const Color sunkenDark = Color(0xFF202328);
  static const Color inkDark = Color(0xFFF3F3F1);
  static const Color inkMutedDark = Color(0xFF9A9CA3);
  static const Color hairlineDark = Color(0xFF2A2D33);
}

/// Tones the Material [ColorScheme] has no slot for: hairline rules, sunken
/// fills, the amber "needs attention" accent, and the unread dot.
@immutable
class AppTones extends ThemeExtension<AppTones> {
  const AppTones({
    required this.hairline,
    required this.sunken,
    required this.canvas,
    required this.warning,
    required this.warningContainer,
    required this.unread,
  });

  final Color hairline;
  final Color sunken;
  final Color canvas;
  final Color warning;
  final Color warningContainer;
  final Color unread;

  static AppTones of(BuildContext context) =>
      Theme.of(context).extension<AppTones>() ?? _fallback;

  static const _fallback = AppTones(
    hairline: AppColors.hairline,
    sunken: AppColors.sunken,
    canvas: AppColors.paper,
    warning: AppColors.amber,
    warningContainer: Color(0x1AB0700C),
    unread: AppColors.red,
  );

  @override
  AppTones copyWith({
    Color? hairline,
    Color? sunken,
    Color? canvas,
    Color? warning,
    Color? warningContainer,
    Color? unread,
  }) {
    return AppTones(
      hairline: hairline ?? this.hairline,
      sunken: sunken ?? this.sunken,
      canvas: canvas ?? this.canvas,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      unread: unread ?? this.unread,
    );
  }

  @override
  AppTones lerp(AppTones? other, double t) {
    if (other == null) return this;
    return AppTones(
      hairline: Color.lerp(hairline, other.hairline, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      unread: Color.lerp(unread, other.unread, t)!,
    );
  }
}

/// Light and dark themes with a shared brand look and platform-native behavior.
class AppTheme {
  static bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  static ThemeData light() => _material(Brightness.light);
  static ThemeData dark() => _material(Brightness.dark);

  static CupertinoThemeData cupertino(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return CupertinoThemeData(
      brightness: brightness,
      primaryColor: isDark ? AppColors.blueDark : AppColors.blue,
      scaffoldBackgroundColor: isDark ? AppColors.soot : AppColors.paper,
      barBackgroundColor: isDark ? AppColors.cardDark : AppColors.card,
      applyThemeToAll: true,
    );
  }

  static ThemeData _material(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final isApple = _isApple;
    final scheme = _scheme(brightness);
    final tones = _tones(brightness);
    final text = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      platform: isApple ? TargetPlatform.iOS : TargetPlatform.android,
      colorScheme: scheme,
      scaffoldBackgroundColor: tones.canvas,
      canvasColor: tones.canvas,
      extensions: [tones],
      textTheme: text,
      primaryTextTheme: text,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: tones.canvas,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium,
        toolbarHeight: 52,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.primary, size: 22),
      ),
      pageTransitionsTheme: isApple
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              },
            )
          : null,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: isDark ? AppColors.cardDark : AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: tones.hairline, width: AppStroke.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.3),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.6),
          elevation: 0,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 52),
        extendedPadding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
        extendedTextStyle: text.labelLarge,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          side: BorderSide(color: tones.hairline, width: AppStroke.thin),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
          minimumSize: const Size(0, 40),
          textStyle: text.titleSmall,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          highlightColor: scheme.primary.withValues(alpha: 0.08),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.cardDark : AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg,
          vertical: AppSpace.md + 2,
        ),
        hintStyle: text.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: text.labelMedium?.copyWith(color: scheme.primary),
        border: _inputBorder(tones.hairline, AppStroke.thin),
        enabledBorder: _inputBorder(tones.hairline, AppStroke.thin),
        focusedBorder: _inputBorder(scheme.primary, AppStroke.focus),
        errorBorder: _inputBorder(scheme.error, AppStroke.thin),
        focusedErrorBorder: _inputBorder(scheme.error, AppStroke.focus),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: tones.hairline, width: AppStroke.thin),
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        checkmarkColor: scheme.primary,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        labelStyle: text.titleSmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        elevation: 0,
        height: 62,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            size: 23,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: tones.canvas,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
        dragHandleSize: const Size(36, 4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.cardDark : AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark ? AppColors.cardDark : AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.18),
        textStyle: text.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: tones.hairline, width: AppStroke.hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        elevation: 4,
        insetPadding: const EdgeInsets.all(AppSpace.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tones.hairline,
        space: AppStroke.hairline,
        thickness: AppStroke.hairline,
      ),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearMinHeight: 3,
        linearTrackColor: tones.sunken,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
        iconColor: scheme.primary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return tones.sunken;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      splashFactory: isApple ? NoSplash.splashFactory : null,
      highlightColor: isApple ? scheme.primary.withValues(alpha: 0.06) : null,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  /// Type scale built on the platform UI font. Large sizes get negative
  /// tracking so headings read tight and intentional instead of default.
  static TextTheme _textTheme(ColorScheme scheme) {
    final ink = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 40,
        height: 1.05,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
        color: ink,
      ),
      displayMedium: TextStyle(
        fontSize: 36,
        height: 1.06,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        color: ink,
      ),
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.08,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
        color: ink,
      ),
      headlineLarge: TextStyle(
        fontSize: 28,
        height: 1.12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        height: 1.16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: ink,
      ),
      headlineSmall: TextStyle(
        fontSize: 21,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        height: 1.22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: ink,
      ),
      titleSmall: TextStyle(
        fontSize: 15,
        height: 1.28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 17,
        height: 1.38,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.3,
        color: ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 15,
        height: 1.44,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.1,
        color: ink,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.38,
        fontWeight: FontWeight.w400,
        color: muted,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      // Eyebrow / section headers — uppercase, wide tracking.
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: muted,
      ),
    );
  }

  static AppTones _tones(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppTones(
      hairline: isDark ? AppColors.hairlineDark : AppColors.hairline,
      sunken: isDark ? AppColors.sunkenDark : AppColors.sunken,
      canvas: isDark ? AppColors.soot : AppColors.paper,
      warning: isDark ? AppColors.amberDark : AppColors.amber,
      warningContainer: (isDark ? AppColors.amberDark : AppColors.amber)
          .withValues(alpha: isDark ? 0.22 : 0.12),
      unread: isDark ? AppColors.redDark : AppColors.red,
    );
  }

  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? AppColors.blueDark : AppColors.blue;
    final violet = isDark ? AppColors.violetDark : AppColors.violet;
    final green = isDark ? AppColors.greenDark : AppColors.green;
    final error = isDark ? AppColors.redDark : AppColors.red;
    final containerAlpha = isDark ? 0.22 : 0.12;

    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primary.withValues(alpha: containerAlpha),
      onPrimaryContainer: primary,
      secondary: violet,
      onSecondary: Colors.white,
      secondaryContainer: violet.withValues(alpha: containerAlpha),
      onSecondaryContainer: violet,
      tertiary: green,
      onTertiary: Colors.white,
      tertiaryContainer: green.withValues(alpha: containerAlpha),
      onTertiaryContainer: green,
      error: error,
      onError: Colors.white,
      errorContainer: error.withValues(alpha: containerAlpha),
      onErrorContainer: error,
      surface: isDark ? AppColors.cardDark : AppColors.card,
      onSurface: isDark ? AppColors.inkDark : AppColors.ink,
      surfaceContainerLowest: isDark ? AppColors.soot : AppColors.paper,
      surfaceContainerLow: isDark ? AppColors.soot : AppColors.paper,
      surfaceContainer: isDark ? AppColors.cardDark : AppColors.card,
      surfaceContainerHigh: isDark ? AppColors.sunkenDark : AppColors.sunken,
      surfaceContainerHighest: isDark ? AppColors.sunkenDark : AppColors.sunken,
      onSurfaceVariant: isDark ? AppColors.inkMutedDark : AppColors.inkMuted,
      outline: isDark ? AppColors.hairlineDark : AppColors.hairline,
      outlineVariant: isDark ? AppColors.hairlineDark : AppColors.hairline,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: isDark
          ? const Color(0xFFF3F3F1)
          : const Color(0xFF23252A),
      onInverseSurface: isDark ? AppColors.ink : Colors.white,
      inversePrimary: isDark ? AppColors.blue : AppColors.blueDark,
      surfaceTint: Colors.transparent,
    );
  }
}
