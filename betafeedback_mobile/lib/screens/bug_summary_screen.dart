import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_icons.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../models/feedback.dart';
import '../models/release.dart';
import '../widgets/fix_bug_sheet.dart';
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
      _BugFilter.suggested =>
        bugs.where((b) => b.status == BugStatus.suggested),
      _BugFilter.open => bugs.where((b) => b.status == BugStatus.open),
      _BugFilter.needsInfo =>
        bugs.where((b) => b.status == BugStatus.needsInfo),
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

        final currentUser = appState.currentUser;
        final canManage = currentUser.id == project.creatorId ||
            project.developerIds.contains(currentUser.id);

        final bugs = project.structuredBugs;
        final suggested =
            bugs.where((b) => b.status == BugStatus.suggested).length;
        final open = bugs.where((b) => b.status == BugStatus.open).length;
        final needsInfo =
            bugs.where((b) => b.status == BugStatus.needsInfo).length;
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
          body: bugs.isEmpty
              ? _EmptyBugs()
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '$suggested',
                            label: 'Suggested',
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            value: '$open',
                            label: 'Open',
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            value: '$needsInfo',
                            label: 'Needs info',
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            value: '$fixed',
                            label: 'Fixed',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final entry in [
                            (_BugFilter.all, 'All'),
                            (_BugFilter.suggested, 'Suggested'),
                            (_BugFilter.open, 'Open'),
                            (_BugFilter.needsInfo, 'Needs info'),
                            (_BugFilter.fixed, 'Fixed'),
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: DropdownButton<_BugSort>(
                        value: _sort,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: _BugSort.newest,
                            child: Text('Newest first'),
                          ),
                          DropdownMenuItem(
                            value: _BugSort.severity,
                            child: Text('By severity'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _sort = v);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'No bugs match this filter.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      )
                    else if (_viewMode == _BugViewMode.cards)
                      for (final bug in visible) ...[
                        StructuredBugCard(
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
                        const SizedBox(height: 12),
                      ]
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (var i = 0; i < visible.length; i++) ...[
                              if (i > 0) const Divider(height: 1),
                              _BugChecklistTile(
                                bug: visible[i],
                                canManage: canManage,
                                onTap: () => _showBugDetail(
                                  context,
                                  appState: appState,
                                  projectId: project.id,
                                  releases: project.releases,
                                  bug: visible[i],
                                  canManage: canManage,
                                ),
                                onConfirm: () => _confirm(
                                  context,
                                  appState,
                                  project.id,
                                  visible[i].id,
                                ),
                                onMarkFixed: () => _openFixSheet(
                                  context,
                                  project.id,
                                  visible[i].id,
                                  project.releases,
                                ),
                                onReopen: () => _reopen(
                                  context,
                                  appState,
                                  project.id,
                                  visible[i].id,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
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
      builder: (_) => FixBugSheet(
        projectId: projectId,
        bugId: bugId,
        releases: releases,
      ),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: StructuredBugCard(
            bug: bug,
            projectId: projectId,
            releases: releases,
            reporterName: bug.reporterName,
            canManage: canManage,
            onMarkFixed: () {},
            onConfirm: () => _confirm(
              sheetContext,
              appState,
              projectId,
              bug.id,
            ),
            onDismiss: () => _dismiss(
              sheetContext,
              appState,
              projectId,
              bug.id,
            ),
            onNeedsInfo: () => _needsInfo(
              sheetContext,
              appState,
              projectId,
              bug.id,
            ),
            onResume: () => _resume(
              sheetContext,
              appState,
              projectId,
              bug.id,
            ),
            onReopen: () => _reopen(
              sheetContext,
              appState,
              projectId,
              bug.id,
            ),
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
    final isFixed = bug.status == BugStatus.fixed;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _isChecked,
              onChanged: _canToggle ? _onCheckChanged : null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 8, bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bug.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isFixed ? TextDecoration.lineThrough : null,
                        color: isFixed ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${bug.severity} · ${_statusLabel(bug.status)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(BugStatus status) => switch (status) {
        BugStatus.suggested => 'Suggested',
        BugStatus.open => 'Open',
        BugStatus.needsInfo => 'Needs info',
        BugStatus.fixed => 'Fixed',
      };
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _EmptyBugs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.sparkles,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No structured bugs yet',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'When testers submit feedback, we automatically draft a structured bug for you to review and confirm. Drafts show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
