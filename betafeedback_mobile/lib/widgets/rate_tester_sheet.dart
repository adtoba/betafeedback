import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/user.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import 'app_header.dart';

/// Bottom sheet for a creator to rate a tester on a project.
Future<void> showRateTesterSheet(
  BuildContext context, {
  required String projectId,
  required User tester,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RateTesterSheet(projectId: projectId, tester: tester),
  );
}

class _RateTesterSheet extends StatefulWidget {
  const _RateTesterSheet({required this.projectId, required this.tester});

  final String projectId;
  final User tester;

  @override
  State<_RateTesterSheet> createState() => _RateTesterSheetState();
}

class _RateTesterSheetState extends State<_RateTesterSheet> {
  int _score = 5;
  final _comment = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await AppScope.of(context).rateTester(
        projectId: widget.projectId,
        testerId: widget.tester.id,
        score: _score,
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Rated ${widget.tester.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    final name = widget.tester.name.isEmpty
        ? widget.tester.email
        : widget.tester.name;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                title: 'Rate $name',
                subtitle: 'Scores help surface top testers across the platform.',
              ),
              const SizedBox(height: AppSpace.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setState(() => _score = i),
                      icon: Icon(
                        AppIcons.star,
                        color: i <= _score
                            ? scheme.primary
                            : scheme.onSurfaceVariant.withValues(alpha: 0.35),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.lg),
              TextField(
                controller: _comment,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'What stood out about their testing?',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpace.lg),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit rating'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
