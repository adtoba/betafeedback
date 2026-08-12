import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/project.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../utils/android_beta_install.dart';

/// Guided checklist for Android testers: Google Group + Play testing link.
Future<void> showAndroidBetaInstallSheet(
  BuildContext context, {
  required Project project,
  required String userEmail,
  bool force = false,
}) async {
  if (!shouldOfferAndroidBetaInstallSheet() ||
      !projectHasAndroidBetaInstall(project)) {
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final dismissedKey = 'android_beta_install_done_${project.id}';
  if (!force && prefs.getBool(dismissedKey) == true) return;

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _AndroidBetaInstallSheet(
      project: project,
      userEmail: userEmail,
      onDone: () async {
        await prefs.setBool(dismissedKey, true);
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      },
    ),
  );
}

class _AndroidBetaInstallSheet extends StatelessWidget {
  const _AndroidBetaInstallSheet({
    required this.project,
    required this.userEmail,
    required this.onDone,
  });

  final Project project;
  final String userEmail;
  final VoidCallback onDone;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groupUrl = project.googleGroupJoinUrl?.trim() ?? '';
    final playUrl = androidPlayTestingUrl(project);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.lg,
          AppSpace.gutter,
          AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Install the Android beta',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'You joined ${project.name}. Finish these steps on this device '
              'before you test.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            _StepTile(
              number: 1,
              title: 'Use this Google account',
              subtitle: userEmail,
              icon: AppIcons.mail,
            ),
            if (groupUrl.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md),
              _StepTile(
                number: 2,
                title: 'Join the tester Google Group',
                subtitle: 'Required for Play closed testing',
                icon: AppIcons.people,
                actionLabel: 'Join group',
                onAction: () => _openUrl(context, groupUrl),
              ),
            ],
            if (playUrl != null) ...[
              const SizedBox(height: AppSpace.md),
              _StepTile(
                number: groupUrl.isNotEmpty ? 3 : 2,
                title: 'Get the app on Google Play',
                subtitle: 'Use the same Google account as above',
                icon: AppIcons.platformAndroid,
                actionLabel: 'Open Play',
                onAction: () => _openUrl(context, playUrl),
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            FilledButton(onPressed: onDone, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

/// Full reusable checklist content for Android closed testing.
///
/// This used to live only inside a bottom sheet, but we also render it as a
/// full page from the "Test build Android" option.
class AndroidBetaInstallChecklist extends StatelessWidget {
  const AndroidBetaInstallChecklist({
    super.key,
    required this.project,
    required this.userEmail,
    required this.onDone,
  });

  final Project project;
  final String userEmail;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _AndroidBetaInstallSheet(
      project: project,
      userEmail: userEmail,
      onDone: onDone,
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: scheme.primaryContainer,
          child: Text(
            '$number',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: scheme.primary),
                  const SizedBox(width: AppSpace.xs),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpace.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.tonal(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
