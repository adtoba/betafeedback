import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../models/feedback.dart';
import '../models/release.dart';
import '../widgets/empty_state.dart';
import '../widgets/fix_bug_sheet.dart';
import '../widgets/grouped_list.dart';
import '../widgets/metric_strip.dart';
import '../widgets/status_pill.dart';
import '../widgets/structured_bug_card.dart';

enum _BugFilter { all, suggested, open, needsInfo, fixed }

enum _BugSort { newest, severity }

enum _BugViewMode { cards, checklist }

const _viewModeKey = 'bug_summary_view_mode';

/// A read-and-act view of every AI-structured bug in a project, with summary
/// counts at the top.
class BugSummaryScreen extends StatefulWidget {
  const BugSummaryScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<BugSummaryScreen> createState() => _BugSummaryScreenState();
}

class _BugSummaryScreenState extends State<BugSummaryScreen> {
  _BugFilter _filter = _BugFilter.all;
  _BugSort _sort = _BugSort.newest;
  _BugViewMode _viewMode = _BugViewMode.cards;

  @override
  void initState() {
    super.initState();
    _loadViewMode();
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_viewModeKey);
    if (stored == null || !mounted) return;
    setState(() {
      _viewMode = _BugViewMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => _BugViewMode.cards,
      );
    });
  }

  Future<void> _setViewMode(_BugViewMode mode) async {
    if (_viewMode == mode) return;
    setState(() => _viewMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode.name);
  }

  List<StructuredBug> _filtered(List<StructuredBug> bugs) {
    final filtered = switch (_filter) {
      _BugFilter.all => bugs,
      _BugFilter.suggested => bugs.where(
        (b) => b.status == BugStatus.suggested,
      ),
      _BugFilter.open => bugs.where((b) => b.status == BugStatus.open),
      _BugFilter.needsInfo => bugs.where(
        (b) => b.status == BugStatus.needsInfo,
      ),
      _BugFilter.fixed => bugs.where((b) => b.status == BugStatus.fixed),
    }.toList();

    if (_sort == _BugSort.severity) {
      const order = {'Critical': 0, 'High': 1, 'Medium': 2, 'Low': 3};
      filtered.sort((a, b) {
        final sa = order[a.severity] ?? 4;
        final sb = order[b.severity] ?? 4;
        if (sa != sb) return sa.compareTo(sb);
        return b.structuredAt.compareTo(a.structuredAt);
      });
    } else {
      filtered.sort((a, b) => b.structuredAt.compareTo(a.structuredAt));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final project = appState.projectById(widget.projectId);
        if (project == null) {
          return const Scaffold(body: Center(child: Text('Project not found')));
        }

        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final tones = AppTones.of(context);
        final currentUser = appState.currentUser;
        final canManage =
            currentUser.id == project.creatorId ||
            project.developerIds.contains(currentUser.id);

        final bugs = project.structuredBugs;
        final suggested = bugs
            .where((b) => b.status == BugStatus.suggested)
            .length;
        final open = bugs.where((b) => b.status == BugStatus.open).length;
        final needsInfo = bugs
            .where((b) => b.status == BugStatus.needsInfo)
            .length;
        final fixed = bugs.where((b) => b.status == BugStatus.fixed).length;
        final visible = _filtered(bugs);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Bug summary'),
            actions: [
              IconButton(
                tooltip: _viewMode == _BugViewMode.cards
                    ? 'Switch to checklist'
                    : 'Switch to detailed cards',
                onPressed: () => _setViewMode(
                  _viewMode == _BugViewMode.cards
                      ? _BugViewMode.checklist
                      : _BugViewMode.cards,
                ),
                icon: Icon(
                  _viewMode == _BugViewMode.cards
                      ? AppIcons.listChecks
                      : AppIcons.layoutList,
                ),
              ),
            ],
          ),
          body: AppLayout.adaptiveBody(
            context,
            bugs.isEmpty
                ? const AppEmptyState(
                    icon: AppIcons.sparkles,
                    title: 'No structured bugs yet',
                    message:
                        'When testers file reports we draft a structured '
                        'bug for you to review. Drafts land here.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      AppSpace.lg,
                      0,
                      AppSpace.xxl,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.gutter,
                        ),
                        child: MetricStrip(
                          metrics: [
                            Metric(
                              label: 'To review',
                              value: '$suggested',
                              tint: suggested > 0 ? scheme.secondary : null,
                            ),
                            Metric(
                              label: 'Open',
                              value: '$open',
                              tint: open > 0 ? tones.warning : null,
                            ),
                            Metric(label: 'Blocked', value: '$needsInfo'),
                            Metric(label: 'Fixed', value: '$fixed'),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.xl),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.gutter,
                        ),
                        child: Row(
                          children: [
                            for (final entry in [
                              (_BugFilter.all, 'All'),
                              (_BugFilter.suggested, 'To review'),
                              (_BugFilter.open, 'Open'),
                              (_BugFilter.needsInfo, 'Blocked'),
                              (_BugFilter.fixed, 'Fixed'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpace.sm - 2,
                                ),
                                child: FilterChip(
                                  label: Text(entry.$2),
                                  selected: _filter == entry.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = entry.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          AppSpace.sm,
                          AppSpace.sm,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PopupMenuButton<_BugSort>(
                              initialValue: _sort,
                              tooltip: 'Sort',
                              onSelected: (v) => setState(() => _sort = v),
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: _BugSort.newest,
                                  child: Text('Newest first'),
                                ),
                                PopupMenuItem(
                                  value: _BugSort.severity,
                                  child: Text('By severity'),
                                ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpace.sm),
                                child: Row(
                                  children: [
                                    Text(
                                      _sort == _BugSort.newest
                                          ? 'Newest first'
                                          : 'By severity',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(color: scheme.primary),
                                    ),
                                    const SizedBox(width: AppSpace.xs),
                                    Icon(
                                      AppIcons.chevronRight,
                                      size: 15,
                                      color: scheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpace.md),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.gutter,
                            vertical: AppSpace.xl,
                          ),
                          child: Text(
                            'Nothing matches this filter.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else if (_viewMode == _BugViewMode.cards)
                        for (final bug in visible)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.gutter,
                              0,
                              AppSpace.gutter,
                              AppSpace.md,
                            ),
                            child: StructuredBugCard(
                              bug: bug,
                              projectId: project.id,
                              releases: project.releases,
                              reporterName: bug.reporterName,
                              canManage: canManage,
                              onMarkFixed: () {},
                              onConfirm: () => _confirm(
                                context,
                                appState,
                                project.id,
                                bug.id,
                              ),
                              onDismiss: () => _dismiss(
                                context,
                                appState,
                                project.id,
                                bug.id,
                              ),
                              onNeedsInfo: () => _needsInfo(
                                context,
                                appState,
                                project.id,
                                bug.id,
                              ),
                              onResume: () => _resume(
                                context,
                                appState,
                                project.id,
                                bug.id,
                              ),
                              onReopen: () => _reopen(
                                context,
                                appState,
                                project.id,
                                bug.id,
                              ),
                            ),
                          )
                      else
                        GroupedSection(
                          children: [
                            for (final bug in visible)
                              _BugChecklistTile(
                                bug: bug,
                                canManage: canManage,
                                onTap: () => _showBugDetail(
                                  context,
                                  appState: appState,
                                  projectId: project.id,
                                  releases: project.releases,
                                  bug: bug,
                                  canManage: canManage,
                                ),
                                onConfirm: () => _confirm(
                                  context,
                                  appState,
                                  project.id,
                                  bug.id,
                                ),
                                onMarkFixed: () => _openFixSheet(
                                  context,
                                  project.id,
                                  bug.id,
                                  project.releases,
                                ),
                                onReopen: () => _reopen(
                                  context,
                                  appState,
                                  project.id,
                                  bug.id,
                                ),
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

  void _openFixSheet(
    BuildContext context,
    String projectId,
    String bugId,
    List<Release> releases,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FixBugSheet(projectId: projectId, bugId: bugId, releases: releases),
    );
  }

  void _showBugDetail(
    BuildContext context, {
    required AppState appState,
    required String projectId,
    required List<Release> releases,
    required StructuredBug bug,
    required bool canManage,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: StructuredBugCard(
            bug: bug,
            projectId: projectId,
            releases: releases,
            reporterName: bug.reporterName,
            canManage: canManage,
            onMarkFixed: () {},
            onConfirm: () =>
                _confirm(sheetContext, appState, projectId, bug.id),
            onDismiss: () =>
                _dismiss(sheetContext, appState, projectId, bug.id),
            onNeedsInfo: () =>
                _needsInfo(sheetContext, appState, projectId, bug.id),
            onResume: () => _resume(sheetContext, appState, projectId, bug.id),
            onReopen: () => _reopen(sheetContext, appState, projectId, bug.id),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    AppState appState,
    String projectId,
    String bugId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.confirmBug(projectId: projectId, bugId: bugId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _dismiss(
    BuildContext context,
    AppState appState,
    String projectId,
    String bugId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.dismissBug(projectId: projectId, bugId: bugId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _needsInfo(
    BuildContext context,
    AppState appState,
    String projectId,
    String bugId,
  ) async {
    final noteController = TextEditingController();
    final note = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request more info'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'What do you need from the tester?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, noteController.text),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    noteController.dispose();
    if (note == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.markBugNeedsInfo(
        projectId: projectId,
        bugId: bugId,
        note: note.trim(),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _resume(
    BuildContext context,
    AppState appState,
    String projectId,
    String bugId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.resumeBug(projectId: projectId, bugId: bugId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _reopen(
    BuildContext context,
    AppState appState,
    String projectId,
    String bugId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.reopenBug(projectId: projectId, bugId: bugId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _BugChecklistTile extends StatelessWidget {
  const _BugChecklistTile({
    required this.bug,
    required this.canManage,
    required this.onTap,
    required this.onConfirm,
    required this.onMarkFixed,
    required this.onReopen,
  });

  final StructuredBug bug;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onConfirm;
  final VoidCallback onMarkFixed;
  final VoidCallback onReopen;

  bool get _isChecked => bug.status == BugStatus.fixed;

  bool get _canToggle =>
      canManage &&
      (bug.status == BugStatus.suggested ||
          bug.status == BugStatus.open ||
          bug.status == BugStatus.fixed);

  void _onCheckChanged(bool? value) {
    if (value == true) {
      switch (bug.status) {
        case BugStatus.suggested:
          onConfirm();
        case BugStatus.open:
          onMarkFixed();
        case BugStatus.needsInfo:
        case BugStatus.fixed:
          break;
      }
      return;
    }
    if (value == false && bug.status == BugStatus.fixed) {
      onReopen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final isFixed = bug.status == BugStatus.fixed;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.sm,
          AppSpace.sm,
          AppSpace.md + 2,
          AppSpace.sm,
        ),
        child: Row(
          children: [
            Checkbox(
              value: _isChecked,
              onChanged: _canToggle ? _onCheckChanged : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bug.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      decoration: isFixed ? TextDecoration.lineThrough : null,
                      decorationColor: scheme.onSurfaceVariant,
                      color: isFixed ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xxs),
                  Text(bug.severity, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            StatusPill(
              label: _statusLabel(bug.status),
              color: switch (bug.status) {
                BugStatus.suggested => scheme.secondary,
                BugStatus.open => tones.warning,
                BugStatus.needsInfo => scheme.primary,
                BugStatus.fixed => scheme.tertiary,
              },
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BugStatus status) => switch (status) {
    BugStatus.suggested => 'To review',
    BugStatus.open => 'Open',
    BugStatus.needsInfo => 'Blocked',
    BugStatus.fixed => 'Fixed',
  };
}
