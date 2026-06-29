import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_icons.dart';
import '../theme/app_layout.dart';

import '../app/app_scope.dart';
import '../data/app_state.dart';
import '../models/feedback.dart';
import '../models/project.dart';
import '../models/project_platform.dart';
import '../models/user.dart';
import '../widgets/feedback_card.dart';
import '../widgets/grouped_list.dart';
import '../widgets/plan_picker_sheet.dart';
import '../widgets/project_logo.dart';
import '../widgets/team_member_tile.dart';
import 'activity_log_screen.dart';
import 'bug_summary_screen.dart';
import 'feedback_list_screen.dart';
import 'invite_member_screen.dart';
import 'new_feedback_screen.dart';
import 'post_release_sheet.dart';
import 'test_plan_screen.dart';

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
      if (mounted) setState(() => _loaded = true);
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
            appBar: AppBar(
              centerTitle: false,
            ),
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

        final messages = project.feedback
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
              if (canStructureOrFix && appState.isPro)
                PopupMenuButton<String>(
                  tooltip: 'Export',
                  icon: const Icon(AppIcons.download),
                  onSelected: (type) =>
                      _exportData(context, appState, project.id, type),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'bugs',
                      child: Text('Export bugs (CSV)'),
                    ),
                    PopupMenuItem(
                      value: 'feedback',
                      child: Text('Export feedback (CSV)'),
                    ),
                  ],
                )
              else if (canStructureOrFix)
                IconButton(
                  tooltip: 'Export (Pro)',
                  onPressed: () => showPlanPickerSheet(
                    context,
                    title: 'Export with Pro',
                    currentPlan: appState.currentSubscription.plan,
                    onSelect: (plan) => appState.changePlan(plan),
                  ),
                  icon: const Icon(AppIcons.download),
                ),
              if (canStructureOrFix)
                IconButton(
                  tooltip: 'Post release update',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => PostReleaseSheet(projectId: project.id),
                  ),
                  icon: const Icon(AppIcons.rocket),
                ),
              IconButton(
                tooltip: 'Team',
                onPressed: () => _showTeamSheet(context, appState, project),
                icon: const Icon(AppIcons.people),
              ),
              if (isCreator)
                IconButton(
                  tooltip: 'Invite member',
                  onPressed: () => _showInvite(context, project.id),
                  icon: const Icon(AppIcons.personAdd),
                ),
            ],
          ),
          body: AppLayout.adaptiveBody(
            context,
            CustomScrollView(
              slivers: [
              SliverToBoxAdapter(
                child: _ProjectHeader(
                  project: project,
                  appState: appState,
                  onViewBugs: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BugSummaryScreen(projectId: project.id),
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
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Text(
                        'Feedback',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (hasMoreFeedback) ...[
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FeedbackListScreen(
                                projectId: project.id,
                              ),
                            ),
                          ),
                          child: Text('See all (${messages.length})'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (messages.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: _EmptyFeedback(canSendFeedback: canSendFeedback),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: previewMessages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
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
                      builder: (_) =>
                          NewFeedbackScreen(projectId: project.id),
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
      final csv = await appState.exportProject(projectId: projectId, type: type);
      await Share.share(csv, subject: 'BetaFeedback $type export');
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
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Text(
                'Team',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),
              if (creator != null) ...[
                _SectionLabel('Creator'),
                TeamMemberTile(user: creator),
                const SizedBox(height: 16),
              ],
              _SectionLabel('Testers (${testers.length})'),
              if (testers.isEmpty)
                const _EmptyNote('No testers yet.')
              else
                ...testers.map((u) => TeamMemberTile(user: u)),
              const SizedBox(height: 16),
              _SectionLabel('Developers (${developers.length})'),
              if (developers.isEmpty)
                const _EmptyNote('No developers yet.')
              else
                ...developers.map((u) => TeamMemberTile(user: u)),
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
    required this.onViewBugs,
    required this.onViewActivity,
    required this.onViewTestPlan,
  });

  final Project project;
  final AppState appState;
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
      return [
        (icon: AppIcons.link, label: 'App link', url: project.appLink!),
      ];
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (links.isNotEmpty) ...[
          GroupedSection(
            header: 'Links',
            children: [
              for (final link in links)
                _CompactLinkRow(
                  icon: link.icon,
                  label: link.label,
                  url: link.url,
                ),
            ],
          ),
          const SizedBox(height: 20),
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
              title: 'Bug summary',
              subtitle: suggestedBugs > 0
                  ? '$suggestedBugs to review · $openBugs open'
                  : '${project.structuredBugs.length} structured · $openBugs open',
              trailing: suggestedBugs > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$suggestedBugs',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : null,
              onTap: onViewBugs,
            ),
            GroupedListTile(
              icon: AppIcons.history,
              title: 'Activity log',
              subtitle: activityCount == 0
                  ? 'No activity yet'
                  : '$activityCount events · fixes & updates',
              onTap: onViewActivity,
            ),
          ],
        ),
        const SizedBox(height: 8),
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
    final actionColor = scheme.onSurfaceVariant.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _EmptyFeedback extends StatelessWidget {
  const _EmptyFeedback({required this.canSendFeedback});

  final bool canSendFeedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GroupedSection(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            children: [
              Icon(
                AppIcons.feedback,
                size: 40,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                'No feedback yet',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                canSendFeedback
                    ? 'Tap + to file the first test report.'
                    : 'Testers haven\'t filed any reports yet.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
