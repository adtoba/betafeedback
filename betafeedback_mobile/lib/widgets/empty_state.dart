import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Compact empty hint, centered in whatever space the parent gives it.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    this.action,
    this.tint,
  });

  final IconData? icon;
  final String title;
  final String message;
  final Widget? action;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.lg,
            vertical: AppSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: tint ?? muted),
                const SizedBox(height: AppSpace.sm + 2),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpace.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact failure hint with a text retry action.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Try again',
  });

  final IconData? icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: icon,
      title: title,
      message: message,
      tint: Theme.of(context).colorScheme.error,
      action: TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(retryLabel),
      ),
    );
  }
}
