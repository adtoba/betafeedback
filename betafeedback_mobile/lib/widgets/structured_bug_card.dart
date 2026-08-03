import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import 'edit_bug_sheet.dart';
import 'fix_bug_sheet.dart';
import 'status_pill.dart';
import '../models/release.dart';

class StructuredBugCard extends StatelessWidget {
  const StructuredBugCard({
    super.key,
    required this.bug,
    required this.canManage,
    required this.projectId,
    required this.releases,
    required this.onMarkFixed,
    this.onConfirm,
    this.onDismiss,
    this.onEdit,
    this.onNeedsInfo,
    this.onResume,
    this.onReopen,
    this.reporterName,
  });

  final StructuredBug bug;
  final String projectId;
  final List<Release> releases;
  final bool canManage;
  final VoidCallback onMarkFixed;
  final VoidCallback? onConfirm;
  final VoidCallback? onDismiss;
  final VoidCallback? onEdit;
  final VoidCallback? onNeedsInfo;
  final VoidCallback? onResume;
  final VoidCallback? onReopen;
  final String? reporterName;

  static const ButtonStyle _actionStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 42)),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpace.lg),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFixed = bug.status == BugStatus.fixed;
    final isSuggested = bug.status == BugStatus.suggested;
    final isNeedsInfo = bug.status == BugStatus.needsInfo;
    final isOpen = bug.status == BugStatus.open;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(status: bug.status),
                const SizedBox(width: AppSpace.sm - 2),
                _SeverityChip(severity: bug.severity),
                const Spacer(),
                if (canManage && !isSuggested && !isFixed)
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    padding: EdgeInsets.zero,
                    onSelected: (action) => _handleAction(context, action),
                    itemBuilder: (context) => [
                      if (isOpen || isNeedsInfo)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit bug'),
                        ),
                      if (isOpen)
                        const PopupMenuItem(
                          value: 'needs_info',
                          child: Text('Request more info'),
                        ),
                      if (isNeedsInfo)
                        const PopupMenuItem(
                          value: 'resume',
                          child: Text('Back to open'),
                        ),
                      if (isOpen)
                        const PopupMenuItem(
                          value: 'fix',
                          child: Text('Mark as fixed'),
                        ),
                      if (isFixed)
                        const PopupMenuItem(
                          value: 'reopen',
                          child: Text('Reopen'),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpace.md + 2),
            Text(
              bug.title,
              style: theme.textTheme.titleMedium?.copyWith(
                decoration: isFixed ? TextDecoration.lineThrough : null,
                decorationColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (reporterName != null || isSuggested || isNeedsInfo) ...[
              const SizedBox(height: AppSpace.xs),
              Text(switch (bug.status) {
                BugStatus.suggested =>
                  'AI draft from tester feedback — review before confirming.',
                BugStatus.needsInfo =>
                  'Waiting on the tester for more details.',
                _ => 'Reported by $reporterName',
              }, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpace.lg),
            _BugDetails(bug: bug),
            if (isFixed) ...[
              const SizedBox(height: AppSpace.md),
              _FixedBanner(label: _fixedLabel(bug), note: bug.fixNote),
            ],
            if (isSuggested && canManage) ...[
              const SizedBox(height: AppSpace.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDismiss,
                      style: _actionStyle,
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm + 2),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: _actionStyle,
                      child: const Text('Confirm bug'),
                    ),
                  ),
                ],
              ),
            ] else if (isOpen && canManage) ...[
              const SizedBox(height: AppSpace.lg),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _openFixSheet(context),
                  style: _actionStyle,
                  icon: const Icon(AppIcons.check, size: 17),
                  label: const Text('Mark as fixed'),
                ),
              ),
            ] else if (isNeedsInfo && canManage) ...[
              const SizedBox(height: AppSpace.lg),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onResume,
                  style: _actionStyle,
                  icon: const Icon(AppIcons.repeat, size: 17),
                  label: const Text('Back to open'),
                ),
              ),
            ] else if (isFixed && canManage) ...[
              const SizedBox(height: AppSpace.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReopen,
                  icon: const Icon(AppIcons.repeat, size: 16),
                  label: const Text('Reopen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fixedLabel(StructuredBug bug) {
    final when = bug.fixedAt != null ? formatRelativeTime(bug.fixedAt!) : '';
    final version = bug.fixedInReleaseVersion;
    if (version != null && version.isNotEmpty) {
      return 'Fixed in $version${when.isNotEmpty ? ' · $when' : ''}';
    }
    return when.isNotEmpty ? 'Fixed $when' : 'Fixed';
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        onEdit?.call();
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => EditBugSheet(projectId: projectId, bug: bug),
        );
      case 'needs_info':
        onNeedsInfo?.call();
      case 'resume':
        onResume?.call();
      case 'fix':
        _openFixSheet(context);
      case 'reopen':
        onReopen?.call();
    }
  }

  void _openFixSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          FixBugSheet(projectId: projectId, bugId: bug.id, releases: releases),
    ).then((_) => onMarkFixed());
  }
}

/// Steps, expected, and actual behaviour on a sunken panel so the report body
/// reads as evidence rather than more card copy.
class _BugDetails extends StatelessWidget {
  const _BugDetails({required this.bug});

  final StructuredBug bug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    final blocks = <Widget>[
      if (bug.stepsToReproduce.isNotEmpty)
        _Block(
          label: 'Steps to reproduce',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < bug.stepsToReproduce.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == bug.stepsToReproduce.length - 1
                        ? 0
                        : AppSpace.xs + 1,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text(
                          '${i + 1}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bug.stepsToReproduce[i],
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      if (bug.expectedBehavior.isNotEmpty)
        _Block(
          label: 'Expected',
          child: Text(bug.expectedBehavior, style: theme.textTheme.bodyMedium),
        ),
      if (bug.actualBehavior.isNotEmpty)
        _Block(
          label: 'Actual',
          child: Text(bug.actualBehavior, style: theme.textTheme.bodyMedium),
        ),
    ];

    if (blocks.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpace.md + 2),
      decoration: BoxDecoration(
        color: tones.canvas,
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < blocks.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
                child: Divider(color: tones.hairline),
              ),
            blocks[i],
          ],
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: AppSpace.xs + 2),
        child,
      ],
    );
  }
}

class _FixedBanner extends StatelessWidget {
  const _FixedBanner({required this.label, this.note});

  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = theme.colorScheme.tertiary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        border: Border.all(
          color: green.withValues(alpha: 0.22),
          width: AppStroke.thin,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.checkCircle, size: 16, color: green),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(color: green),
                ),
                if (note != null && note!.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.xs),
                  Text(note!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = AppTones.of(context);
    final color = switch (severity) {
      'Critical' => scheme.error,
      'High' => tones.warning,
      'Medium' => scheme.onSurfaceVariant,
      _ => scheme.onSurfaceVariant,
    };

    return StatusPill(label: severity, color: color);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BugStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = AppTones.of(context);

    final (Color color, IconData icon, String label) = switch (status) {
      BugStatus.fixed => (scheme.tertiary, AppIcons.checkCircle, 'Fixed'),
      BugStatus.suggested => (scheme.secondary, AppIcons.sparkles, 'Suggested'),
      BugStatus.needsInfo => (scheme.primary, AppIcons.flag, 'Needs info'),
      BugStatus.open => (tones.warning, AppIcons.bug, 'Open'),
    };

    return StatusPill(label: label, color: color, icon: icon, solid: true);
  }
}
