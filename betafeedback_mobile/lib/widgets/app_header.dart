import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Navigation-style large title with an optional summary line beneath it.
class AppLargeTitle extends StatelessWidget {
  const AppLargeTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.displaySmall),
        // if (subtitle != null) ...[
        //   const SizedBox(height: AppSpace.xs),
        //   Text(
        //     subtitle!,
        //     maxLines: 1,
        //     overflow: TextOverflow.ellipsis,
        //     style: theme.textTheme.bodySmall,
        //   ),
        // ],
      ],
    );
  }
}

/// Eyebrow label that introduces a block of content outside a grouped section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpace.gutter + AppSpace.xs,
      0,
      AppSpace.gutter,
      AppSpace.sm,
    ),
  });

  final String title;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(title.toUpperCase(), style: theme.textTheme.labelSmall),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Title block for bottom sheets, so every sheet in the app opens the same way.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.xs + 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Hairline rule broken by a short label — separates two ways of doing the
/// same thing (sign in with email vs. Google, invite by link vs. by email).
class LabeledRule extends StatelessWidget {
  const LabeledRule(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);

    return Row(
      children: [
        Expanded(child: Divider(color: tones.hairline)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
        ),
        Expanded(child: Divider(color: tones.hairline)),
      ],
    );
  }
}

/// Toolbar icon button used beside large titles.
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

  /// Replaces the plain glyph, e.g. an unread count [Badge].
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 22,
      visualDensity: VisualDensity.compact,
      icon: badge ?? Icon(icon),
      color: Theme.of(context).colorScheme.onSurface,
    );
  }
}
