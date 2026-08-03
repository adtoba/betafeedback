import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped_list.dart';

import '../app/app_scope.dart';
import '../models/app_notification.dart';
import 'project_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh, then mark everything read once the user opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = AppScope.of(context);
      await appState.loadNotifications();
      await appState.markNotificationsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final items = appState.myNotifications;

        return Scaffold(
          appBar: AppBar(title: const Text('Notifications')),
          body: AppLayout.adaptiveBody(
            context,
            items.isEmpty
                ? const AppEmptyState(
                    icon: AppIcons.bell,
                    title: "You're all caught up",
                    message:
                        'Release announcements and project updates land '
                        'here as they happen.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.gutter,
                      AppSpace.md,
                      AppSpace.gutter,
                      AppSpace.xxl,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpace.sm),
                    itemBuilder: (context, index) => _NotificationTile(
                      notification: items[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailScreen(
                            projectId: items[index].projectId,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = switch (notification.kind) {
      NotificationKind.release => scheme.tertiary,
    };

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: _iconFor(notification.kind), tint: tint, size: 34),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          formatRelativeTime(notification.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.xxs + 1),
                    Text(
                      notification.body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(NotificationKind kind) => switch (kind) {
    NotificationKind.release => AppIcons.rocket,
  };
}
