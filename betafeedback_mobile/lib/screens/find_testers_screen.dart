import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/tester.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/metric_strip.dart';
import '../widgets/status_pill.dart';

/// Browse opted-in testers and invite them to [projectId], or propose swaps.
class FindTestersScreen extends StatefulWidget {
  const FindTestersScreen({
    super.key,
    required this.projectId,
    this.projectName = '',
    this.showSkip = false,
  });

  final String projectId;
  final String projectName;
  final bool showSkip;

  @override
  State<FindTestersScreen> createState() => _FindTestersScreenState();
}

class _FindTestersScreenState extends State<FindTestersScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final TabController _tabs;
  List<TesterProfile> _testers = [];
  List<TesterProfile> _top = [];
  List<SwapPartner> _partners = [];
  bool _loading = true;
  String? _error;
  final _inviting = <String>{};
  final _invited = <String>{};
  final _proposing = <String>{};
  final _proposed = <String>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = AppScope.of(context);
      final results = await Future.wait([
        appState.loadOpenTesters(
          projectId: widget.projectId,
          query: _search.text,
        ),
        appState.loadTopTesters(),
        appState.loadSwapPartners(
          projectId: widget.projectId,
          query: _search.text,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _testers = results[0] as List<TesterProfile>;
        _top = results[1] as List<TesterProfile>;
        _partners = results[2] as List<SwapPartner>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  TesterProfile _withLocalInviteState(TesterProfile tester) {
    if (_invited.contains(tester.id) || _inviting.contains(tester.id)) {
      return tester.copyWith(invitePending: true);
    }
    return tester;
  }

  Future<void> _showTester(TesterProfile tester) async {
    final current = _withLocalInviteState(tester);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TesterProfileSheet(
        tester: current,
        inviting: _inviting.contains(tester.id),
        onInvite: current.canInvite
            ? () async {
                await _invite(tester);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              }
            : null,
      ),
    );
  }

  Future<void> _invite(TesterProfile tester) async {
    if (_inviting.contains(tester.id) || _invited.contains(tester.id)) return;
    setState(() => _inviting.add(tester.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).inviteTester(
        projectId: widget.projectId,
        userId: tester.id,
      );
      if (!mounted) return;
      setState(() {
        _inviting.remove(tester.id);
        _invited.add(tester.id);
        _testers = [
          for (final t in _testers)
            if (t.id == tester.id) t.copyWith(invitePending: true) else t,
        ];
        _top = [
          for (final t in _top)
            if (t.id == tester.id) t.copyWith(invitePending: true) else t,
        ];
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${tester.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inviting.remove(tester.id));
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _proposeSwap(SwapPartner partner) async {
    if (!partner.canPropose || _proposing.contains(partner.id)) return;

    SwapProject? theirProject = partner.projects.length == 1
        ? partner.projects.first
        : null;
    if (theirProject == null) {
      theirProject = await showModalBottomSheet<SwapProject>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter,
                  AppSpace.lg,
                  AppSpace.gutter,
                  AppSpace.md,
                ),
                child: Text(
                  'Which of ${partner.name}\'s projects will you test?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final project in partner.projects)
                ListTile(
                  title: Text(project.name),
                  onTap: () => Navigator.of(sheetContext).pop(project),
                ),
              const SizedBox(height: AppSpace.md),
            ],
          ),
        ),
      );
      if (theirProject == null || !mounted) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Propose test-for-test?'),
        content: Text(
          'You\'ll invite ${partner.name} to test your project, and you\'ll '
          'join ${theirProject!.name} as a tester when they accept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Propose'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _proposing.add(partner.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).proposeSwap(
        fromProjectId: widget.projectId,
        toProjectId: theirProject.id,
      );
      if (!mounted) return;
      setState(() {
        _proposing.remove(partner.id);
        _proposed.add(partner.id);
        _partners = [
          for (final p in _partners)
            if (p.id == partner.id) p.copyWith(swapPending: true) else p,
        ];
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Swap proposed to ${partner.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _proposing.remove(partner.id));
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSwaps = _tabs.index == 1;
    final title = widget.projectName.isEmpty
        ? (onSwaps ? 'Test-for-test' : 'Find testers')
        : (onSwaps
              ? 'Swap for ${widget.projectName}'
              : 'Find testers for ${widget.projectName}');

    return Scaffold(
      appBar: AppBar(
        title: Text(onSwaps ? 'Test-for-test' : 'Find testers'),
        actions: [
          if (widget.showSkip)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Invite'),
            Tab(text: 'Swap'),
          ],
        ),
      ),
      body: AppLayout.adaptiveBody(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.sm,
                AppSpace.gutter,
                AppSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    onSwaps
                        ? 'Propose a swap with creators who also need testers. '
                              'You join theirs, they join yours.'
                        : 'Invite people who are open to testing apps on BetaFeedback.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpace.lg),
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onSubmitted: (_) => _load(),
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(AppIcons.search, size: 20),
                      suffixIcon: IconButton(
                        tooltip: 'Search',
                        onPressed: _load,
                        icon: const Icon(AppIcons.arrowRight, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _inviteBody(theme),
                  _swapBody(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inviteBody(ThemeData theme) {
    return _body(theme);
  }

  Widget _swapBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorState(
        icon: AppIcons.cloudOff,
        title: 'Couldn\'t load partners',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_partners.isEmpty) {
      final querying = _search.text.trim().isNotEmpty;
      return AppEmptyState(
        icon: AppIcons.repeat,
        title: querying ? 'No matches' : 'No swap partners yet',
        message: querying
            ? 'No creators open to swaps match that search.'
            : 'When other creators turn on test-for-test in their profile, '
                  'they\'ll show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          0,
          AppSpace.gutter,
          AppSpace.xxxl,
        ),
        itemCount: _partners.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpace.sm),
        itemBuilder: (context, index) {
          final partner = _partners[index];
          final pending =
              partner.swapPending || _proposed.contains(partner.id);
          final proposing = _proposing.contains(partner.id);
          return _PartnerTile(
            partner: partner,
            pending: pending,
            proposing: proposing,
            onPropose: partner.canPropose && !pending
                ? () => _proposeSwap(partner)
                : null,
          );
        },
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorState(
        icon: AppIcons.cloudOff,
        title: 'Couldn\'t load testers',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_testers.isEmpty) {
      final querying = _search.text.trim().isNotEmpty;
      return AppEmptyState(
        icon: AppIcons.people,
        title: querying ? 'No matches' : 'No testers yet',
        message: querying
            ? 'No opted-in testers match that name or email.'
            : 'When people opt in on their profile, they\'ll show up here. '
                  'You can still invite by email from the project.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter,
          0,
          AppSpace.gutter,
          AppSpace.xxxl,
        ),
        children: [
          if (_top.isNotEmpty && _search.text.trim().isEmpty) ...[
            Text('Top testers', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _top.length.clamp(0, 8),
                separatorBuilder: (_, _) => const SizedBox(width: AppSpace.sm),
                itemBuilder: (context, index) => _TopTesterChip(
                  tester: _withLocalInviteState(_top[index]),
                  onTap: () => _showTester(_top[index]),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            Text('Open to test', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpace.sm),
          ],
          for (final tester in _testers)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.sm + 2),
              child: _TesterRow(
                tester: _withLocalInviteState(tester),
                inviting: _inviting.contains(tester.id),
                onTap: () => _showTester(tester),
              ),
            ),
        ],
      ),
    );
  }
}

class _TesterProfileSheet extends StatelessWidget {
  const _TesterProfileSheet({
    required this.tester,
    required this.inviting,
    this.onInvite,
  });

  final TesterProfile tester;
  final bool inviting;
  final Future<void> Function()? onInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    String statusLabel;
    if (tester.alreadyMember) {
      statusLabel = 'Already on the team';
    } else if (tester.invitePending) {
      statusLabel = 'Invite pending';
    } else {
      statusLabel = 'Open to test';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(
                title: 'Tester profile',
                subtitle: 'Review their details before sending an invite.',
              ),
              Row(
                children: [
                  _Avatar(name: tester.name, hue: tester.avatarHue, size: 64),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tester.name,
                          style: theme.textTheme.headlineSmall,
                        ),
                        if (tester.email.isNotEmpty) ...[
                          const SizedBox(height: AppSpace.xxs),
                          Text(
                            tester.email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpace.sm),
                        StatusPill(
                          label: statusLabel,
                          color: tester.canInvite
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              MetricStrip(
                metrics: [
                  Metric(
                    label: 'Rating',
                    value: tester.ratingCount == 0
                        ? '—'
                        : tester.ratingAvg.toStringAsFixed(1),
                    tint: tester.ratingCount > 0 ? scheme.primary : null,
                  ),
                  Metric(
                    label: 'Reviews',
                    value: '${tester.ratingCount}',
                  ),
                  Metric(
                    label: 'Completed',
                    value: '${tester.completedCount}',
                  ),
                ],
              ),
              if (tester.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                Text('About', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpace.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: tones.sunken,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(tester.bio, style: theme.textTheme.bodyMedium),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              if (inviting)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (onInvite != null)
                FilledButton(
                  onPressed: () => onInvite!(),
                  child: const Text('Send invite'),
                )
              else
                OutlinedButton(
                  onPressed: null,
                  child: Text(
                    tester.alreadyMember ? 'Already joined' : 'Invite sent',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopTesterChip extends StatelessWidget {
  const _TopTesterChip({required this.tester, required this.onTap});

  final TesterProfile tester;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 148,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(name: tester.name, hue: tester.avatarHue, size: 28),
                  const Spacer(),
                  Icon(AppIcons.star, size: 14, color: scheme.primary),
                  const SizedBox(width: 2),
                  Text(
                    tester.ratingAvg.toStringAsFixed(1),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                tester.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                '${tester.completedCount} completed',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TesterRow extends StatelessWidget {
  const _TesterRow({
    required this.tester,
    required this.inviting,
    required this.onTap,
  });

  final TesterProfile tester;
  final bool inviting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String actionLabel;
    if (tester.alreadyMember) {
      actionLabel = 'Joined';
    } else if (tester.invitePending) {
      actionLabel = 'Invited';
    } else {
      actionLabel = 'View';
    }

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.md,
            AppSpace.md,
            AppSpace.sm,
            AppSpace.md,
          ),
          child: Row(
            children: [
              _Avatar(name: tester.name, hue: tester.avatarHue, size: 44),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tester.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (tester.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        tester.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (tester.bio.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        tester.bio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpace.xs),
                    Text(
                      tester.ratingLabel,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              if (inviting)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                StatusPill(
                  label: actionLabel,
                  color: tester.canInvite
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.hue, required this.size});

  final String name;
  final int? hue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorForHue(hue, Theme.of(context).colorScheme),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PartnerTile extends StatelessWidget {
  const _PartnerTile({
    required this.partner,
    required this.pending,
    required this.proposing,
    this.onPropose,
  });

  final SwapPartner partner;
  final bool pending;
  final bool proposing;
  final VoidCallback? onPropose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final projectNames = partner.projects.map((p) => p.name).join(', ');

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.md,
          AppSpace.md,
          AppSpace.sm,
          AppSpace.md,
        ),
        child: Row(
          children: [
            _Avatar(name: partner.name, hue: partner.avatarHue, size: 44),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (projectNames.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      projectNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpace.xs),
                  Text(partner.ratingLabel, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            if (proposing)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (onPropose != null)
              FilledButton(
                onPressed: onPropose,
                child: const Text('Swap'),
              )
            else
              StatusPill(
                label: pending ? 'Proposed' : 'Unavailable',
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
