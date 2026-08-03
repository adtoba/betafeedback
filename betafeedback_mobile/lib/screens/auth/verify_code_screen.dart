import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/grouped_list.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';

/// Step two of email sign-in: the user enters the one-time code emailed to
/// their address, which the backend verifies.
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key, required this.email, this.debugCode});

  final String email;

  /// In dev mode the backend returns the code so it can be shown as a hint.
  final String? debugCode;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const _resendSeconds = 30;
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  bool _verifying = false;
  String? _error;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _resend() async {
    _startCountdown();
    try {
      await AppScope.of(context).requestEmailCode(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New code sent to ${widget.email}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _onCompleted(String code) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await AppScope.of(context).verifyEmailCode(widget.email, code);
      // On success the app shell rebuilds to the home screen; pop this route
      // to reveal it.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _verifying = false;
        _attempt++; // forces a fresh, cleared code field
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.xxl,
              AppSpace.lg,
              AppSpace.xxl,
              AppSpace.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.narrowMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconTile(
                    icon: AppIcons.mailOpen,
                    tint: scheme.primary,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  Text('Check your email', style: theme.textTheme.displaySmall),
                  const SizedBox(height: AppSpace.sm + 2),
                  Text.rich(
                    TextSpan(
                      text: 'Enter the 6-digit code we sent to ',
                      children: [
                        TextSpan(
                          text: widget.email,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxl),
                  _CodeInput(
                    key: ValueKey(_attempt),
                    enabled: !_verifying,
                    onCompleted: _onCompleted,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Row(
                      children: [
                        Icon(AppIcons.error, size: 15, color: scheme.error),
                        const SizedBox(width: AppSpace.sm - 2),
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpace.xl),
                  if (_verifying)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.primary,
                        ),
                      ),
                    )
                  else
                    _ResendRow(secondsLeft: _secondsLeft, onResend: _resend),
                  if (widget.debugCode != null) ...[
                    const SizedBox(height: AppSpace.xl),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.md,
                        vertical: AppSpace.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppTones.of(context).warningContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Dev code · ${widget.debugCode}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTones.of(context).warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsLeft, required this.onResend});

  final int secondsLeft;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canResend = secondsLeft == 0;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          "Didn't get it? ",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (canResend)
          GestureDetector(
            onTap: onResend,
            child: Text(
              'Send another code',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Text(
            'You can ask again in ${secondsLeft}s',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Six single-digit boxes backed by one hidden field, so input, paste and
/// backspace all behave naturally without juggling focus nodes.
class _CodeInput extends StatefulWidget {
  const _CodeInput({super.key, required this.onCompleted, this.enabled = true});

  final ValueChanged<String> onCompleted;
  final bool enabled;
  int get length => 6;

  @override
  State<_CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<_CodeInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    if (value.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final text = _controller.text;
    final focused = _focusNode.hasFocus;

    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpace.sm),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 0.84,
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: focused && i == text.length
                            ? scheme.primary
                            : tones.hairline,
                        width: focused && i == text.length
                            ? AppStroke.focus
                            : AppStroke.thin,
                      ),
                    ),
                    child: Text(
                      i < text.length ? text[i] : '',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              autofocus: true,
              showCursor: false,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              onChanged: _onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
