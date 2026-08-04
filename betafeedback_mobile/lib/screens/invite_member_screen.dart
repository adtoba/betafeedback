import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/user.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_header.dart';
import '../widgets/grouped_list.dart';

/// Full-screen form for inviting a tester or developer to a project.
class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  UserRole _role = UserRole.tester;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await AppScope.of(context).addMember(
        projectId: widget.projectId,
        name: _nameController.text.trim(),
        email: email,
        role: _role,
      );
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Invite sent to $email — they can accept in the app'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = AppScope.of(context).projectById(widget.projectId);

    return Scaffold(
      appBar: AppBar(title: const Text('Invite')),
      body: AppLayout.adaptiveBody(
        context,
        Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.gutter + AppSpace.xs,
              AppSpace.lg,
              AppSpace.gutter + AppSpace.xs,
              AppSpace.xxl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                'Testers can file reports. Developers can triage them, fix '
                'bugs, and reply.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (project != null) ...[
                const SizedBox(height: AppSpace.xl),
                _InviteLinkCard(link: project.inviteLink),
                const SizedBox(height: AppSpace.xl),
                const LabeledRule('or invite by email'),
              ],
              const SizedBox(height: AppSpace.xl),
              const _FieldLabel('Their role'),
              SegmentedButton<UserRole>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: UserRole.tester,
                    label: Text('Tester'),
                    icon: Icon(AppIcons.bug, size: 16),
                  ),
                  ButtonSegment(
                    value: UserRole.developer,
                    label: Text('Developer'),
                    icon: Icon(AppIcons.code, size: 16),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: AppSpace.xl),
              const _FieldLabel('Name'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: 'Jordan Ade'),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: AppSpace.lg),
              const _FieldLabel('Email'),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'jordan@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppTones.of(context).hairline,
              width: AppStroke.hairline,
            ),
          ),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.md,
          ),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Send invite'),
          ),
        ),
      ),
    );
  }
}

/// The shareable join link. Presented first because it's the path most teams
/// actually take — the email form below is the deliberate, named invite.
class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tones.hairline, width: AppStroke.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: AppIcons.link, tint: scheme.primary, size: 28),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  'Share a join link',
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.md - 2,
            ),
            decoration: BoxDecoration(
              color: tones.sunken,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                TextButton(
                  onPressed: () =>
                      copyToClipboard(context, link, 'Invite link copied'),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.sm,
                      vertical: AppSpace.xs,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Copy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm + 2),
          Text(
            'Anyone with the link can join as a tester after signing in.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
