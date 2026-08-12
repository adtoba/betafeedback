import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../models/feedback.dart';
import '../models/project.dart';
import '../models/project_platform.dart';
import '../models/user.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/feedback_card.dart';
import '../widgets/grouped_list.dart';
import '../widgets/metric_strip.dart';
import '../widgets/project_logo.dart';
import '../widgets/status_pill.dart';
import '../widgets/team_member_tile.dart';
import 'activity_log_screen.dart';
import 'bug_summary_screen.dart';
import 'feedback_list_screen.dart';
import 'invite_member_screen.dart';
import 'find_testers_screen.dart';
import 'new_feedback_screen.dart';
import 'post_release_sheet.dart';
import 'test_plan_screen.dart';
import '../widgets/rate_tester_sheet.dart';
import '../widgets/android_beta_install_sheet.dart';
import '../widgets/edit_distribution_sheet.dart';
import '../utils/android_beta_install.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = AppScope.of(context);
      await appState.loadProject(widget.projectId);
      await appState.markProjectViewed(widget.projectId);
      if (mounted) {
        setState(() => _loaded = true);
        final project = appState.projectById(widget.projectId);
        if (project != null &&
            project.testerIds.contains(appState.currentUser.id)) {
          await showAndroidBetaInstallSheet(
            context,
            project: project,
            userEmail: appState.currentUser.email,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final project = appState.projectById(widget.projectId);

        if (!_loaded && appState.isProjectLoading(widget.projectId)) {
          return Scaffold(
            appBar: AppBar(
              centerTitle: false,
              title: ProjectAppBarTitle(
                projectName: project?.name ?? 'Project',
                logoUrl: project?.logoUrl,
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (project == null) {
          return Scaffold(
            appBar: AppBar(centerTitle: false),
            body: Center(
              child: Text(
                appState.projectError(widget.projectId) ?? 'Project not found',
              ),
            ),
          );
        }

        final currentUser = appState.currentUser;
        final isCreator = currentUser.id == project.creatorId;
        final isTester = project.testerIds.contains(currentUser.id);
        final isDeveloper = project.developerIds.contains(currentUser.id);
        final canSendFeedback = isTester || isCreator || isDeveloper;
        final canStructureOrFix = isDeveloper || isCreator;
        final canReplyToFeedback = isDeveloper || isCreator;

        final messages =
            project.feedback
                .where((m) => m.type == FeedbackType.testerMessage)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final previewMessages = messages
            .take(FeedbackListScreen.previewLimit)
            .toList();
        final hasMoreFeedback =
            messages.length > FeedbackListScreen.previewLimit;

        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            title: ProjectAppBarTitle(
              projectName: project.name,
              logoUrl: project.logoUrl,
            ),
            actions: [
              IconButton(
                tooltip: 'Team',
                onPressed: () => _showTeamSheet(context, appState, project),
                icon: const Icon(AppIcons.people),
              ),
              if (isCreator || canStructureOrFix)
                PopupMenuButton<String>(
                  tooltip: 'More',
                  icon: const Icon(AppIcons.more),
                  offset: const Offset(0, 46),
                  onSelected: (value) {
                    switch (value) {
                      case 'invite':
                        _showInvite(context, project.id);
                      case 'find_testers':
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FindTestersScreen(
                              projectId: project.id,
                              projectName: project.name,
                            ),
                          ),
                        );
                      case 'release':
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) =>
                              PostReleaseSheet(projectId: project.id),
                        );
                      case 'export_bugs':
                        _exportData(context, appState, project.id, 'bugs');
                      case 'export_feedback':
                        _exportData(
                          context,
                          appState,
                          project.id,
                          'feedback',
                        );
                      case 'android_testing':
                        showEditDistributionSheet(context, project: project);
                    }
                  },
                  itemBuilder: (context) => [
                    if (isCreator) ...[
                      const PopupMenuItem(
                        value: 'invite',
                        child: _MenuRow(
                          icon: AppIcons.personAdd,
                          label: 'Invite member',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'find_testers',
                        child: _MenuRow(
                          icon: AppIcons.search,
                          label: 'Find testers',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'android_testing',
                        child: _MenuRow(
                          icon: AppIcons.platformAndroid,
                          label: 'Android closed testing',
                        ),
                      ),
                    ],
                    if (canStructureOrFix) ...[
                      if (isCreator) const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'release',
                        child: _MenuRow(
                          icon: AppIcons.rocket,
                          label: 'Post release',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export_bugs',
                        child: const _MenuRow(
                          icon: AppIcons.download,
                          label: 'Export bugs (CSV)',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export_feedback',
                        child: const _MenuRow(
                          icon: AppIcons.download,
                          label: 'Export feedback (CSV)',
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          body: AppLayout.adaptiveBody(
            context,
            CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  sliver: SliverToBoxAdapter(
                    child: _ProjectHeader(
                      project: project,
                      appState: appState,
                      isCreator: isCreator,
                      isTester: isTester,
                      onViewBugs: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              BugSummaryScreen(projectId: project.id),
                        ),
                      ),
                      onViewActivity: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ActivityLogScreen(projectId: project.id),
                        ),
                      ),
                      onViewTestPlan: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TestPlanScreen(projectId: project.id),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.xxl),
                    child: SectionHeader(
                      title: 'Feedback',
                      action: hasMoreFeedback
                          ? TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FeedbackListScreen(projectId: project.id),
                                ),
                              ),
                              child: Text('See all ${messages.length}'),
                            )
                          : null,
                    ),
                  ),
                ),
                if (messages.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: AppIcons.feedback,
                      title: 'No reports yet',
                      message: canSendFeedback
                          ? 'File the first report and it will show up here for '
                                'the whole team.'
                          : 'Nothing from your testers so far. Reports appear '
                                'here as they come in.',
                    ),
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
                      itemCount: previewMessages.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpace.sm + 2),
                      itemBuilder: (context, index) {
                        final message = previewMessages[index];
                        final author = appState.userById(message.authorId);
                        final linkedBug = appState.structuredBugForFeedback(
                          project.id,
                          message.id,
                        );
                        return FeedbackCard(
                          message: message,
                          author: author,
                          structuredBug: linkedBug,
                          canReply: canReplyToFeedback,
                          projectId: project.id,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: canSendFeedback
              ? FloatingActionButton(
                  tooltip: 'New feedback',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => NewFeedbackScreen(projectId: project.id),
                    ),
                  ),
                  child: const Icon(AppIcons.feedbackAdd),
                )
              : null,
        );
      },
    );
  }

  void _showInvite(BuildContext context, String projectId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InviteMemberScreen(projectId: projectId),
      ),
    );
  }

  Future<void> _exportData(
    BuildContext context,
    AppState appState,
    String projectId,
    String type,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await appState.exportProject(
        projectId: projectId,
        type: type,
      );
      await Share.share(csv, subject: 'BetaFeedback $type export');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _copyTesterEmails(
    BuildContext context,
    AppState appState,
    Project project,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final emails = await appState.listTesterEmails(project.id);
      if (emails.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No tester emails yet'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      await Clipboard.setData(ClipboardData(text: emails.join('\n')));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Copied ${emails.length} email${emails.length == 1 ? '' : 's'}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showTeamSheet(
    BuildContext context,
    AppState appState,
    Project project,
  ) {
    final isCreator = project.creatorId == appState.currentUser.id;
    final creator = appState.userById(project.creatorId);
    final testers = project.testerIds
        .map(appState.userById)
        .whereType<User>()
        .toList();
    final developers = project.developerIds
        .map(appState.userById)
        .whereType<User>()
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(0, AppSpace.xs, 0, AppSpace.xxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter + AppSpace.xs,
                  0,
                  AppSpace.gutter,
                  AppSpace.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Team',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (isCreator)
                      IconButton(
                        tooltip: 'Invite member',
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _showInvite(context, project.id);
                        },
                        icon: const Icon(AppIcons.personAdd),
                      ),
                  ],
                ),
              ),
              if (creator != null) ...[
                GroupedSection(
                  header: 'Creator',
                  children: [TeamMemberTile(user: creator)],
                ),
                const SizedBox(height: AppSpace.xxl),
              ],
              GroupedSection(
                header: 'Testers · ${testers.length}',
                children: [
                  if (testers.isEmpty)
                    GroupedNote(
                      isCreator
                          ? 'No testers yet. Find people open to testing.'
                          : 'No testers have joined yet.',
                    )
                  else
                    for (final u in testers)
                      TeamMemberTile(
                        user: u,
                        trailing: isCreator
                            ? TextButton(
                                onPressed: () {
                                  Navigator.of(sheetContext).pop();
                                  showRateTesterSheet(
                                    context,
                                    projectId: project.id,
                                    tester: u,
                                  );
                                },
                                child: const Text('Rate'),
                              )
                            : null,
                      ),
                  if (isCreator)
                    GroupedListTile(
                      icon: AppIcons.search,
                      title: 'Find testers',
                      subtitle: 'Invite from the marketplace',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FindTestersScreen(
                              projectId: project.id,
                              projectName: project.name,
                            ),
                          ),
                        );
                      },
                    ),
                  if (isCreator && testers.isNotEmpty)
                    GroupedListTile(
                      icon: AppIcons.mail,
                      title: 'Copy tester emails',
                      subtitle: 'For Play Console or Google Group',
                      onTap: () => _copyTesterEmails(context, appState, project),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.xxl),
              GroupedSection(
                header: 'Developers · ${developers.length}',
                children: developers.isEmpty
                    ? const [GroupedNote('No developers have joined yet.')]
                    : [for (final u in developers) TeamMemberTile(user: u)],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  const _ProjectHeader({
    required this.project,
    required this.appState,
    required this.isCreator,
    required this.isTester,
    required this.onViewBugs,
    required this.onViewActivity,
    required this.onViewTestPlan,
  });

  final Project project;
  final AppState appState;
  final bool isCreator;
  final bool isTester;
  final VoidCallback onViewBugs;
  final VoidCallback onViewActivity;
  final VoidCallback onViewTestPlan;

  List<({IconData icon, String label, String url})> get _links {
    if (project.platformLinks.isNotEmpty) {
      return [
        for (final link in project.platformLinks)
          (
            icon: platformById(link.platform)?.icon ?? AppIcons.link,
            label: platformById(link.platform)?.label ?? link.platform,
            url: link.url,
          ),
      ];
    }
    if (project.appLink != null) {
      return [(icon: AppIcons.link, label: 'App link', url: project.appLink!)];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final openBugs = project.structuredBugs
        .where((b) => b.status == BugStatus.open)
        .length;
    final suggestedBugs = project.structuredBugs
        .where((b) => b.status == BugStatus.suggested)
        .length;
    final activityCount = appState.activityForProject(project.id).length;
    final links = _links;
    final theme = Theme.of(context);
    final tones = AppTones.of(context);
    final reportCount = project.feedback
        .where((m) => m.type == FeedbackType.testerMessage)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (project.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter + AppSpace.xs,
              0,
              AppSpace.gutter + AppSpace.xs,
              AppSpace.lg,
            ),
            child: Text(
              project.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
          child: MetricStrip(
            metrics: [
              Metric(label: 'Testers', value: '${project.testerCount}'),
              Metric(label: 'Reports', value: '$reportCount'),
              Metric(
                label: 'Open bugs',
                value: '$openBugs',
                tint: openBugs > 0 ? tones.warning : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xxl),
        if (links.isNotEmpty) ...[
          GroupedSection(
            header: 'Test builds',
            children: [
              for (final link in links)
                _CompactLinkRow(
                  icon: link.icon,
                  label: link.label,
                  url: link.url,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xxl),
        ],
        if (isCreator || (isTester && projectHasAndroidBetaInstall(project))) ...[
          GroupedSection(
            header: 'Android beta',
            children: [
              if (isCreator)
                GroupedListTile(
                  icon: AppIcons.platformAndroid,
                  title: 'Closed testing setup',
                  subtitle: 'Play link and Google Group',
                  onTap: () => showEditDistributionSheet(
                    context,
                    project: project,
                  ),
                ),
              if (isTester && projectHasAndroidBetaInstall(project))
                GroupedListTile(
                  icon: AppIcons.download,
                  title: 'Install Android beta',
                  subtitle: 'Group + Play checklist',
                  onTap: () => showAndroidBetaInstallSheet(
                    context,
                    project: project,
                    userEmail: appState.currentUser.email,
                    force: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.xxl),
        ],
        GroupedSection(
          header: 'Project',
          children: [
            GroupedListTile(
              icon: AppIcons.listChecks,
              title: 'What to test',
              subtitle: project.testPlan.isEmpty
                  ? 'No instructions yet'
                  : '${project.testPlan.length} '
                        '${project.testPlan.length == 1 ? "item" : "items"} to check',
              onTap: onViewTestPlan,
            ),
            GroupedListTile(
              icon: AppIcons.sparkles,
              iconColor: tones.warning,
              title: 'Bug summary',
              subtitle: suggestedBugs > 0
                  ? '$suggestedBugs to review · $openBugs open'
                  : '${project.structuredBugs.length} structured · $openBugs open',
              trailing: suggestedBugs > 0
                  ? CountBadge(count: suggestedBugs)
                  : null,
              onTap: onViewBugs,
            ),
            GroupedListTile(
              icon: AppIcons.history,
              iconColor: theme.colorScheme.secondary,
              title: 'Activity log',
              subtitle: activityCount == 0
                  ? 'No activity yet'
                  : '$activityCount events · fixes & updates',
              onTap: onViewActivity,
            ),
          ],
        ),
      ],
    );
  }
}

class _CompactLinkRow extends StatelessWidget {
  const _CompactLinkRow({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  Future<void> _openLink(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Invalid link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!await canLaunchUrl(uri)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open $label link'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actionColor = scheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.md + 2,
        AppSpace.sm - 1,
        AppSpace.sm,
        AppSpace.sm - 1,
      ),
      child: Row(
        children: [
          IconTile(icon: icon, tint: scheme.primary),
          const SizedBox(width: AppSpace.md),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          IconButton(
            tooltip: 'Copy $label link',
            onPressed: () =>
                copyToClipboard(context, url, '$label link copied'),
            icon: Icon(AppIcons.copy, size: 18, color: actionColor),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            tooltip: 'Open $label link',
            onPressed: () => _openLink(context),
            icon: Icon(AppIcons.externalLink, size: 18, color: actionColor),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpace.md),
        Text(label),
      ],
    );
  }
}
