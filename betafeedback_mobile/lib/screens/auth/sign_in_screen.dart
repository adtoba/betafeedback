import 'package:flutter/material.dart';

import '../../theme/app_layout.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_header.dart';
import '../../widgets/brand_mark.dart';
import '../../widgets/google_logo.dart';

import '../../app/app_scope.dart';
import '../../services/apple_auth_service.dart';
import '../../services/google_auth_service.dart';
import 'verify_code_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _appleAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApple());
  }

  Future<void> _checkApple() async {
    final available = await AppScope.of(context).isAppleSignInAvailable();
    if (!mounted) return;
    setState(() => _appleAvailable = available);
  }

  Future<void> _continueWithGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await AppScope.of(context).signInWithGoogle();
    } on GoogleSignInCancelledException {
      // User closed the account picker.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _continueWithApple() async {
    setState(() => _appleLoading = true);
    try {
      await AppScope.of(context).signInWithApple();
    } on AppleSignInCancelledException {
      // User closed the Apple sheet.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  /// Requests an email code, then advances to the verification screen.
  Future<void> _continueWithEmail(String email) async {
    final debugCode = await AppScope.of(context).requestEmailCode(email);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyCodeScreen(email: email, debugCode: debugCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = _googleLoading || _appleLoading;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              // Fills the viewport so the block sits centred, but grows and
              // scrolls on short screens or at large text sizes.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.narrowMaxWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xxl,
                      AppSpace.xxl,
                      AppSpace.xxl,
                      AppSpace.xl,
                    ),
                    child: Column(
                      // Shrink-wrapped and centred, so short screens scroll
                      // instead of squeezing the copy.
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const BrandLockup(),
                        const SizedBox(height: AppSpace.xxl),
                        Text(
                          'Beta feedback that\nturns into fixes.',
                          style: theme.textTheme.displaySmall,
                        ),
                        const SizedBox(height: AppSpace.md),
                        Text(
                          'Collect reports from your testers, triage them into '
                          'bugs, and tell everyone when they ship.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpace.xxl),
                        _EmailSection(onSubmit: busy ? null : _continueWithEmail),
                        const SizedBox(height: AppSpace.xl),
                        const LabeledRule('or'),
                        const SizedBox(height: AppSpace.lg),
                        _GoogleButton(
                          loading: _googleLoading,
                          onPressed: busy ? null : _continueWithGoogle,
                        ),
                        if (_appleAvailable) ...[
                          const SizedBox(height: AppSpace.sm + 2),
                          _AppleButton(
                            loading: _appleLoading,
                            onPressed: busy ? null : _continueWithApple,
                          ),
                        ],
                        const SizedBox(height: AppSpace.xl),
                        const _LegalNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text.rich(
      textAlign: TextAlign.center,
      TextSpan(
        text: 'By continuing you agree to our ',
        children: const [
          TextSpan(
            text: 'Terms',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: '.'),
        ],
      ),
      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
    );
  }
}

class _EmailSection extends StatefulWidget {
  const _EmailSection({required this.onSubmit});

  /// Called with a validated email; may throw to surface a server error.
  /// Null when another sign-in method is busy.
  final Future<void> Function(String email)? onSubmit;

  @override
  State<_EmailSection> createState() => _EmailSectionState();
}

class _EmailSectionState extends State<_EmailSection> {
  final _controller = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _submit() async {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null) return;
    final email = _controller.text.trim();
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await onSubmit(email);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _submitting || widget.onSubmit == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: !disabled,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.go,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            hintText: 'you@yourcompany.com',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpace.sm + 2),
        FilledButton(
          onPressed: disabled ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text('Email me a sign-in code'),
        ),
      ],
    );
  }
}

/// Google's guidelines ask for their mark on a neutral surface.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: _ButtonRow(
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            : const GoogleLogo(size: 18),
        label: 'Continue with Google',
      ),
    );
  }
}

/// Sign in with Apple HIG: black on light backgrounds, white on dark.
class _AppleButton extends StatelessWidget {
  const _AppleButton({required this.onPressed, required this.loading});

  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? Colors.white : const Color(0xFF16171A);
    final foreground = isDark ? const Color(0xFF16171A) : Colors.white;

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background.withValues(alpha: 0.55),
        disabledForegroundColor: foreground.withValues(alpha: 0.7),
        shadowColor: Colors.transparent,
      ),
      child: _ButtonRow(
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: foreground,
                ),
              )
            : Icon(Icons.apple, size: 21, color: foreground),
        label: 'Continue with Apple',
      ),
    );
  }
}

/// Keeps the label optically centered while the glyph stays pinned left.
class _ButtonRow extends StatelessWidget {
  const _ButtonRow({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 22, height: 22, child: Center(child: icon)),
        ),
        Text(label),
      ],
    );
  }
}
