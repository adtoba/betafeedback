import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/release.dart';
import '../theme/app_icons.dart';

/// Sheet for marking a bug fixed with an optional note and release link.
class FixBugSheet extends StatefulWidget {
  const FixBugSheet({
    super.key,
    required this.projectId,
    required this.bugId,
    required this.releases,
  });

  final String projectId;
  final String bugId;
  final List<Release> releases;

  @override
  State<FixBugSheet> createState() => _FixBugSheetState();
}

class _FixBugSheetState extends State<FixBugSheet> {
  final _noteController = TextEditingController();
  String? _releaseId;
  bool _submitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await AppScope.of(context).markBugAsFixed(
        projectId: widget.projectId,
        bugId: widget.bugId,
        note: _noteController.text.trim(),
        releaseId: _releaseId,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mark as fixed',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Optionally note what changed and link a release.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _noteController,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Fix note (optional)',
              hintText: 'What was changed or how it was resolved',
              alignLabelWithHint: true,
            ),
          ),
          if (widget.releases.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _releaseId,
              decoration: const InputDecoration(
                labelText: 'Fixed in release (optional)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No release linked'),
                ),
                for (final r in widget.releases)
                  DropdownMenuItem(
                    value: r.id,
                    child: Text(r.version),
                  ),
              ],
              onChanged: _submitting ? null : (v) => setState(() => _releaseId = v),
            ),
          ],
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
            label: const Text('Mark fixed'),
          ),
        ],
      ),
    );
  }
}
