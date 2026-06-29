import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import '../theme/app_icons.dart';

/// Sheet for editing an open or needs-info structured bug.
class EditBugSheet extends StatefulWidget {
  const EditBugSheet({
    super.key,
    required this.projectId,
    required this.bug,
  });

  final String projectId;
  final StructuredBug bug;

  @override
  State<EditBugSheet> createState() => _EditBugSheetState();
}

class _EditBugSheetState extends State<EditBugSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _expectedController;
  late final TextEditingController _actualController;
  late final List<TextEditingController> _stepControllers;
  late String _severity;
  bool _submitting = false;

  static const _severities = ['Critical', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    final bug = widget.bug;
    _titleController = TextEditingController(text: bug.title);
    _expectedController = TextEditingController(text: bug.expectedBehavior);
    _actualController = TextEditingController(text: bug.actualBehavior);
    _severity = bug.severity;
    _stepControllers = bug.stepsToReproduce
        .map((s) => TextEditingController(text: s))
        .toList();
    if (_stepControllers.isEmpty) {
      _stepControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _expectedController.dispose();
    _actualController.dispose();
    for (final c in _stepControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addStep() {
    setState(() => _stepControllers.add(TextEditingController()));
  }

  void _removeStep(int index) {
    if (_stepControllers.length <= 1) return;
    setState(() {
      _stepControllers.removeAt(index).dispose();
    });
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final steps = _stepControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (title.isEmpty || steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title and at least one step are required'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await AppScope.of(context).updateBug(
        projectId: widget.projectId,
        bug: StructuredBug(
          id: widget.bug.id,
          feedbackId: widget.bug.feedbackId,
          title: title,
          stepsToReproduce: steps,
          expectedBehavior: _expectedController.text.trim(),
          actualBehavior: _actualController.text.trim(),
          severity: _severity,
          status: widget.bug.status,
          structuredAt: widget.bug.structuredAt,
          fixedAt: widget.bug.fixedAt,
          reporterName: widget.bug.reporterName,
          fixNote: widget.bug.fixNote,
          fixedInReleaseId: widget.bug.fixedInReleaseId,
          fixedInReleaseVersion: widget.bug.fixedInReleaseVersion,
        ),
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit bug',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _severities.contains(_severity) ? _severity : 'Low',
              decoration: const InputDecoration(labelText: 'Severity'),
              items: [
                for (final s in _severities)
                  DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged:
                  _submitting ? null : (v) => setState(() => _severity = v!),
            ),
            const SizedBox(height: 16),
            Text(
              'Steps to reproduce',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _stepControllers.length; i++) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _stepControllers[i],
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Step ${i + 1}',
                      ),
                    ),
                  ),
                  if (_stepControllers.length > 1)
                    IconButton(
                      onPressed: _submitting ? null : () => _removeStep(i),
                      icon: const Icon(AppIcons.close, size: 18),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting ? null : _addStep,
                icon: const Icon(AppIcons.add, size: 18),
                label: const Text('Add step'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _expectedController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Expected'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actualController,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Actual'),
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
                  : const Icon(AppIcons.check, size: 18),
              label: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
