import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Small tonal label for statuses, roles, and plans.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.solid = false,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Filled treatment for the one status per screen that needs to shout.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final foreground = solid ? Colors.white : color;

    return Container(
      padding: EdgeInsets.only(
        left: icon == null ? AppSpace.sm + 2 : AppSpace.sm,
        right: AppSpace.sm + 2,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpace.xs + 1),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric badge for counts that need attention.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, this.color});

  final int count;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final background = color ?? Theme.of(context).colorScheme.error;

    return Container(
      constraints: const BoxConstraints(minWidth: 21),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}
