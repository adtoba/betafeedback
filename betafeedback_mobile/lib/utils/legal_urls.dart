import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const termsOfUseUrl = 'https://betafeedback.com/terms';
const privacyPolicyUrl = 'https://betafeedback.com/privacy';

Future<void> launchLegalUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (!await canLaunchUrl(uri)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open link'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
