import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/tester.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/project_logo.dart';
import '../widgets/status_pill.dart';
import 'project_detail_screen.dart';

/// Inbox of invitations for users who opted into testing.
class TesterInvitesScreen extends StatefulWidget {
  const TesterInvitesScreen({super.key});

  @override
  State<TesterInvitesScreen> createState() => _TesterInvitesScreenState();
}

class _TesterInvitesScreenState extends State<TesterInvitesScreen> {
  bool _loading = true;
  String? _error;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AppScope.of(context).loadTesterInvites();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _showInvite(TesterInvitation invite) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _InviteProjectSheet(
        invite: invite,
        busy: _busy.contains(invite.id),
        onAccept: invite.isPending
            ? () async {
                final ok = await _accept(invite, showOpenAction: false);
                if (!mounted) return;
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                if (ok) _openProject(invite.projectId);
              }
            : null,
        onDecline: invite.isPending
            ? () async {
                await _decline(invite);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              }
            : null,
        onOpenProject: invite.status == TesterInviteStatus.accepted
            ? () {
                Navigator.of(sheetContext).pop();
                _openProject(invite.projectId);
              }
            : null,
      ),
    );
  }

  void _openProject(String projectId) {
    final navigator = Navigator.of(context);
    // SnackBarAction / sheet pop tear down overlays in the same frame; wait
    // one frame so the push isn't discarded.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(projectId: projectId),
        ),
      );
    });
  }

  /// Returns true when the invite was accepted successfully.
  Future<bool> _accept(
    TesterInvitation invite, {
    bool showOpenAction = true,
  }) async {
    setState(() => _busy.add(invite.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).acceptTesterInvite(invite.id);
      if (!mounted) return false;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('You joined ${invite.projectName}'),
            behavior: SnackBarBehavior.floating,
            action: showOpenAction
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () => _openProject(invite.projectId),
                  )
                : null,
          ),
        );
      return true;
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(invite.id));
    }
  }

  Future<void> _decline(TesterInvitation invite) async {
    setState(() => _busy.add(invite.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).declineTesterInvite(invite.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(invite.id));
    }
  }

  Future<void> _enterInviteCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter invite code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'project-abcd',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final project = await AppScope.of(context).joinWithInviteCode(code);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Joined ${project.name}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _openProject(project.id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final invites = appState.testerInvites;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Invitations'),
            actions: [
              TextButton(
                onPressed: () => _enterInviteCode(),
                child: const Text('Enter code'),
              ),
            ],
          ),
          body: AppLayout.adaptiveBody(
            context,
            _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? AppErrorState(
                    icon: AppIcons.cloudOff,
                    title: 'Invitations didn\'t load',
                    message: _error!,
                    onRetry: _refresh,
                  )
                : invites.isEmpty
                ? AppEmptyState(
                    icon: AppIcons.mailOpen,
                    title: 'No invitations yet',
                    message:
                        'When someone invites you to a project, '
                        'those requests land here. You can also join '
                        'with a shared invite code.',
                    action: TextButton(
                      onPressed: _enterInviteCode,
                      child: const Text('Enter invite code'),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpace.gutter,
                        AppSpace.md,
                        AppSpace.gutter,
                        AppSpace.xxxl,
                      ),
                      itemCount: invites.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpace.sm + 2),
                      itemBuilder: (context, index) {
                        final invite = invites[index];
                        return _InviteRow(
                          invite: invite,
                          busy: _busy.contains(invite.id),
                          onTap: () => _showInvite(invite),
                        );
                      },
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _InviteRow extends StatelessWidget {
  const _InviteRow({
    required this.invite,
    required this.busy,
    required this.onTap,
  });

  final TesterInvitation invite;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              ProjectLogo(
                projectName: invite.projectName,
                logoUrl: invite.projectLogoUrl,
                size: 48,
                borderRadius: AppRadius.sm + 2,
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From ${invite.fromUserName} · ${invite.roleLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              if (busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                StatusPill(
                  label: testerInviteStatusLabel(invite.status),
                  color: switch (invite.status) {
                    TesterInviteStatus.pending => scheme.primary,
                    TesterInviteStatus.accepted => scheme.tertiary,
                    TesterInviteStatus.declined => scheme.onSurfaceVariant,
                    TesterInviteStatus.cancelled => scheme.onSurfaceVariant,
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteProjectSheet extends StatelessWidget {
  const _InviteProjectSheet({
    required this.invite,
    required this.busy,
    this.onAccept,
    this.onDecline,
    this.onOpenProject,
  });

  final TesterInvitation invite;
  final bool busy;
  final Future<void> Function()? onAccept;
  final Future<void> Function()? onDecline;
  final VoidCallback? onOpenProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final testersLabel =
        '${invite.testerCount} '
        '${invite.testerCount == 1 ? "tester" : "testers"} already on the team';

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(
                title: 'Project invitation',
                subtitle: 'Review the project before you accept.',
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProjectLogo(
                    projectName: invite.projectName,
                    logoUrl: invite.projectLogoUrl,
                    size: 64,
                    borderRadius: AppRadius.md,
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.projectName,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpace.xs),
                        Text(
                          'Invited by ${invite.fromUserName} as ${invite.roleLabel}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        StatusPill(
                          label: testerInviteStatusLabel(invite.status),
                          color: switch (invite.status) {
                            TesterInviteStatus.pending => scheme.primary,
                            TesterInviteStatus.accepted => scheme.tertiary,
                            TesterInviteStatus.declined =>
                              scheme.onSurfaceVariant,
                            TesterInviteStatus.cancelled =>
                              scheme.onSurfaceVariant,
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              Text(
                testersLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Received ${formatRelativeTime(invite.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (invite.projectDescription.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                Text('About', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpace.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: tones.sunken,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    invite.projectDescription,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
              if (invite.message.isNotEmpty) ...[
                const SizedBox(height: AppSpace.xl),
                Text('Message', style: theme.textTheme.labelSmall),
                const SizedBox(height: AppSpace.sm),
                Text(
                  '"${invite.message}"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.xl),
              if (busy)
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (onAccept != null && onDecline != null)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onDecline!(),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onAccept!(),
                        child: const Text('Accept'),
                      ),
                    ),
                  ],
                )
              else if (onOpenProject != null)
                FilledButton(
                  onPressed: onOpenProject,
                  child: const Text('Open project'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
