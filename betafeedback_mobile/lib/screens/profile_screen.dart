import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../widgets/plan_picker_sheet.dart';
import '../models/subscription.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _subLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AppScope.of(context).loadSubscription();
      } catch (_) {
        // Leave the default subscription if it can't be loaded.
      }
      if (mounted) setState(() => _subLoaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final user = appState.currentUser;
        final sub = appState.currentSubscription;

        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 24),
              _SectionTitle('Subscription'),
              const SizedBox(height: 10),
              if (!_subLoaded)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _SubscriptionCard(
                  subscription: sub,
                  projectsUsed: appState.projectsCreatedByCurrentUser,
                  onManage: () => _openPlanPicker(context, appState, sub),
                ),
              const SizedBox(height: 24),
              _SectionTitle('Preferences'),
              const SizedBox(height: 10),
              _AppearanceTile(appState: appState),
              const SizedBox(height: 8),
              _EmailNotificationsTile(appState: appState, subscription: sub),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  appState.signOut();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                icon: const Icon(AppIcons.logout, size: 18),
                label: const Text('Sign out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPlanPicker(
    BuildContext context,
    AppState appState,
    Subscription current,
  ) {
    showPlanPickerSheet(
      context,
      currentPlan: current.plan,
      onSelect: (plan) async {
        await appState.changePlan(plan);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You\'re now on the ${plan.label} plan'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: avatarColorForUser(user, scheme),
          child: Text(
            initialsFor(user.name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          user.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.projectsUsed,
    required this.onManage,
  });

  final Subscription subscription;
  final int projectsUsed;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plan = subscription.plan;
    final limit = subscription.projectLimit;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    plan.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _StatusPill(status: subscription.status),
                const Spacer(),
                Text(
                  plan.priceLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.tagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (subscription.renewsOn != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(AppIcons.repeat,
                      size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Renews ${formatDate(subscription.renewsOn!)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Project usage
            _UsageBar(used: projectsUsed, limit: limit),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...plan.features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(AppIcons.checkCircle,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(f)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onManage,
                child: Text(
                  subscription.isPaid ? 'Manage subscription' : 'Upgrade plan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.used, required this.limit});

  final int used;
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unlimited = limit == null;
    final fraction =
        unlimited ? 0.0 : (limit == 0 ? 1.0 : (used / limit!).clamp(0.0, 1.0));
    final atLimit = !unlimited && used >= limit!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Projects',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              unlimited ? '$used · Unlimited' : '$used of $limit',
              style: theme.textTheme.labelMedium?.copyWith(
                color: atLimit ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: unlimited ? 1.0 : fraction,
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            color: atLimit ? scheme.error : scheme.primary,
          ),
        ),
        if (atLimit) ...[
          const SizedBox(height: 6),
          Text(
            'You\'ve reached your project limit. Upgrade to add more.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status) {
      SubscriptionStatus.active => (scheme.primaryContainer, scheme.onPrimaryContainer),
      SubscriptionStatus.trialing =>
        (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      SubscriptionStatus.pastDue => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmailNotificationsTile extends StatelessWidget {
  const _EmailNotificationsTile({
    required this.appState,
    required this.subscription,
  });

  final AppState appState;
  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPro = subscription.plan == SubscriptionPlan.pro;
    final enabled = appState.currentUser.emailNotifications;

    return Card(
      child: SwitchListTile(
        secondary: const Icon(AppIcons.mail),
        title: const Text('Email notifications'),
        subtitle: Text(
          isPro
              ? 'Get emailed when feedback arrives, bugs are suggested, or releases ship.'
              : 'Available on Pro — upgrade to get alerts in your inbox.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        value: isPro && enabled,
        onChanged: isPro
            ? (value) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await appState.setEmailNotifications(value);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('$e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            : null,
      ),
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({required this.appState});

  final AppState appState;

  static const _options = [
    (ThemeMode.system, AppIcons.sunMoon, 'System', 'Match device settings'),
    (ThemeMode.light, AppIcons.sun, 'Light', 'Always use light mode'),
    (ThemeMode.dark, AppIcons.moon, 'Dark', 'Always use dark mode'),
  ];

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _AppearancePickerSheet(
        current: appState.themeMode,
        onSelect: (mode) {
          appState.setThemeMode(mode);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _options
        .firstWhere((o) => o.$1 == appState.themeMode)
        .$3;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: const Icon(AppIcons.sunMoon),
        title: const Text('Appearance'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(AppIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
        onTap: () => _openPicker(context),
      ),
    );
  }
}

class _AppearancePickerSheet extends StatelessWidget {
  const _AppearancePickerSheet({
    required this.current,
    required this.onSelect,
  });

  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;

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
              'Appearance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final option in _AppearanceTile._options) ...[
              _AppearanceOption(
                icon: option.$2,
                label: option.$3,
                subtitle: option.$4,
                isSelected: option.$1 == current,
                onTap: () => onSelect(option.$1),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  const _AppearanceOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

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
            color: isSelected ? scheme.primary : scheme.outlineVariant,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(AppIcons.checkCircle, color: scheme.primary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
    );
  }
}
