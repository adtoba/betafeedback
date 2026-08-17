import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/project.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import '../utils/store_compliance.dart';
import 'linkified_text.dart';

/// Full-screen view of [Project.memberNotes]. Creators can edit inline.
class MemberNotesScreen extends StatefulWidget {
  const MemberNotesScreen({
    super.key,
    required this.project,
    required this.canEdit,
  });

  final Project project;
  final bool canEdit;

  @override
  State<MemberNotesScreen> createState() => _MemberNotesScreenState();
}

class _MemberNotesScreenState extends State<MemberNotesScreen> {
  late final TextEditingController _controller;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.project.memberNotes);
    _editing = widget.canEdit && widget.project.memberNotes.trim().isEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).updateProjectMemberNotes(
        projectId: widget.project.id,
        memberNotes: _controller.text,
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Getting started notes saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notes = widget.project.memberNotes.trim();
    final showEditor = widget.canEdit && (_editing || notes.isEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting started'),
        actions: [
          if (widget.canEdit && !_editing && notes.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.gutter + AppSpace.xs,
          AppSpace.lg,
          AppSpace.gutter + AppSpace.xs,
          AppSpace.xxxl,
        ),
        children: [
          if (widget.canEdit && showEditor) ...[
            Text(
              'Share download links, install steps, and anything new members '
              'should know. Everyone on the project can read this.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            TextField(
              controller: _controller,
              autofocus: notes.isEmpty,
              maxLines: 12,
              minLines: 8,
              decoration: InputDecoration(
                hintText: memberNotesExampleHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save notes'),
            ),
          ] else if (notes.isNotEmpty)
            LinkifiedText(text: notes)
          else
            Text(
              'The creator has not added getting started notes yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact preview card for project detail.
class MemberNotesPreview extends StatelessWidget {
  const MemberNotesPreview({
    super.key,
    required this.notes,
    required this.canEdit,
    required this.onTap,
  });

  final String notes;
  final bool canEdit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trimmed = notes.trim();
    final hasNotes = trimmed.isNotEmpty;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.layoutList, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(
                    child: Text(
                      'Getting started',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  Icon(AppIcons.chevronRight, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              if (hasNotes)
                Text(
                  trimmed,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else
                Text(
                  canEdit
                      ? 'Add download links and instructions for your team'
                      : 'No notes yet',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
