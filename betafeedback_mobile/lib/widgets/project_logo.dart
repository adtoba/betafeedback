import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import 'project_card.dart';

/// Project avatar — shows the uploaded logo or initials on a tinted background.
class ProjectLogo extends StatelessWidget {
  const ProjectLogo({
    super.key,
    required this.projectName,
    this.logoUrl,
    this.size = 40,
    this.borderRadius = 10,
  });

  final String projectName;
  final String? logoUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = ProjectCard.accentColor(projectName, scheme);
    final fallback = _InitialsAvatar(
      projectName: projectName,
      size: size,
      borderRadius: borderRadius,
      accent: accent,
    );

    if (logoUrl == null || logoUrl!.isEmpty) return fallback;

    final url = AppScope.of(context).mediaUrl(logoUrl!);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return fallback;
        },
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.projectName,
    required this.size,
    required this.borderRadius,
    required this.accent,
  });

  final String projectName;
  final double size;
  final double borderRadius;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final initials = projectName.trim().isEmpty
        ? '?'
        : initialsFor(projectName);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: accent,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// App bar title with optional project logo beside the name.
class ProjectAppBarTitle extends StatelessWidget {
  const ProjectAppBarTitle({
    super.key,
    required this.projectName,
    this.logoUrl,
  });

  final String projectName;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ProjectLogo(
          projectName: projectName,
          logoUrl: logoUrl,
          size: 28,
          borderRadius: 7,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            projectName,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
