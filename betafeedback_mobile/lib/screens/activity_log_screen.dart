import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

import '../app/app_scope.dart';
import '../models/activity.dart';

/// A project-wide, read-only timeline of events (bugs structured, bugs marked
/// fixed). Visible to every member — testers, developers and the creator.
class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final entries = appState.activityForProject(projectId);

        return Scaffold(
          appBar: AppBar(title: const Text('Activity log')),
          body: entries.isEmpty
              ? _Empty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _ActivityTile(
                      entry: entry,
                      actorName: entry.actorName,
                      isFirst: index == 0,
                      isLast: index == entries.length - 1,
                    );
                  },
                ),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.entry,
    required this.actorName,
    required this.isFirst,
    required this.isLast,
  });

  final ActivityLog entry;
  final String actorName;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (accent, icon, verb, quoted) = switch (entry.type) {
      ActivityType.bugFixed => (
          scheme.primary,
          AppIcons.checkCircle,
          'marked as fixed',
          true,
        ),
      ActivityType.bugStructured => (
          scheme.tertiary,
          AppIcons.sparkles,
          'turned into a bug report',
          true,
        ),
      ActivityType.releaseShipped => (
          scheme.primary,
          AppIcons.rocket,
          'shipped',
          false,
        ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          Column(
            children: [
              SizedBox(
                height: 4,
                child: isFirst
                    ? null
                    : VerticalDivider(
                        color: scheme.outlineVariant,
                        width: 36,
                        thickness: 2,
                      ),
              ),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              Expanded(
                child: isLast
                    ? const SizedBox.shrink()
                    : VerticalDivider(
                        color: scheme.outlineVariant,
                        width: 36,
                        thickness: 2,
                      ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      children: [
                        TextSpan(
                          text: actorName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' $verb '),
                        TextSpan(
                          text: quoted ? '“${entry.subject}”' : entry.subject,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (entry.note != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    formatRelativeTime(entry.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.history,
                size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('No activity yet', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'When a report is structured into a bug or a bug is marked fixed, it shows up here for everyone.',
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
