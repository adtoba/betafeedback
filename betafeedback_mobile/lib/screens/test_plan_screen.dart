import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../models/test_item.dart';
import 'new_feedback_screen.dart';

/// The project's "What to test" plan. The creator manages the list; testers and
/// developers read it, and testers can file a report against any item.
class TestPlanScreen extends StatelessWidget {
  const TestPlanScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final project = appState.projectById(projectId);
        if (project == null) {
          return const Scaffold(body: Center(child: Text('Project not found')));
        }

        final currentUser = appState.currentUser;
        final isCreator = currentUser.id == project.creatorId;
        final isDeveloper = project.developerIds.contains(currentUser.id);
        final isTester = project.testerIds.contains(currentUser.id);
        final canManagePlan = isCreator;
        final canAddToPlan = isCreator || isDeveloper;
        final items = project.testPlan;

        return Scaffold(
          appBar: AppBar(title: const Text('What to test')),
          body: items.isEmpty
              ? _Empty(canAdd: canAddToPlan)
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, canAddToPlan ? 96 : 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _TestItemCard(
                    index: index + 1,
                    item: items[index],
                    canManage: canManagePlan,
                    canReport: isTester || isCreator,
                    onDelete: () => _removeItem(
                      context,
                      appState,
                      project.id,
                      items[index].id,
                    ),
                    onReport: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => NewFeedbackScreen(
                          projectId: project.id,
                          initialTitle: items[index].title,
                        ),
                      ),
                    ),
                  ),
                ),
          floatingActionButton: canAddToPlan
              ? FloatingActionButton.extended(
                  onPressed: () => _openAddItem(context, appState, project.id),
                  icon: const Icon(AppIcons.add),
                  label: const Text('Add item'),
                )
              : null,
        );
      },
    );
  }

  void _openAddItem(
    BuildContext context,
    AppState appState,
    String projectId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddTestItemSheet(projectId: projectId),
    );
  }

  Future<void> _removeItem(
    BuildContext context,
    AppState appState,
    String projectId,
    String itemId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.removeTestItem(projectId: projectId, itemId: itemId);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _TestItemCard extends StatelessWidget {
  const _TestItemCard({
    required this.index,
    required this.item,
    required this.canManage,
    required this.canReport,
    required this.onDelete,
    required this.onReport,
  });

  final int index;
  final TestItem item;
  final bool canManage;
  final bool canReport;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                if (canManage)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove',
                    onPressed: onDelete,
                    icon: Icon(AppIcons.close, size: 18, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
            if (item.details != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 38),
                child: Text(
                  item.details!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            if (canReport) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(AppIcons.flag, size: 18),
                    label: const Text('Report on this'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AddTestItemSheet extends StatefulWidget {
  const _AddTestItemSheet({required this.projectId});

  final String projectId;

  @override
  State<_AddTestItemSheet> createState() => _AddTestItemSheetState();
}

class _AddTestItemSheetState extends State<_AddTestItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await AppScope.of(context).addTestItem(
        projectId: widget.projectId,
        title: _titleController.text,
        details: _detailsController.text,
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add test item',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tell testers exactly what to check.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What to test',
                hintText: 'e.g. Complete a checkout with a promo code',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Add a short instruction' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _detailsController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Steps, context, or what "done" looks like',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(AppIcons.add, size: 18),
              label: const Text('Add to plan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.canAdd});

  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.listChecks,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No test plan yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              canAdd
                  ? 'Add items to tell your testers exactly what to focus on.'
                  : 'The creator hasn\'t added testing instructions yet.',
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
