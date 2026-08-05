import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app_scope.dart';
import 'data/app_state.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_config.dart';
import 'services/deep_link_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/brand_mark.dart';

final _navigatorKey = GlobalKey<NavigatorState>();
final _deepLinks = DeepLinkService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.load();
  final appState = AppState();
  appState.pushService.navigatorKey = _navigatorKey;
  _deepLinks.navigatorKey = _navigatorKey;
  _deepLinks.joinWithCode = (code) async {
    final project = await appState.joinWithInviteCode(code);
    return project.id;
  };
  await _deepLinks.start();
  runApp(BetaFeedbackApp(appState: appState, deepLinks: _deepLinks));
}

class BetaFeedbackApp extends StatefulWidget {
  BetaFeedbackApp({
    super.key,
    required this.appState,
    DeepLinkService? deepLinks,
  }) : deepLinks = deepLinks ?? DeepLinkService();

  final AppState appState;
  final DeepLinkService deepLinks;

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
    widget.deepLinks.dispose();
    super.dispose();
  }

  /// Rebuild [MaterialApp] only when theme changes — not on every cache update.
  /// Also gates deep-link navigation on signed-in bootstrap.
  void _onAppStateChanged() {
    final ready =
        widget.appState.isBootstrapped && widget.appState.isSignedIn;
    widget.deepLinks.setNavigationReady(ready);

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
            BrandMark(size: 56, borderRadius: AppRadius.md),
            const SizedBox(height: AppSpace.lg),
            Text('BetaFeedback', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
