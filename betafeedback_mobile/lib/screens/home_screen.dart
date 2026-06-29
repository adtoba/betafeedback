import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../widgets/project_card.dart';
import '../widgets/plan_picker_sheet.dart';
import 'create_project_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'project_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final projects = appState.myProjects;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: 'New project',
            onPressed: () => _openCreateProject(context),
            child: const Icon(AppIcons.add),
          ),
          body: SafeArea(
            child: AppLayout.adaptiveBody(
              context,
              CustomScrollView(
                slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        const Expanded(child: LargeScreenTitle('Projects')),
                        _NotificationsButton(appState: appState),
                        _AccountButton(appState: appState),
                      ],
                    ),
                  ),
                ),
                if (projects.isEmpty && appState.isLoadingProjects)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (projects.isEmpty && appState.projectsError != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(
                      message: appState.projectsError!,
                      onRetry: appState.loadProjects,
                    ),
                  )
                else if (projects.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyProjects(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            AppLayout.projectGridMaxExtent(context),
                        mainAxisExtent: 176,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final project = projects[index];
                          return ProjectCard(
                            project: project,
                            creatorName: project.creatorName,
                            hasUnread: appState.projectHasUnread(project),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProjectDetailScreen(
                                  projectId: project.id,
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: projects.length,
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
        );
      },
    );
  }

  void _openCreateProject(BuildContext context) {
    final appState = AppScope.of(context);
    if (!appState.canCreateMoreProjects) {
      showPlanPickerSheet(
        context,
        title: 'Upgrade to create more projects',
        currentPlan: appState.currentSubscription.plan,
        onSelect: (plan) => appState.changePlan(plan),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateProjectScreen()),
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final unread = appState.unreadNotificationCount;
    final scheme = Theme.of(context).colorScheme;

    return HeaderIconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      icon: AppIcons.bell,
      badge: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: scheme.error,
        label: Text('$unread'),
        child: const Icon(AppIcons.bell),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = appState.currentUser;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onSelected: (value) {
        if (value == 'signout') {
          appState.signOut();
        } else if (value == 'profile') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: avatarColorForUser(user, theme.colorScheme),
                child: Text(
                  initialsFor(user.name),
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.name.isEmpty ? user.email : user.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      'View profile',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(AppIcons.logout, size: 20),
              SizedBox(width: 10),
              Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: avatarColorForUser(user, theme.colorScheme),
          child: Text(
            initialsFor(user.name),
            style: const TextStyle(fontSize: 13, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.cloudOff,
                size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text("Couldn't load projects",
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.folder,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No projects yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Create a project, invite testers and developers, and start collecting feedback. Tap + to get started.',
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
