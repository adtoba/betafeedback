import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_scope.dart';
import '../models/project.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_tokens.dart';
import '../widgets/grouped_list.dart';

/// iOS TestFlight distribution page — shown for both creators and testers.
class TestBuildIosScreen extends StatelessWidget {
  const TestBuildIosScreen({
    super.key,
    required this.project,
    required this.isCreator,
    required this.isTester,
  });

  final Project project;
  final bool isCreator;
  final bool isTester;

  String? _testFlightUrl() {
    for (final link in project.platformLinks) {
      if (link.platform == 'ios' && link.url.trim().isNotEmpty) {
        return link.url.trim();
      }
    }
    return project.appLink;
  }

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

  @override
  Widget build(BuildContext context) {
    final testFlightUrl = _testFlightUrl() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('iOS'),
        actions: [
          if (isCreator)
            TextButton(
              onPressed: () => _showEditSheet(context),
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
            // Tester view — checklist
            if (isTester) ...[
              GroupedSection(
                header: 'Install checklist',
                // footer: 'Complete these steps on your iPhone or iPad.',
                children: [
                  _ChecklistTile(
                    step: 1,
                    icon: AppIcons.platformIos,
                    title: 'Install TestFlight',
                    subtitle: 'Needed to run beta apps.',
                    actionLabel: 'Open App Store',
                    actionUrl:
                        'https://apps.apple.com/app/testflight/id899247664',
                    onOpen: () => _launch(
                      context,
                      'https://apps.apple.com/app/testflight/id899247664',
                    ),
                  ),
                  if (testFlightUrl.isNotEmpty)
                    _ChecklistTile(
                      step: 2,
                      icon: AppIcons.link,
                      title: 'Join the beta',
                      subtitle: 'Tap Open to go straight into TestFlight.',
                      actionLabel: 'Open TestFlight',
                      actionUrl: testFlightUrl,
                      onOpen: () => _launch(context, testFlightUrl),
                      onCopy: () => copyToClipboard(
                        context,
                        testFlightUrl,
                        'TestFlight link copied',
                      ),
                    )
                  else
                    const _ChecklistTile(
                      step: 2,
                      icon: AppIcons.link,
                      title: 'Join the beta',
                      subtitle:
                          'The creator hasn\'t added a TestFlight link yet.',
                    ),
                ],
              ),
              if (testFlightUrl.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.gutter,
                  ),
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
            ],

            // Creator view — link management
            if (isCreator) ...[
              GroupedSection(
                header: 'Distribution link',
                footer:
                    'TestFlight public links look like '
                    'testflight.apple.com/join/… — '
                    'find yours in App Store Connect under External Groups.',
                children: [
                  _CreatorLinkRow(
                    icon: AppIcons.platformIos,
                    title: 'TestFlight public link',
                    subtitle: testFlightUrl.isNotEmpty
                        ? testFlightUrl
                        : 'Not set',
                    actions: testFlightUrl.isNotEmpty
                        ? _LinkActions(
                            onLaunch: () => _launch(context, testFlightUrl),
                            onCopy: () => copyToClipboard(
                              context,
                              testFlightUrl,
                              'TestFlight link copied',
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

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditIosLinkSheet(project: project),
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

// ---------------------------------------------------------------------------
// Checklist tile
// ---------------------------------------------------------------------------

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.step,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionUrl,
    this.onOpen,
    this.onCopy,
  });

  final int step;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final String? actionUrl;
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
                        label: Text(actionLabel ?? 'Open'),
                      ),
                      if (onCopy != null) ...[
                        const SizedBox(width: AppSpace.xs),
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

// ---------------------------------------------------------------------------
// Creator icon-button pair (copy + open)
// ---------------------------------------------------------------------------

class _LinkActions extends StatelessWidget {
  const _LinkActions({required this.onLaunch, required this.onCopy});

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

// ---------------------------------------------------------------------------
// Creator edit sheet
// ---------------------------------------------------------------------------

class _EditIosLinkSheet extends StatefulWidget {
  const _EditIosLinkSheet({required this.project});

  final Project project;

  @override
  State<_EditIosLinkSheet> createState() => _EditIosLinkSheetState();
}

class _EditIosLinkSheetState extends State<_EditIosLinkSheet> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    String current = '';
    for (final link in widget.project.platformLinks) {
      if (link.platform == 'ios') {
        current = link.url;
        break;
      }
    }
    if (current.isEmpty) current = widget.project.appLink ?? '';
    _controller = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Enter a valid URL (https://…)';
    }
    return null;
  }

  Future<void> _save() async {
    final url = _controller.text.trim();
    if (_validate(url) != null) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final links = <PlatformLink>[
        for (final link in widget.project.platformLinks)
          if (link.platform != 'ios') link,
        if (url.isNotEmpty) PlatformLink(platform: 'ios', url: url),
      ];
      await AppScope.of(context).updateProjectDistribution(
        projectId: widget.project.id,
        googleGroupJoinUrl: widget.project.googleGroupJoinUrl,
        platformLinks: links,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('TestFlight link updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.gutter,
        right: AppSpace.gutter,
        top: AppSpace.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('iOS', style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpace.xs),
          Text(
            'Paste your TestFlight public link — testers tap it to join '
            'instantly without needing an individual invite.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'TestFlight public link',
              hintText: 'https://testflight.apple.com/join/…',
              prefixIcon: Icon(AppIcons.platformIos),
            ),
            validator: _validate,
          ),
          const SizedBox(height: AppSpace.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
