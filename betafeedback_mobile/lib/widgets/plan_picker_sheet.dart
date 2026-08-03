import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/subscription.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'app_header.dart';
import 'status_pill.dart';

/// Convenience wrapper that wires RevenueCat purchase / restore / manage.
void showUpgradeSheet(
  BuildContext context,
  AppState appState, {
  String? title,
}) {
  showPlanPickerSheet(
    context,
    title: title,
    currentPlan: appState.currentSubscription.plan,
    onUpgrade: () async {
      final ok = await appState.purchasePro();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'You\'re on Pro — thanks for supporting BetaFeedback'
                : 'Purchase canceled',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    onRestore: () async {
      final ok = await appState.restorePurchases();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Purchases restored' : 'No active Pro subscription found',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    },
    onManage: appState.manageSubscription,
  );
}

/// Shows Free / Pro options. Selecting Pro runs [onUpgrade]; Free while on Pro
/// opens manage subscriptions; Restore uses [onRestore].
void showPlanPickerSheet(
  BuildContext context, {
  required SubscriptionPlan currentPlan,
  required Future<void> Function() onUpgrade,
  Future<void> Function()? onRestore,
  Future<void> Function()? onManage,
  String? title,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => PlanPickerSheet(
      title: title ?? 'Choose a plan',
      currentPlan: currentPlan,
      onUpgrade: () async {
        final navigator = Navigator.of(sheetContext);
        try {
          await onUpgrade();
          if (sheetContext.mounted) navigator.pop();
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
      onRestore: onRestore == null
          ? null
          : () async {
              try {
                await onRestore();
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
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
      onManage: onManage,
    ),
  );
}

class PlanPickerSheet extends StatelessWidget {
  const PlanPickerSheet({
    super.key,
    required this.title,
    required this.currentPlan,
    required this.onUpgrade,
    this.onRestore,
    this.onManage,
  });

  final String title;
  final SubscriptionPlan currentPlan;
  final VoidCallback onUpgrade;
  final VoidCallback? onRestore;
  final Future<void> Function()? onManage;

  @override
  Widget build(BuildContext context) {
    final isPro = currentPlan == SubscriptionPlan.pro;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          AppSpace.xs,
          AppSpace.xl,
          AppSpace.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(
              title: title,
              subtitle: isPro
                  ? "You're on Pro. Manage or restore your plan below."
                  : 'Upgrade any time — your projects and feedback stay put.',
            ),
            for (final plan in SubscriptionPlan.values) ...[
              _PlanOption(
                plan: plan,
                isCurrent: plan == currentPlan,
                onTap: plan == currentPlan
                    ? null
                    : plan == SubscriptionPlan.pro
                    ? onUpgrade
                    : () async {
                        // Downgrades happen in the store subscription manager.
                        if (onManage != null) {
                          await onManage!();
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Cancel Pro in your App Store or Play Store subscriptions.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              ),
              const SizedBox(height: AppSpace.md),
            ],
            const SizedBox(height: AppSpace.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isPro && onManage != null)
                  TextButton(
                    onPressed: () => onManage!(),
                    child: const Text('Manage subscription'),
                  ),
                if (onRestore != null)
                  TextButton(
                    onPressed: onRestore,
                    child: const Text('Restore purchases'),
                  ),
              ],
            ),
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

    final tones = AppTones.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg + 1),
        decoration: BoxDecoration(
          color: isCurrent ? scheme.primary.withValues(alpha: 0.04) : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isCurrent ? scheme.primary : tones.hairline,
            width: isCurrent ? AppStroke.focus : AppStroke.thin,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(plan.label, style: theme.textTheme.titleLarge),
                const SizedBox(width: AppSpace.sm),
                Text(
                  plan.priceLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (isCurrent)
                  StatusPill(label: 'Current', color: scheme.primary)
                else
                  Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.xxs),
            Text(
              plan.tagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.md + 2),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm - 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.check, size: 15, color: scheme.tertiary),
                    const SizedBox(width: AppSpace.sm + 2),
                    Expanded(
                      child: Text(feature, style: theme.textTheme.bodyMedium),
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
