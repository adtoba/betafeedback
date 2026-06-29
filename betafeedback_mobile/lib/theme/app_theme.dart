import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared brand colors used on both iOS and Android.
abstract final class AppColors {
  static const Color systemBlue = Color(0xFF007AFF);
  static const Color systemBlueDark = Color(0xFF0A84FF);
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
      primaryColor: isDark ? AppColors.systemBlueDark : AppColors.systemBlue,
      scaffoldBackgroundColor: _groupedBackground(isDark, apple: true),
      barBackgroundColor: _elevatedSurface(isDark, apple: true),
      applyThemeToAll: true,
    );
  }

  static ThemeData _material(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final isApple = _isApple;
    final scheme =
        isApple ? _iosColorScheme(brightness) : _androidColorScheme(brightness);

    return ThemeData(
      useMaterial3: true,
      platform: isApple ? TargetPlatform.iOS : TargetPlatform.android,
      colorScheme: scheme,
      scaffoldBackgroundColor: _groupedBackground(isDark, apple: isApple),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: _groupedBackground(isDark, apple: isApple),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: isApple ? -0.4 : 0,
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        color: _elevatedSurface(isDark, apple: isApple),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.35),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.6),
          elevation: 0,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: isApple ? 2 : 4,
        focusElevation: isApple ? 4 : 6,
        hoverElevation: isApple ? 4 : 6,
        highlightElevation: isApple ? 6 : 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedSizeConstraints:
            const BoxConstraints.tightFor(height: 56),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 24),
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 17),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _fillColor(isDark, apple: isApple),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.14),
        checkmarkColor: scheme.primary,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _elevatedSurface(isDark, apple: isApple),
        elevation: 0,
        height: 64,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: scheme.primary, size: 24);
          }
          return IconThemeData(color: scheme.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: scheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          );
        }),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.5),
        space: 1,
        thickness: 0.5,
      ),
      iconTheme: IconThemeData(
        color: scheme.onSurfaceVariant,
        size: 22,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        iconColor: scheme.primary,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w400,
        ),
        subtitleTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 15,
        ),
      ),
      splashFactory: isApple ? NoSplash.splashFactory : null,
      highlightColor:
          isApple ? scheme.primary.withValues(alpha: 0.08) : null,
    );
  }

  static Color _groupedBackground(bool isDark, {required bool apple}) {
    if (apple) {
      return isDark
          ? CupertinoColors.black
          : CupertinoColors.systemGroupedBackground;
    }
    return isDark ? const Color(0xFF121212) : const Color(0xFFF3F3F3);
  }

  static Color _elevatedSurface(bool isDark, {required bool apple}) {
    if (apple) {
      return isDark
          ? CupertinoColors.secondarySystemGroupedBackground.darkColor
          : CupertinoColors.secondarySystemGroupedBackground;
    }
    return isDark ? const Color(0xFF1E1E1E) : Colors.white;
  }

  static Color _fillColor(bool isDark, {required bool apple}) {
    if (apple) {
      return isDark
          ? CupertinoColors.tertiarySystemFill.darkColor
          : CupertinoColors.tertiarySystemFill;
    }
    return isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
  }

  static ColorScheme _sharedScheme(Brightness brightness, {
    required Color surface,
    required Color onSurface,
    required Color onSurfaceVariant,
    required Color outline,
    required Color surfaceContainer,
  }) {
    final isDark = brightness == Brightness.dark;
    const redLight = Color(0xFFFF3B30);
    const redDark = Color(0xFFFF453A);
    const indigo = Color(0xFF5856D6);
    const green = Color(0xFF34C759);
    final primary =
        isDark ? AppColors.systemBlueDark : AppColors.systemBlue;
    final error = isDark ? redDark : redLight;

    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primary.withValues(alpha: isDark ? 0.28 : 0.14),
      onPrimaryContainer: primary,
      secondary: indigo,
      onSecondary: Colors.white,
      secondaryContainer: indigo.withValues(alpha: isDark ? 0.28 : 0.14),
      onSecondaryContainer: indigo,
      tertiary: green,
      onTertiary: Colors.white,
      tertiaryContainer: green.withValues(alpha: isDark ? 0.28 : 0.14),
      onTertiaryContainer: green,
      error: error,
      onError: Colors.white,
      errorContainer: error.withValues(alpha: isDark ? 0.28 : 0.14),
      onErrorContainer: error,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: surfaceContainer,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.55),
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: isDark ? Colors.white : const Color(0xFF1C1C1E),
      onInverseSurface: isDark ? Colors.black : Colors.white,
      inversePrimary: isDark ? AppColors.systemBlue : AppColors.systemBlueDark,
      surfaceTint: Colors.transparent,
    );
  }

  static ColorScheme _iosColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return _sharedScheme(
      brightness,
      surface: _groupedBackground(isDark, apple: true),
      onSurface:
          isDark ? CupertinoColors.label.darkColor : CupertinoColors.label,
      onSurfaceVariant: isDark
          ? CupertinoColors.secondaryLabel.darkColor
          : CupertinoColors.secondaryLabel,
      outline: isDark
          ? CupertinoColors.separator.darkColor
          : CupertinoColors.separator,
      surfaceContainer: isDark
          ? CupertinoColors.tertiarySystemGroupedBackground.darkColor
          : CupertinoColors.tertiarySystemGroupedBackground,
    );
  }

  static ColorScheme _androidColorScheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return _sharedScheme(
      brightness,
      surface: _groupedBackground(isDark, apple: false),
      onSurface: isDark ? Colors.white : Colors.black87,
      onSurfaceVariant:
          isDark ? Colors.white70 : Colors.black.withValues(alpha: 0.55),
      outline: isDark
          ? Colors.white24
          : Colors.black.withValues(alpha: 0.12),
      surfaceContainer:
          isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE8E8E8),
    );
  }
}
