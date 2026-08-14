import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';
import 'grouped_list.dart';

const kReportReasons = [
  ('spam', 'Spam or fake profile'),
  ('harassment', 'Harassment or abuse'),
  ('inappropriate', 'Inappropriate content'),
  ('other', 'Something else'),
];

/// Reason picker used to report a user or their content.
Future<bool> showReportUserSheet(
  BuildContext context, {
  required String displayName,
  required Future<void> Function(String reason, String details) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _ReportUserSheet(
      displayName: displayName,
      onSubmit: onSubmit,
    ),
  );
  return result == true;
}

/// Confirms blocking [displayName]. Returns true if the user confirmed.
Future<bool> confirmBlockUser(
  BuildContext context, {
  required String displayName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Block this person?'),
      content: Text(
        'You won\'t see $displayName in Find testers, and they won\'t see you. '
        'Pending invites and swap proposals between you are cancelled.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class _ReportUserSheet extends StatefulWidget {
  const _ReportUserSheet({
    required this.displayName,
    required this.onSubmit,
  });

  final String displayName;
  final Future<void> Function(String reason, String details) onSubmit;

  @override
  State<_ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<_ReportUserSheet> {
  String _reason = 'spam';
  final _details = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSubmit(_reason, _details.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.lg,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Report ${widget.displayName}', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppSpace.sm),
              Text(
                'We review reports within 24 hours and may remove content or accounts that break our rules.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpace.xl),
              GroupedSection(
                header: 'Reason',
                children: [
                  for (final option in kReportReasons)
                    GroupedListTile(
                      icon: option.$1 == _reason ? AppIcons.check : AppIcons.flag,
                      title: option.$2,
                      showChevron: false,
                      onTap: _submitting
                          ? null
                          : () => setState(() => _reason = option.$1),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              TextField(
                controller: _details,
                enabled: !_submitting,
                maxLength: 1000,
                maxLines: 4,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Optional details',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: AppSpace.md),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
