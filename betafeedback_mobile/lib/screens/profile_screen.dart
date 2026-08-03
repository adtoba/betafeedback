import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/grouped_list.dart';
import '../widgets/status_pill.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../widgets/plan_picker_sheet.dart';
import '../models/subscription.dart';
import '../models/user.dart';
import 'tester_invites_screen.dart';

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
          body: AppLayout.adaptiveBody(
            context,
            ListView(
              padding: const EdgeInsets.only(
                top: AppSpace.sm,
                bottom: AppSpace.xxxl,
              ),
              children: [
                _IdentityRow(user: user),
                const SizedBox(height: AppSpace.xxl),
                if (!_subLoaded)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpace.xxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  _SubscriptionPanel(
                    subscription: sub,
                    projectsUsed: appState.projectsCreatedByCurrentUser,
                    onManage: () => showUpgradeSheet(context, appState),
                  ),
                const SizedBox(height: AppSpace.xxl),
                _TesterMarketplacePanel(appState: appState),
                const SizedBox(height: AppSpace.xxl),
                GroupedSection(
                  header: 'Preferences',
                  children: [
                    _AppearanceRow(appState: appState),
                    _PushRow(appState: appState),
                    _EmailRow(appState: appState, subscription: sub),
                    if (appState.currentUser.openToTest ||
                        appState.pendingTesterInviteCount > 0)
                      GroupedListTile(
                        icon: AppIcons.mailOpen,
                        title: 'Testing invitations',
                        subtitle: appState.pendingTesterInviteCount > 0
                            ? '${appState.pendingTesterInviteCount} pending'
                            : 'View invites to test apps',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const TesterInvitesScreen(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.xxl),
                GroupedSection(
                  children: [
                    _SignOutRow(
                      onSignOut: () {
                        appState.signOut();
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = user.name.isEmpty ? user.email : user.name;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColorForUser(user, theme.colorScheme),
              shape: BoxShape.circle,
            ),
            child: Text(
              initialsFor(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
                if (user.name.isNotEmpty)
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Current plan, what it includes, and how much of it is used.
class _SubscriptionPanel extends StatelessWidget {
  const _SubscriptionPanel({
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
    final tones = AppTones.of(context);
    final plan = subscription.plan;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tones.hairline, width: AppStroke.hairline),
        ),
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR PLAN', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(width: AppSpace.md - 2),
                StatusPill(
                  label: subscription.status.label,
                  color: switch (subscription.status) {
                    SubscriptionStatus.active => scheme.tertiary,
                    SubscriptionStatus.trialing => scheme.primary,
                    SubscriptionStatus.pastDue => scheme.error,
                  },
                ),
                const SizedBox(width: AppSpace.sm),
                Text(plan.priceLabel, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: AppSpace.sm - 2),
            Text(
              plan.tagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (subscription.renewsOn != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                'Renews ${formatDate(subscription.renewsOn!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpace.xl),
            _UsageBar(used: projectsUsed, limit: subscription.projectLimit),
            const SizedBox(height: AppSpace.xl),
            Divider(color: tones.hairline),
            const SizedBox(height: AppSpace.lg),
            for (final feature in plan.features)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm + 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.check, size: 16, color: scheme.tertiary),
                    const SizedBox(width: AppSpace.sm + 2),
                    Expanded(
                      child: Text(feature, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              width: double.infinity,
              child: subscription.isPaid
                  ? OutlinedButton(
                      onPressed: onManage,
                      child: const Text('Manage subscription'),
                    )
                  : FilledButton(
                      onPressed: onManage,
                      child: const Text('Upgrade plan'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opt into the tester marketplace and show rating stats.
class _TesterMarketplacePanel extends StatefulWidget {
  const _TesterMarketplacePanel({required this.appState});

  final AppState appState;

  @override
  State<_TesterMarketplacePanel> createState() =>
      _TesterMarketplacePanelState();
}

class _TesterMarketplacePanelState extends State<_TesterMarketplacePanel> {
  late final TextEditingController _bio;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bio = TextEditingController(text: widget.appState.currentUser.testerBio);
  }

  @override
  void dispose() {
    _bio.dispose();
    super.dispose();
  }

  Future<void> _setOpen(bool value) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.appState.updateTesterProfile(openToTest: value);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveBio() async {
    final bio = _bio.text.trim();
    if (bio == widget.appState.currentUser.testerBio) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.appState.updateTesterProfile(testerBio: bio);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tester bio saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final user = widget.appState.currentUser;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Container(
        padding: const EdgeInsets.all(AppSpace.lg),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tones.hairline, width: AppStroke.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Open to test apps',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (_saving)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: user.openToTest,
                    onChanged: _setOpen,
                  ),
              ],
            ),
            Text(
              'Show up when creators look for testers. Accept invitations '
              'from your Testing invitations inbox.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpace.md),
            Row(
              children: [
                Icon(AppIcons.star, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpace.xs),
                Text(
                  user.testerRatingLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            if (user.openToTest) ...[
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: _bio,
                maxLength: 280,
                maxLines: 3,
                minLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Tester bio',
                  hintText: 'Devices you use, what you like to test…',
                  alignLabelWithHint: true,
                ),
                onEditingComplete: _saveBio,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _saving ? null : _saveBio,
                  child: const Text('Save bio'),
                ),
              ),
            ],
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
    final tones = AppTones.of(context);
    final unlimited = limit == null;
    final fraction = unlimited
        ? 1.0
        : (limit == 0 ? 1.0 : (used / limit!).clamp(0.0, 1.0));
    final atLimit = !unlimited && used >= limit!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Projects',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            Text(
              unlimited ? '$used · unlimited' : '$used of $limit',
              style: theme.textTheme.labelMedium?.copyWith(
                color: atLimit ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: tones.sunken,
            color: atLimit ? scheme.error : scheme.primary,
          ),
        ),
        if (atLimit) ...[
          const SizedBox(height: AppSpace.sm - 2),
          Text(
            "You've reached your project limit. Upgrade to add more.",
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}

class _AppearanceRow extends StatelessWidget {
  const _AppearanceRow({required this.appState});

  final AppState appState;

  static const options = [
    (ThemeMode.system, AppIcons.sunMoon, 'System', 'Match device settings'),
    (ThemeMode.light, AppIcons.sun, 'Light', 'Always use light mode'),
    (ThemeMode.dark, AppIcons.moon, 'Dark', 'Always use dark mode'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((o) => o.$1 == appState.themeMode);

    return GroupedListTile(
      icon: current.$2,
      title: 'Appearance',
      trailing: Text(
        current.$3,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        builder: (sheetContext) => _AppearanceSheet(
          current: appState.themeMode,
          onSelect: (mode) {
            appState.setThemeMode(mode);
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }
}

class _PushRow extends StatelessWidget {
  const _PushRow({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return GroupedListTile(
      icon: AppIcons.bell,
      title: 'Push notifications',
      showChevron: false,
      trailing: Switch.adaptive(
        value: appState.currentUser.pushNotifications,
        onChanged: (value) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await appState.setPushNotifications(value);
          } catch (e) {
            messenger.showSnackBar(SnackBar(content: Text('$e')));
          }
        },
      ),
    );
  }
}

class _EmailRow extends StatelessWidget {
  const _EmailRow({required this.appState, required this.subscription});

  final AppState appState;
  final Subscription subscription;

  @override
  Widget build(BuildContext context) {
    final isPro = subscription.plan == SubscriptionPlan.pro;
    final enabled = appState.currentUser.emailNotifications;

    return GroupedListTile(
      icon: AppIcons.mail,
      title: 'Email notifications',
      subtitle: isPro ? null : 'Available on Pro',
      showChevron: false,
      trailing: Switch.adaptive(
        value: isPro && enabled,
        onChanged: isPro
            ? (value) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await appState.setEmailNotifications(value);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            : null,
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  const _SignOutRow({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GroupedListTile(
      icon: AppIcons.logout,
      iconColor: scheme.error,
      title: 'Sign out',
      showChevron: false,
      onTap: onSignOut,
    );
  }
}

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.current, required this.onSelect});

  final ThemeMode current;
  final ValueChanged<ThemeMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs, bottom: AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter + AppSpace.xs,
                0,
                AppSpace.gutter,
                AppSpace.xl,
              ),
              child: Text('Appearance', style: theme.textTheme.headlineSmall),
            ),
            GroupedSection(
              children: [
                for (final option in _AppearanceRow.options)
                  GroupedListTile(
                    icon: option.$2,
                    title: option.$3,
                    subtitle: option.$4,
                    showChevron: false,
                    trailing: option.$1 == current
                        ? Icon(
                            AppIcons.check,
                            size: 19,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => onSelect(option.$1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
