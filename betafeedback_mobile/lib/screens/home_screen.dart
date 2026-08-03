import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../models/project.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_card.dart';
import '../widgets/plan_picker_sheet.dart';
import 'create_project_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'project_detail_screen.dart';
import 'tester_invites_screen.dart';

enum _ProjectFilter { all, created, invited }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _ProjectFilter _filter = _ProjectFilter.all;

  List<Project> _filtered(AppState appState, List<Project> all) {
    final me = appState.currentUser.id;
    return switch (_filter) {
      _ProjectFilter.all => all,
      _ProjectFilter.created =>
        all.where((p) => p.creatorId == me).toList(growable: false),
      _ProjectFilter.invited =>
        all.where((p) => p.creatorId != me).toList(growable: false),
    };
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final allProjects = appState.myProjects;
        final projects = _filtered(appState, allProjects);
        final isLoading = allProjects.isEmpty && appState.isLoadingProjects;
        final error = appState.projectsError;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            tooltip: 'New project',
            onPressed: () => _openCreateProject(context),
            child: const Icon(AppIcons.add),
          ),
          body: SafeArea(
            child: AppLayout.adaptiveBody(
              context,
              RefreshIndicator(
                onRefresh: appState.loadProjects,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          AppSpace.sm,
                          AppSpace.sm,
                          AppSpace.md,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppLargeTitle(
                                'Projects',
                                subtitle: _summary(appState, projects),
                              ),
                            ),
                            _NotificationsButton(appState: appState),
                            _TesterInvitesButton(appState: appState),
                            _AccountButton(appState: appState),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          0,
                          AppSpace.gutter,
                          AppSpace.xl,
                        ),
                        child: Row(
                          children: [
                            for (final entry in [
                              (_ProjectFilter.all, 'All'),
                              (_ProjectFilter.created, 'Created'),
                              (_ProjectFilter.invited, 'Invited'),
                            ])
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpace.sm - 2,
                                ),
                                child: FilterChip(
                                  label: Text(entry.$2),
                                  selected: _filter == entry.$1,
                                  onSelected: (_) =>
                                      setState(() => _filter = entry.$1),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (isLoading)
                      const _ProjectSkeletonList()
                    else if (allProjects.isEmpty && error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppErrorState(
                          icon: AppIcons.cloudOff,
                          title: 'Projects didn\'t load',
                          message: error,
                          onRetry: appState.loadProjects,
                        ),
                      )
                    else if (projects.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyForFilter(context),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpace.gutter,
                          0,
                          AppSpace.gutter,
                          AppSpace.fabClearance,
                        ),
                        sliver: SliverList.separated(
                          itemCount: projects.length,
                          separatorBuilder: (context, index) =>
                              const _RowDivider(),
                          itemBuilder: (context, index) {
                            final project = projects[index];
                            return ProjectCard(
                              project: project,
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
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyForFilter(BuildContext context) {
    return switch (_filter) {
      _ProjectFilter.all => AppEmptyState(
        icon: AppIcons.folder,
        title: 'Start your first project',
        message:
            'Create a project, invite your testers, and '
            'their reports land here.',
        action: TextButton(
          onPressed: () => _openCreateProject(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('New project'),
        ),
      ),
      _ProjectFilter.created => AppEmptyState(
        icon: AppIcons.folder,
        title: 'No projects created',
        message: 'Projects you create show up here.',
        action: TextButton(
          onPressed: () => _openCreateProject(context),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('New project'),
        ),
      ),
      _ProjectFilter.invited => const AppEmptyState(
        icon: AppIcons.people,
        title: 'No invitations yet',
        message:
            'When someone invites you to test or collaborate, '
            'those projects land here.',
      ),
    };
  }

  String? _summary(AppState appState, List<Project> projects) {
    if (projects.isEmpty) return null;
    final unread = projects.where(appState.projectHasUnread).length;
    final count =
        '${projects.length} ${projects.length == 1 ? "project" : "projects"}';
    if (unread == 0) return '$count · all caught up';
    return '$count · $unread with new activity';
  }

  void _openCreateProject(BuildContext context) {
    final appState = AppScope.of(context);
    if (!appState.canCreateMoreProjects) {
      showUpgradeSheet(
        context,
        appState,
        title: 'Upgrade to create more projects',
      );
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateProjectScreen()));
  }
}

/// Hairline between project rows, inset so it starts where the text does.
class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: ProjectCard.separatorInset),
      child: Divider(color: AppTones.of(context).hairline),
    );
  }
}

/// Placeholder rows shown on a cold load so the list doesn't pop into place.
class _ProjectSkeletonList extends StatelessWidget {
  const _ProjectSkeletonList();

  @override
  Widget build(BuildContext context) {
    final tones = AppTones.of(context);

    Widget block(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: tones.sunken,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
    );

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      sliver: SliverList.separated(
        itemCount: 4,
        separatorBuilder: (context, index) => const _RowDivider(),
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md - 2),
          child: Row(
            children: [
              Container(
                width: ProjectCard.iconSize,
                height: ProjectCard.iconSize,
                decoration: BoxDecoration(
                  color: tones.sunken,
                  borderRadius: BorderRadius.circular(
                    ProjectCard.iconSize * 0.23,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    block(150 - index * 18, 14),
                    const SizedBox(height: AppSpace.sm),
                    block(190 - index * 22, 11),
                    const SizedBox(height: AppSpace.sm - 2),
                    block(90 - index * 8, 10),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Container(
                width: 74,
                height: 30,
                decoration: BoxDecoration(
                  color: tones.sunken,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ],
          ),
        ),
      ),
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
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      icon: AppIcons.bell,
      badge: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: scheme.error,
        label: Text('$unread'),
        child: Icon(AppIcons.bell, color: scheme.onSurface),
      ),
    );
  }
}

class _TesterInvitesButton extends StatelessWidget {
  const _TesterInvitesButton({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final pending = appState.pendingTesterInviteCount;
    final scheme = Theme.of(context).colorScheme;
    final open = appState.currentUser.openToTest;

    // Only surface the inbox when the user is open to testing or already has
    // invitations waiting.
    if (!open && pending == 0) return const SizedBox.shrink();

    return HeaderIconButton(
      tooltip: 'Testing invitations',
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TesterInvitesScreen()),
      ),
      icon: AppIcons.mailOpen,
      badge: Badge(
        isLabelVisible: pending > 0,
        backgroundColor: scheme.primary,
        label: Text('$pending'),
        child: Icon(AppIcons.mailOpen, color: scheme.onSurface),
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
      offset: const Offset(0, 46),
      onSelected: (value) {
        if (value == 'signout') {
          appState.signOut();
        } else if (value == 'profile') {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              _Avatar(appState: appState, size: 36),
              const SizedBox(width: AppSpace.md),
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
                    Text('View profile', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'signout',
          child: Row(
            children: [
              Icon(
                AppIcons.logout,
                size: 19,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpace.md),
              const Text('Sign out'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        child: _Avatar(appState: appState, size: 34),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.appState, required this.size});

  final AppState appState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = appState.currentUser;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: avatarColorForUser(user, scheme),
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsFor(user.name),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}
