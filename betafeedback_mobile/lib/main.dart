import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_scope.dart';
import 'data/app_state.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_config.dart';
import 'theme/app_icons.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  final appState = AppState();
  appState.pushService.navigatorKey = _navigatorKey;
  runApp(BetaFeedbackApp(appState: appState));
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
        navigatorKey: _navigatorKey,
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
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(AppIcons.brand, color: Colors.white, size: 29),
            ),
            const SizedBox(height: AppSpace.lg),
            Text('BetaFeedback', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
