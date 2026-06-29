import 'package:flutter/material.dart';

import '../models/subscription.dart';
import '../theme/app_icons.dart';

void showPlanPickerSheet(
  BuildContext context, {
  required SubscriptionPlan currentPlan,
  required Future<void> Function(SubscriptionPlan plan) onSelect,
  String? title,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => PlanPickerSheet(
      title: title ?? 'Choose a plan',
      currentPlan: currentPlan,
      onSelect: (plan) async {
        final navigator = Navigator.of(sheetContext);
        try {
          await onSelect(plan);
          navigator.pop();
        } catch (e) {
          if (sheetContext.mounted) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              SnackBar(
                content: Text('$e'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    ),
  );
}

class PlanPickerSheet extends StatelessWidget {
  const PlanPickerSheet({
    super.key,
    required this.title,
    required this.currentPlan,
    required this.onSelect,
  });

  final String title;
  final SubscriptionPlan currentPlan;
  final void Function(SubscriptionPlan plan) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final plan in SubscriptionPlan.values) ...[
              _PlanOption(
                plan: plan,
                isCurrent: plan == currentPlan,
                onTap: plan == currentPlan ? null : () => onSelect(plan),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.plan,
    required this.isCurrent,
    required this.onTap,
  });

  final SubscriptionPlan plan;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? scheme.primary : scheme.outlineVariant,
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            plan.priceLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.tagline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Text(
                    'Current',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Icon(AppIcons.chevronRight, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.checkCircle,
                        size: 16, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
