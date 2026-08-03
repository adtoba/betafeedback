import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'project_logo.dart';

/// App Store style project row: a large icon, the name with its tagline, and a
/// pill action on the trailing edge. Rows sit on the page background and are
/// divided by hairlines inset to [separatorInset].
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.hasUnread,
    required this.onTap,
  });

  final Project project;
  final bool hasUnread;
  final VoidCallback onTap;

  /// Icon edge. Matches the App Store's list artwork size.
  static const double iconSize = 58;

  /// Space between the icon and the text column.
  static const double _gap = AppSpace.md + 2;

  /// Left inset for the divider between rows, so it starts at the text.
  static const double separatorInset = iconSize + _gap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    final tagline = project.description.trim();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md - 2),
        child: Row(
          children: [
            _Icon(project: project, hasUnread: hasUnread),
            const SizedBox(width: _gap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 16),
                  ),
                  if (tagline.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpace.md),
            _ActionPill(label: hasUnread ? 'New' : 'Open', tones: tones),
          ],
        ),
      ),
    );
  }

  static Color accentColor(String seed, ColorScheme scheme) {
    final hue = (seed.codeUnits.fold<int>(0, (a, b) => a + b) * 13) % 360;
    return HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      0.5,
      scheme.brightness == Brightness.dark ? 0.62 : 0.42,
    ).toColor();
  }
}

/// Project artwork with the hairline App Store icons carry, plus the unread dot.
class _Icon extends StatelessWidget {
  const _Icon({required this.project, required this.hasUnread});

  final Project project;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);
    const radius = ProjectCard.iconSize * 0.23;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: tones.hairline,
              width: AppStroke.hairline,
            ),
          ),
          child: ProjectLogo(
            projectName: project.name,
            logoUrl: project.logoUrl,
            size: ProjectCard.iconSize,
            borderRadius: radius,
          ),
        ),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: Semantics(
              label: 'Unread project activity',
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: tones.unread,
                  shape: BoxShape.circle,
                  border: Border.all(color: tones.canvas, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The trailing pill. Presentational — the whole row is the tap target, so it
/// never competes with the row for the touch.
class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, required this.tones});

  final String label;
  final AppTones tones;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 30,
      alignment: Alignment.center,
      constraints: const BoxConstraints(minWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md + 2),
      decoration: BoxDecoration(
        color: tones.sunken,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
