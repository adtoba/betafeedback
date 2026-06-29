import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../models/feedback.dart';
import '../widgets/structured_bug_card.dart';

enum _BugFilter { all, suggested, open, needsInfo, fixed }

enum _BugSort { newest, severity }

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
          appBar: AppBar(title: const Text('Bug summary')),
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
                    else
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
                      ],
                  ],
                ),
        );
      },
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
