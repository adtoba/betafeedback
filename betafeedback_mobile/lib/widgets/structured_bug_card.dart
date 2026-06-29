import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import 'edit_bug_sheet.dart';
import 'fix_bug_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFixed = bug.status == BugStatus.fixed;
    final isSuggested = bug.status == BugStatus.suggested;
    final isNeedsInfo = bug.status == BugStatus.needsInfo;
    final isOpen = bug.status == BugStatus.open;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(status: bug.status),
                const Spacer(),
                _SeverityChip(severity: bug.severity),
                if (canManage && !isSuggested && !isFixed)
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
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
            if (isSuggested) ...[
              const SizedBox(height: 12),
              Text(
                'AI draft from tester feedback — review before confirming.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (isNeedsInfo) ...[
              const SizedBox(height: 12),
              Text(
                'Waiting on the tester for more details.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              bug.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                decoration: isFixed ? TextDecoration.lineThrough : null,
                height: 1.2,
              ),
            ),
            if (reporterName != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reported by $reporterName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _BugSection(
              title: 'Steps to reproduce',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: bug.stepsToReproduce
                    .asMap()
                    .entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${e.key + 1}. ${e.value}'),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            _BugSection(
              title: 'Expected',
              child: Text(bug.expectedBehavior),
            ),
            const SizedBox(height: 12),
            _BugSection(
              title: 'Actual',
              child: Text(bug.actualBehavior),
            ),
            if (isFixed) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    AppIcons.checkCircle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _fixedLabel(bug),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (bug.fixNote != null && bug.fixNote!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  bug.fixNote!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            if (isSuggested && canManage) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(AppIcons.close, size: 18),
                    label: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(AppIcons.check, size: 18),
                    label: const Text('Confirm bug'),
                  ),
                ],
              ),
            ] else if (isOpen && canManage) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => _openFixSheet(context),
                  icon: const Icon(AppIcons.check, size: 18),
                  label: const Text('Mark as fixed'),
                ),
              ),
            ] else if (isNeedsInfo && canManage) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onResume,
                  icon: const Icon(AppIcons.repeat, size: 18),
                  label: const Text('Back to open'),
                ),
              ),
            ] else if (isFixed && canManage) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReopen,
                  icon: const Icon(AppIcons.repeat, size: 18),
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
      builder: (_) => FixBugSheet(
        projectId: projectId,
        bugId: bug.id,
        releases: releases,
      ),
    ).then((_) => onMarkFixed());
  }
}

class _BugSection extends StatelessWidget {
  const _BugSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final String severity;

  Color _color(ColorScheme scheme) {
    switch (severity) {
      case 'Critical':
        return scheme.error;
      case 'High':
        return Colors.orange.shade700;
      case 'Medium':
        return Colors.amber.shade800;
      default:
        return scheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(Theme.of(context).colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        severity,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final BugStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color bg, Color fg, IconData icon, String label) = switch (status) {
      BugStatus.fixed => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          AppIcons.checkCircle,
          'Fixed',
        ),
      BugStatus.suggested => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          AppIcons.sparkles,
          'Suggested',
        ),
      BugStatus.needsInfo => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          AppIcons.flag,
          'Needs info',
        ),
      BugStatus.open => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          AppIcons.error,
          'Open',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
