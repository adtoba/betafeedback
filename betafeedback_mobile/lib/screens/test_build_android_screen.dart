import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_scope.dart';
import '../models/project.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_tokens.dart';
import '../utils/android_beta_install.dart';
import '../widgets/edit_distribution_sheet.dart';
import '../widgets/grouped_list.dart';

/// Full Android closed-testing page — shown for both creators and testers.
class TestBuildAndroidScreen extends StatelessWidget {
  const TestBuildAndroidScreen({
    super.key,
    required this.project,
    required this.userEmail,
    required this.isCreator,
    required this.isTester,
  });

  final Project project;
  final String userEmail;
  final bool isCreator;
  final bool isTester;

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
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

  Future<void> _markDone(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('android_beta_install_done_${project.id}', true);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final playUrl = androidPlayTestingUrl(project) ?? '';
    final groupUrl = project.googleGroupJoinUrl?.trim() ?? '';
    final hasBetaInfo = playUrl.isNotEmpty || groupUrl.isNotEmpty;

    // Build the tester checklist steps dynamically.
    int step = 0;
    final steps = <({int n, String title, String subtitle, IconData icon, String? url})>[];

    step++;
    steps.add((
      n: step,
      title: 'Use this Google account',
      subtitle: userEmail.isNotEmpty ? userEmail : 'Your signed-in email',
      icon: AppIcons.mail,
      url: null,
    ));

    if (groupUrl.isNotEmpty) {
      step++;
      steps.add((
        n: step,
        title: 'Join the tester Google Group',
        subtitle: 'Required for Play closed testing',
        icon: AppIcons.people,
        url: groupUrl,
      ));
    }

    if (playUrl.isNotEmpty) {
      step++;
      steps.add((
        n: step,
        title: 'Get the app on Google Play',
        subtitle: 'Use the same Google account as above',
        icon: AppIcons.platformAndroid,
        url: playUrl,
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Android'),
        actions: [
          if (isCreator)
            TextButton(
              onPressed: () => showEditDistributionSheet(
                context,
                project: project,
              ),
              child: const Text('Edit'),
            ),
        ],
      ),
      body: AppLayout.adaptiveBody(
        context,
        ListView(
          padding: const EdgeInsets.only(
            top: AppSpace.lg,
            bottom: AppSpace.xxxl,
          ),
          children: [
            // Tester checklist
            if (isTester && hasBetaInfo) ...[
              GroupedSection(
                header: 'Install checklist',
                // footer:
                //     'Complete these steps before testing.',
                children: [
                  for (final s in steps)
                    _ChecklistTile(
                      step: s.n,
                      title: s.title,
                      subtitle: s.subtitle,
                      icon: s.icon,
                      url: s.url,
                      onOpen: s.url != null
                          ? () => _launch(context, s.url!)
                          : null,
                      onCopy: s.url != null
                          ? () => copyToClipboard(
                                context,
                                s.url!,
                                'Link copied',
                              )
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
                child: FilledButton(
                  onPressed: () => _markDone(context),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(height: AppSpace.xl),
            ],

            // Creator view: show current links
            if (isCreator) ...[
              GroupedSection(
                header: 'Distribution links',
                footer: 'Testers who join your project will see these as a checklist.',
                children: [
                  _CreatorLinkRow(
                    icon: AppIcons.platformAndroid,
                    title: 'Play testing link',
                    subtitle: playUrl.isNotEmpty ? playUrl : 'Not set',
                    actions: playUrl.isNotEmpty
                        ? _LinkActions(
                            url: playUrl,
                            copyLabel: 'Play link copied',
                            onLaunch: () => _launch(context, playUrl),
                            onCopy: () => copyToClipboard(
                              context,
                              playUrl,
                              'Play link copied',
                            ),
                          )
                        : null,
                  ),
                  _CreatorLinkRow(
                    icon: AppIcons.people,
                    title: 'Google Group join URL',
                    subtitle: groupUrl.isNotEmpty ? groupUrl : 'Not set',
                    actions: groupUrl.isNotEmpty
                        ? _LinkActions(
                            url: groupUrl,
                            copyLabel: 'Group link copied',
                            onLaunch: () => _launch(context, groupUrl),
                            onCopy: () => copyToClipboard(
                              context,
                              groupUrl,
                              'Group link copied',
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreatorLinkRow extends StatelessWidget {
  const _CreatorLinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actions,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md + 2,
        AppSpace.sm,
        AppSpace.md + 2,
        AppSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions != null) ...[
            const SizedBox(height: AppSpace.xs),
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.xl + AppSpace.xs),
              child: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

/// A checklist step inside a [GroupedSection].
class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.url,
    this.onOpen,
    this.onCopy,
  });

  final int step;
  final String title;
  final String subtitle;
  final IconData icon;
  final String? url;
  final VoidCallback? onOpen;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md + 2,
        vertical: AppSpace.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number badge
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$step',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
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
                    Icon(icon, size: 15, color: scheme.primary),
                    const SizedBox(width: AppSpace.xs),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.bodyLarge,
                      ),
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
                if (onOpen != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onOpen,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                          ),
                        ),
                        icon: Icon(
                          AppIcons.externalLink,
                          size: 14,
                          color: scheme.primary,
                        ),
                        label: Text(
                          icon == AppIcons.people ? 'Join group' : 'Open',
                        ),
                      ),
                      if (onCopy != null) ...[
                        const SizedBox(width: AppSpace.sm),
                        IconButton(
                          onPressed: onCopy,
                          tooltip: 'Copy link',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            AppIcons.copy,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two small icon buttons — open externally + copy — used inside creator tiles.
class _LinkActions extends StatelessWidget {
  const _LinkActions({
    required this.url,
    required this.copyLabel,
    required this.onLaunch,
    required this.onCopy,
  });

  final String url;
  final String copyLabel;
  final VoidCallback onLaunch;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final color =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onCopy,
          tooltip: 'Copy',
          visualDensity: VisualDensity.compact,
          icon: Icon(AppIcons.copy, size: 17, color: color),
        ),
        IconButton(
          onPressed: onLaunch,
          tooltip: 'Open',
          visualDensity: VisualDensity.compact,
          icon: Icon(AppIcons.externalLink, size: 17, color: color),
        ),
      ],
    );
  }
}
