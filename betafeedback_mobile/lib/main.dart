import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_scope.dart';
import 'data/app_state.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_icons.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(BetaFeedbackApp(appState: AppState()));
}

class BetaFeedbackApp extends StatefulWidget {
  const BetaFeedbackApp({super.key, required this.appState});

  final AppState appState;

  @override
  State<BetaFeedbackApp> createState() => _BetaFeedbackAppState();
}

class _BetaFeedbackAppState extends State<BetaFeedbackApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.appState.themeMode;
    widget.appState.addListener(_onAppStateChanged);
    widget.appState.bootstrap();
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  /// Rebuild [MaterialApp] only when theme changes — not on every cache update.
  void _onAppStateChanged() {
    final next = widget.appState.themeMode;
    if (next == _themeMode) return;
    setState(() => _themeMode = next);
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      appState: widget.appState,
      child: MaterialApp(
        title: 'BetaFeedback',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: _themeMode,
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          final content = child ?? const SizedBox.shrink();
          if (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS) {
            return CupertinoTheme(
              data: AppTheme.cupertino(brightness),
              child: content,
            );
          }
          return content;
        },
        home: _AppHome(appState: widget.appState),
      ),
    );
  }
}

/// Switches between splash, sign-in, and the signed-in shell without
/// recreating [MaterialApp] (which would duplicate navigator GlobalKeys).
class _AppHome extends StatelessWidget {
  const _AppHome({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        if (!appState.isBootstrapped) {
          return const _SplashScreen();
        }
        if (appState.isSignedIn) {
          return const HomeScreen();
        }
        return const SignInScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(AppIcons.brand, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}
