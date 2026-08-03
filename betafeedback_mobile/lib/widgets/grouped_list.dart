import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Inset grouped section: an eyebrow label, a hairline-bordered card of rows,
/// and an optional explanatory footer.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.header,
    this.footer,
    this.headerAction,
    required this.children,
  });

  final String? header;
  final String? footer;

  /// Optional control aligned with the eyebrow, e.g. a "See all" button.
  final Widget? headerAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tones = AppTones.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null || headerAction != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter + AppSpace.xs,
              0,
              AppSpace.gutter,
              AppSpace.sm,
            ),
            child: Row(
              children: [
                if (header != null)
                  Expanded(
                    child: Text(
                      header!.toUpperCase(),
                      style: theme.textTheme.labelSmall,
                    ),
                  )
                else
                  const Spacer(),
                ?headerAction,
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: tones.hairline,
                width: AppStroke.hairline,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(color: tones.hairline),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter + AppSpace.xs,
              AppSpace.sm,
              AppSpace.gutter + AppSpace.xs,
              0,
            ),
            child: Text(footer!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}

/// Standard row inside a [GroupedSection]. The leading glyph sits in a tinted
/// tile so rows keep a common left edge whether or not they have an icon.
class GroupedListTile extends StatelessWidget {
  const GroupedListTile({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showChevron = true,
    this.onTap,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = iconColor ?? scheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md + 2,
            vertical: AppSpace.md - 1,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                IconTile(icon: icon!, tint: tint),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyLarge),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpace.xxs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpace.sm),
                trailing!,
              ],
              if (showChevron && onTap != null) ...[
                const SizedBox(width: AppSpace.sm),
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Glyph on a tinted rounded tile — the app's standard leading element.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 30,
  });

  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.56, color: tint),
    );
  }
}

/// Plain text row for sections that hold copy rather than navigation.
class GroupedNote extends StatelessWidget {
  const GroupedNote(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md + 2,
        vertical: AppSpace.md,
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
