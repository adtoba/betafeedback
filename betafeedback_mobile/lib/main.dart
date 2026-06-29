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
  @override
  void initState() {
    super.initState();
    widget.appState.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      appState: widget.appState,
      child: ListenableBuilder(
        listenable: widget.appState,
        builder: (context, _) {
          final Widget home;
          if (!widget.appState.isBootstrapped) {
            home = const _SplashScreen();
          } else if (widget.appState.isSignedIn) {
            home = const HomeScreen();
          } else {
            home = const SignInScreen();
          }
          return MaterialApp(
            title: 'BetaFeedback',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: widget.appState.themeMode,
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
            home: home,
          );
        },
      ),
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
