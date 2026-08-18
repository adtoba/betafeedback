import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../utils/legal_urls.dart';

/// Tappable Terms of Use and Privacy Policy links for auth and subscription UI.
class LegalLinksText extends StatelessWidget {
  const LegalLinksText({
    super.key,
    this.prefix = 'By continuing you agree to our ',
    this.termsLabel = 'Terms of Use',
    this.privacyLabel = 'Privacy Policy',
    this.textAlign = TextAlign.center,
  });

  final String prefix;
  final String termsLabel;
  final String privacyLabel;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall?.copyWith(height: 1.45);
    final linkStyle = baseStyle?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
    );

    return Text.rich(
      textAlign: textAlign,
      TextSpan(
        style: baseStyle,
        children: [
          if (prefix.isNotEmpty) TextSpan(text: prefix),
          TextSpan(
            text: termsLabel,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchLegalUrl(context, termsOfUseUrl),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: privacyLabel,
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchLegalUrl(context, privacyPolicyUrl),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
