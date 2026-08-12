import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/tester.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped_list.dart';
import '../widgets/plan_picker_sheet.dart';
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
    final appState = AppScope.of(context);
    if (!appState.isPro) {
      showUpgradeSheet(
        context,
        appState,
        title: 'Test-for-test is on Pro',
      );
      return;
    }

    setState(() => _busy.add(swap.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.acceptSwap(swap.id);
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
          appBar: AppBar(title: const Text('Swaps')),
          body: AppLayout.adaptiveBody(
            context,
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? AppEmptyState(
                    icon: AppIcons.error,
                    title: 'Couldn\'t load swaps',
                    message: _error!,
                    action: TextButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  )
                : swaps.isEmpty
                ? const AppEmptyState(
                    icon: AppIcons.repeat,
                    title: 'No swaps yet',
                    message:
                        'Propose a test-for-test from Recruit. You join their '
                        'project, they join yours.',
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
                          GroupedSection(
                            header: 'Incoming',
                            footer: 'Accept to join their project and add them '
                                'as a tester on yours.',
                            children: [
                              for (final swap in incoming)
                                _SwapExchangeRow(
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
                            ],
                          ),
                          const SizedBox(height: AppSpace.xl),
                        ],
                        if (outgoing.isNotEmpty) ...[
                          GroupedSection(
                            header: 'Outgoing',
                            children: [
                              for (final swap in outgoing)
                                _SwapExchangeRow(
                                  swap: swap,
                                  meId: me,
                                  busy: _busy.contains(swap.id),
                                  onCancel: () => _cancel(swap),
                                  onOpenTheirs: () =>
                                      _openProject(swap.toProjectId),
                                  onOpenYours: () =>
                                      _openProject(swap.fromProjectId),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpace.xl),
                        ],
                        if (active.isNotEmpty)
                          GroupedSection(
                            header: 'Active',
                            children: [
                              for (final swap in active)
                                _SwapExchangeRow(
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
                          ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _SwapExchangeRow extends StatelessWidget {
  const _SwapExchangeRow({
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md + 2,
        vertical: AppSpace.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  partnerName.isEmpty ? 'Creator' : partnerName,
                  style: theme.textTheme.bodyLarge,
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
          _ProjectLine(
            caption: 'You test',
            name: theirProject,
            logoUrl: theirLogo,
            onTap: onOpenTheirs,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 18, top: AppSpace.xs),
            child: Column(
              children: [
                Container(
                  width: AppStroke.hairline,
                  height: 8,
                  color: tones.hairline,
                ),
                Transform.rotate(
                  angle: 1.5708,
                  child: Icon(
                    AppIcons.arrowRight,
                    size: 14,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                ),
                Container(
                  width: AppStroke.hairline,
                  height: 8,
                  color: tones.hairline,
                ),
              ],
            ),
          ),
          _ProjectLine(
            caption: 'They test',
            name: myProject,
            logoUrl: myLogo,
            onTap: onOpenYours,
          ),
          if (swap.message.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Text(
              swap.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
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
    );
  }
}

class _ProjectLine extends StatelessWidget {
  const _ProjectLine({
    required this.caption,
    required this.name,
    this.logoUrl,
    this.onTap,
  });

  final String caption;
  final String name;
  final String? logoUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.xs,
            horizontal: AppSpace.xxs,
          ),
          child: Row(
            children: [
              ProjectLogo(
                projectName: name,
                logoUrl: logoUrl,
                size: 32,
                borderRadius: 8,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpace.xxs),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
