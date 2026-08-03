import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';

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
          appBar: AppBar(title: const Text('Activity')),
          body: AppLayout.adaptiveBody(
            context,
            entries.isEmpty
                ? const AppEmptyState(
                    icon: AppIcons.history,
                    title: 'Nothing has happened yet',
                    message:
                        'Structured bugs, fixes, and shipped releases '
                        'show up here for the whole team.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl,
                      AppSpace.xl,
                      AppSpace.gutter,
                      AppSpace.xxl,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) => _ActivityRow(
                      entry: entries[index],
                      actorName: entries[index].actorName,
                      isFirst: index == 0,
                      isLast: index == entries.length - 1,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
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
    final tones = AppTones.of(context);

    final (accent, icon, verb, quoted) = switch (entry.type) {
      ActivityType.bugFixed => (
        scheme.tertiary,
        AppIcons.checkCircle,
        'marked as fixed',
        true,
      ),
      ActivityType.bugStructured => (
        scheme.secondary,
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
          SizedBox(
            width: 30,
            child: Column(
              children: [
                SizedBox(
                  height: AppSpace.xs,
                  child: isFirst ? null : _Rail(color: tones.hairline),
                ),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 15, color: accent),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : _Rail(color: tones.hairline),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.md + 2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpace.xs,
                bottom: AppSpace.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: actorName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                    const SizedBox(height: AppSpace.xs),
                    Text(entry.note!, style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: AppSpace.xs),
                  Text(
                    formatRelativeTime(entry.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0,
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

class _Rail extends StatelessWidget {
  const _Rail({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: AppStroke.thin,
        child: ColoredBox(color: color),
      ),
    );
  }
}
