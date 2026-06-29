import 'package:flutter/material.dart';

import '../models/project.dart';
import '../theme/app_icons.dart';
import 'project_logo.dart';

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.creatorName,
    required this.hasUnread,
    required this.onTap,
  });

  final Project project;
  final String creatorName;
  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const unreadColor = Color(0xFFFF453A); // iOS-style notification red

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProjectLogo(
                    projectName: project.name,
                    logoUrl: project.logoUrl,
                    size: 40,
                    borderRadius: 10,
                  ),
                  const Spacer(),
                  if (hasUnread)
                    Semantics(
                      label: 'Unread project activity',
                      child: Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: unreadColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                project.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'by $creatorName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    AppIcons.people,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${project.testerCount} '
                      '${project.testerCount == 1 ? "tester" : "testers"}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color accentColor(String seed, ColorScheme scheme) =>
      _accentColor(seed, scheme);

  static Color _accentColor(String seed, ColorScheme scheme) {
    final hue = (seed.codeUnits.fold<int>(0, (a, b) => a + b) * 13) % 360;
    return HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      0.55,
      scheme.brightness == Brightness.dark ? 0.65 : 0.45,
    ).toColor();
  }
}

/// Large navigation-style title used at the top of primary screens.
class LargeScreenTitle extends StatelessWidget {
  const LargeScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 34,
            letterSpacing: 0.4,
          ),
    );
  }
}

/// Standard toolbar icon button used in screen headers.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: badge ?? Icon(icon),
    );
  }
}

/// Exposes common header icons for convenience.
abstract final class HeaderIcons {
  static const add = AppIcons.add;
  static const bell = AppIcons.bell;
}
