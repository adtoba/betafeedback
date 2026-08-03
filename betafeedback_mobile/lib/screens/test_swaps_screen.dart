import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/tester.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_logo.dart';
import '../widgets/status_pill.dart';
import 'project_detail_screen.dart';

/// Inbox of test-for-test swap proposals.
class TestSwapsScreen extends StatefulWidget {
  const TestSwapsScreen({super.key});

  @override
  State<TestSwapsScreen> createState() => _TestSwapsScreenState();
}

class _TestSwapsScreenState extends State<TestSwapsScreen> {
  bool _loading = true;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.of(context).loadSwaps();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _accept(TestSwap swap) async {
    setState(() => _busy.add(swap.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).acceptSwap(swap.id);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Swap accepted — you\'re testing ${swap.fromProjectName}',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => _openProject(swap.fromProjectId),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(swap.id));
    }
  }

  Future<void> _decline(TestSwap swap) async {
    setState(() => _busy.add(swap.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).declineSwap(swap.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(swap.id));
    }
  }

  Future<void> _cancel(TestSwap swap) async {
    setState(() => _busy.add(swap.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).cancelSwap(swap.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(swap.id));
    }
  }

  void _openProject(String projectId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final me = appState.currentUser.id;
        final swaps = appState.swaps;
        final incoming = swaps
            .where((s) => s.toUserId == me && s.isPending)
            .toList();
        final outgoing = swaps
            .where((s) => s.fromUserId == me && s.isPending)
            .toList();
        final active = swaps
            .where(
              (s) =>
                  s.status == TestSwapStatus.accepted ||
                  s.status == TestSwapStatus.fulfilled,
            )
            .toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Test-for-test')),
          body: AppLayout.adaptiveBody(
            context,
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? AppEmptyState(
                    icon: AppIcons.error,
                    title: 'Couldn\'t load swaps',
                    message: _error!,
                    action: TextButton(onPressed: _refresh, child: const Text('Retry')),
                  )
                : swaps.isEmpty
                ? const AppEmptyState(
                    icon: AppIcons.repeat,
                    title: 'No swaps yet',
                    message:
                        'Propose a test-for-test from Find testers — you join '
                        'their project, they join yours.',
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      padding: const EdgeInsets.only(
                        top: AppSpace.sm,
                        bottom: AppSpace.xxxl,
                      ),
                      children: [
                        if (incoming.isNotEmpty) ...[
                          _SectionHeader(title: 'Incoming'),
                          for (final swap in incoming)
                            _SwapCard(
                              swap: swap,
                              meId: me,
                              busy: _busy.contains(swap.id),
                              onAccept: () => _accept(swap),
                              onDecline: () => _decline(swap),
                              onOpenTheirs: () =>
                                  _openProject(swap.fromProjectId),
                              onOpenYours: () =>
                                  _openProject(swap.toProjectId),
                            ),
                          const SizedBox(height: AppSpace.xl),
                        ],
                        if (outgoing.isNotEmpty) ...[
                          _SectionHeader(title: 'Outgoing'),
                          for (final swap in outgoing)
                            _SwapCard(
                              swap: swap,
                              meId: me,
                              busy: _busy.contains(swap.id),
                              onCancel: () => _cancel(swap),
                              onOpenTheirs: () =>
                                  _openProject(swap.toProjectId),
                              onOpenYours: () =>
                                  _openProject(swap.fromProjectId),
                            ),
                          const SizedBox(height: AppSpace.xl),
                        ],
                        if (active.isNotEmpty) ...[
                          _SectionHeader(title: 'Active'),
                          for (final swap in active)
                            _SwapCard(
                              swap: swap,
                              meId: me,
                              busy: false,
                              onOpenTheirs: () => _openProject(
                                swap.fromUserId == me
                                    ? swap.toProjectId
                                    : swap.fromProjectId,
                              ),
                              onOpenYours: () => _openProject(
                                swap.fromUserId == me
                                    ? swap.fromProjectId
                                    : swap.toProjectId,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter + AppSpace.xs,
        0,
        AppSpace.gutter,
        AppSpace.sm,
      ),
      child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class _SwapCard extends StatelessWidget {
  const _SwapCard({
    required this.swap,
    required this.meId,
    required this.busy,
    this.onAccept,
    this.onDecline,
    this.onCancel,
    this.onOpenTheirs,
    this.onOpenYours,
  });

  final TestSwap swap;
  final String meId;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;
  final VoidCallback? onOpenTheirs;
  final VoidCallback? onOpenYours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final iAmRecipient = swap.toUserId == meId;
    final partnerName = iAmRecipient ? swap.fromUserName : swap.toUserName;
    final myProject = iAmRecipient ? swap.toProjectName : swap.fromProjectName;
    final theirProject =
        iAmRecipient ? swap.fromProjectName : swap.toProjectName;
    final myLogo =
        iAmRecipient ? swap.toProjectLogoUrl : swap.fromProjectLogoUrl;
    final theirLogo =
        iAmRecipient ? swap.fromProjectLogoUrl : swap.toProjectLogoUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tones.hairline, width: AppStroke.hairline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      partnerName.isEmpty ? 'Partner' : partnerName,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  StatusPill(
                    label: testSwapStatusLabel(swap.status),
                    color: switch (swap.status) {
                      TestSwapStatus.pending => scheme.primary,
                      TestSwapStatus.accepted => scheme.tertiary,
                      TestSwapStatus.fulfilled => scheme.tertiary,
                      TestSwapStatus.declined => scheme.error,
                      TestSwapStatus.cancelled => scheme.onSurfaceVariant,
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  Expanded(
                    child: _ProjectChip(
                      name: theirProject,
                      logoUrl: theirLogo,
                      caption: 'You test',
                      onTap: onOpenTheirs,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                    child: Icon(
                      AppIcons.repeat,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Expanded(
                    child: _ProjectChip(
                      name: myProject,
                      logoUrl: myLogo,
                      caption: 'They test',
                      onTap: onOpenYours,
                    ),
                  ),
                ],
              ),
              if (swap.message.isNotEmpty) ...[
                const SizedBox(height: AppSpace.md),
                Text(swap.message, style: theme.textTheme.bodySmall),
              ],
              if (onAccept != null || onDecline != null || onCancel != null) ...[
                const SizedBox(height: AppSpace.lg),
                if (busy)
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  Row(
                    children: [
                      if (onDecline != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onDecline,
                            child: const Text('Decline'),
                          ),
                        ),
                      if (onDecline != null && onAccept != null)
                        const SizedBox(width: AppSpace.sm),
                      if (onAccept != null)
                        Expanded(
                          child: FilledButton(
                            onPressed: onAccept,
                            child: const Text('Accept'),
                          ),
                        ),
                      if (onCancel != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            child: const Text('Cancel'),
                          ),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    required this.name,
    this.logoUrl,
    required this.caption,
    this.onTap,
  });

  final String name;
  final String? logoUrl;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              ProjectLogo(
                projectName: name,
                logoUrl: logoUrl,
                size: 28,
                borderRadius: 7,
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
