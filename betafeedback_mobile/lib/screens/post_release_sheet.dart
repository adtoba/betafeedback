import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_header.dart';

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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpace.xl,
        right: AppSpace.xl,
        top: AppSpace.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.xxl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(
              title: 'Announce a release',
              subtitle:
                  'Everyone on the project is notified and it lands in the '
                  'activity trail.',
            ),
            TextFormField(
              controller: _versionController,
              decoration: const InputDecoration(
                labelText: 'Version',
                hintText: 'e.g. v1.4.0 (231)',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Add a version' : null,
            ),
            const SizedBox(height: AppSpace.lg),
            TextFormField(
              controller: _notesController,
              maxLines: 4,
              minLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What\'s new (optional)',
                hintText: 'Fixes, new features, what to retest…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpace.xxl),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post release'),
            ),
          ],
        ),
      ),
    );
  }
}
