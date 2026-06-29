import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../app/app_scope.dart';

/// Sheet developers (or the creator) use to announce a new build. Posts to the
/// activity trail and notifies every other member.
class PostReleaseSheet extends StatefulWidget {
  const PostReleaseSheet({super.key, required this.projectId});

  final String projectId;

  @override
  State<PostReleaseSheet> createState() => _PostReleaseSheetState();
}

class _PostReleaseSheetState extends State<PostReleaseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _versionController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _versionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await AppScope.of(context).postRelease(
        projectId: widget.projectId,
        version: _versionController.text,
        notes: _notesController.text,
      );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Release announced to the team'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
            Row(
              children: [
                Icon(AppIcons.rocket, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Announce a release',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Everyone on the project gets notified.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _versionController,
              decoration: const InputDecoration(
                labelText: 'Version',
                hintText: 'e.g. v1.4.0 (231)',
                prefixIcon: Icon(AppIcons.tag),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Add a version' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: "What's new (optional)",
                hintText: 'Fixes, new features, what to retest…',
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
                  : const Icon(AppIcons.megaphone, size: 18),
              label: const Text('Post release'),
            ),
          ],
        ),
      ),
    );
  }
}
