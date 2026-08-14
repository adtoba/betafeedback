import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/tester.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped_list.dart';
import '../widgets/marketplace_mode_switch.dart';
import '../widgets/marketplace_person.dart';
import '../widgets/plan_picker_sheet.dart';
import '../widgets/report_user_sheet.dart';
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

class _FindTestersScreenState extends State<FindTestersScreen> {
  final _search = TextEditingController();
  int _modeIndex = 0;
  List<TesterProfile> _testers = [];
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
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
        appState.loadSwapPartners(
          projectId: widget.projectId,
          query: _search.text,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _testers = List<TesterProfile>.from(results[0] as List<TesterProfile>)
          ..sort(TesterProfile.compareByRating);
        _partners = List<SwapPartner>.from(results[1] as List<SwapPartner>)
          ..sort(SwapPartner.compareByRating);
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
        onReport: () => _reportUser(
          userId: tester.id,
          displayName: tester.displayLabel,
        ),
        onBlock: () async {
          final blocked = await _blockUser(
            userId: tester.id,
            displayName: tester.displayLabel,
          );
          if (blocked && sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  }

  Future<void> _showPartner(SwapPartner partner) async {
    final pending = partner.swapPending || _proposed.contains(partner.id);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _SwapPartnerSheet(
        partner: partner,
        proposing: _proposing.contains(partner.id),
        pending: pending,
        onPropose: partner.canPropose && !pending
            ? () async {
                Navigator.of(sheetContext).pop();
                await _proposeSwap(partner);
              }
            : null,
        onReport: () => _reportUser(
          userId: partner.id,
          displayName: partner.displayLabel,
        ),
        onBlock: () async {
          final blocked = await _blockUser(
            userId: partner.id,
            displayName: partner.displayLabel,
          );
          if (blocked && sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );
  }

  Future<void> _reportUser({
    required String userId,
    required String displayName,
  }) async {
    final reported = await showReportUserSheet(
      context,
      displayName: displayName,
      onSubmit: (reason, details) => AppScope.of(context).reportUser(
        userId: userId,
        reason: reason,
        details: details,
      ),
    );
    if (!reported || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted. We\'ll review it within 24 hours.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _blockUser({
    required String userId,
    required String displayName,
  }) async {
    final confirmed = await confirmBlockUser(
      context,
      displayName: displayName,
    );
    if (!confirmed || !mounted) return false;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).blockUser(userId);
      if (!mounted) return false;
      setState(() {
        _testers = [for (final t in _testers) if (t.id != userId) t];
        _partners = [for (final p in _partners) if (p.id != userId) p];
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('$displayName is blocked'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
      return false;
    }
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
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invite sent to ${tester.displayLabel}'),
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

    final appState = AppScope.of(context);
    if (!appState.isPro) {
      showUpgradeSheet(
        context,
        appState,
        title: 'Test-for-test is on Pro',
      );
      return;
    }

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
                  'Which of ${partner.displayLabel}\'s projects will you test?',
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
          'You\'ll invite ${partner.displayLabel} to test your project, and you\'ll '
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
          content: Text('Swap proposed to ${partner.displayLabel}'),
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

  Widget? _testerTrailing(TesterProfile tester, bool inviting) {
    if (inviting) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    if (tester.alreadyMember) {
      return StatusPill(label: 'Joined', color: scheme.onSurfaceVariant);
    }
    if (tester.invitePending) {
      return StatusPill(label: 'Invited', color: scheme.primary);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final onSwaps = _modeIndex == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recruit'),
        actions: [
          if (widget.showSkip)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
        ],
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
                AppSpace.xxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // if (widget.projectName.isNotEmpty) ...[
                  //   Text(
                  //     widget.projectName.toUpperCase(),
                  //     style: theme.textTheme.labelSmall,
                  //   ),
                  //   const SizedBox(height: AppSpace.xs),
                  // ],
                  // Text(headline, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpace.lg),
                  MarketplaceModeSwitch(
                    index: _modeIndex,
                    onChanged: (i) => setState(() => _modeIndex = i),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  MarketplaceSearchField(
                    controller: _search,
                    onSearch: _load,
                  ),
                ],
              ),
            ),
            Expanded(
              child: onSwaps ? _swapBody() : _inviteBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _partnerTrailing(
    SwapPartner partner,
    bool proposing,
    bool pending,
  ) {
    if (proposing) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    if (partner.canPropose && !pending) {
      return TextButton(
        onPressed: () => _proposeSwap(partner),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
        ),
        child: const Text('Propose'),
      );
    }
    return StatusPill(
      label: pending ? 'Proposed' : 'Unavailable',
      color: scheme.onSurfaceVariant,
    );
  }

  Widget _inviteBody() {
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
            ? 'No opted-in testers match that email.'
            : 'When people opt in on their profile, they\'ll show up here. '
                  'You can still invite by email from the project.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
        children: [
          GroupedSection(
            header: _search.text.trim().isEmpty ? 'Open to test' : 'Results',
            children: [
              for (final tester in _testers)
                MarketplacePersonRow(
                  name: tester.displayLabel,
                  hue: tester.avatarHue,
                  subtitle: tester.marketplaceSubtitle,
                  trailing: _testerTrailing(
                    _withLocalInviteState(tester),
                    _inviting.contains(tester.id),
                  ),
                  onTap: () => _showTester(tester),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _swapBody() {
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
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxxl),
        children: [
          GroupedSection(
            header: 'Open to swap',
            // footer: 'You join their project; they join yours when they accept.',
            children: [
              for (final partner in _partners)
                MarketplacePersonRow(
                  name: partner.displayLabel,
                  hue: partner.avatarHue,
                  subtitle: partner.marketplaceSubtitle,
                  trailing: _partnerTrailing(
                    partner,
                    _proposing.contains(partner.id),
                    partner.swapPending || _proposed.contains(partner.id),
                  ),
                  onTap: () => _showPartner(partner),
                ),
            ],
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
    this.onReport,
    this.onBlock,
  });

  final TesterProfile tester;
  final bool inviting;
  final Future<void> Function()? onInvite;
  final Future<void> Function()? onReport;
  final Future<void> Function()? onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    String statusLabel;
    Color statusColor;
    if (tester.alreadyMember) {
      statusLabel = 'On your team';
      statusColor = scheme.onSurfaceVariant;
    } else if (tester.invitePending) {
      statusLabel = 'Invite sent';
      statusColor = scheme.primary;
    } else {
      statusLabel = 'Open to test';
      statusColor = scheme.primary;
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
              Row(
                children: [
                  PersonAvatar(
                    name: tester.displayLabel,
                    hue: tester.avatarHue,
                    size: 52,
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tester.displayLabel,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpace.xxs),
                        // Text(
                        //   tester.marketplaceSubtitle,
                        //   style: theme.textTheme.bodySmall?.copyWith(
                        //     color: scheme.onSurfaceVariant,
                        //   ),
                        // ),
                        const SizedBox(height: AppSpace.sm),
                        StatusPill(label: statusLabel, color: statusColor),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              GroupedSection(
                children: [
                  GroupedListTile(
                    icon: AppIcons.star,
                    title: 'Rating',
                    subtitle: tester.ratingCount == 0
                        ? 'No ratings yet'
                        : tester.ratingAvg.toStringAsFixed(1),
                    showChevron: false,
                  ),
                  GroupedListTile(
                    icon: AppIcons.feedback,
                    title: 'Reviews',
                    subtitle: '${tester.ratingCount}',
                    showChevron: false,
                  ),
                  GroupedListTile(
                    icon: AppIcons.check,
                    title: 'Completed tests',
                    subtitle: '${tester.completedCount}',
                    showChevron: false,
                  ),
                ],
              ),
              if (tester.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                GroupedSection(
                  header: 'Bio',
                  children: [GroupedNote(tester.bio)],
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
                    tester.alreadyMember ? 'Already on team' : 'Invite sent',
                  ),
                ),
              if (onReport != null || onBlock != null) ...[
                const SizedBox(height: AppSpace.lg),
                if (onReport != null)
                  OutlinedButton(
                    onPressed: () => onReport!(),
                    child: const Text('Report'),
                  ),
                if (onBlock != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  TextButton(
                    onPressed: () => onBlock!(),
                    child: Text(
                      'Block',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapPartnerSheet extends StatelessWidget {
  const _SwapPartnerSheet({
    required this.partner,
    required this.proposing,
    required this.pending,
    this.onPropose,
    this.onReport,
    this.onBlock,
  });

  final SwapPartner partner;
  final bool proposing;
  final bool pending;
  final Future<void> Function()? onPropose;
  final Future<void> Function()? onReport;
  final Future<void> Function()? onBlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

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
              Row(
                children: [
                  PersonAvatar(
                    name: partner.displayLabel,
                    hue: partner.avatarHue,
                    size: 52,
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.displayLabel,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpace.sm),
                        StatusPill(
                          label: pending ? 'Proposed' : 'Open to swap',
                          color: pending
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (partner.bio.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                GroupedSection(
                  header: 'Bio',
                  children: [GroupedNote(partner.bio)],
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              if (proposing)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (onPropose != null)
                FilledButton(
                  onPressed: () => onPropose!(),
                  child: const Text('Propose swap'),
                )
              else
                OutlinedButton(
                  onPressed: null,
                  child: Text(pending ? 'Swap proposed' : 'Unavailable'),
                ),
              if (onReport != null || onBlock != null) ...[
                const SizedBox(height: AppSpace.lg),
                if (onReport != null)
                  OutlinedButton(
                    onPressed: () => onReport!(),
                    child: const Text('Report'),
                  ),
                if (onBlock != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  TextButton(
                    onPressed: () => onBlock!(),
                    child: Text(
                      'Block',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
