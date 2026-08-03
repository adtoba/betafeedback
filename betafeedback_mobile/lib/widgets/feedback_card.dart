import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import '../models/project_platform.dart';
import '../models/user.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'status_pill.dart';

/// Renders a single feedback entry. Tester reports show full test details
/// (title, device, build, description, screenshots); system messages render as
/// compact banners.
class FeedbackCard extends StatelessWidget {
  const FeedbackCard({
    super.key,
    required this.message,
    required this.author,
    this.structuredBug,
    this.canReply = false,
    this.projectId,
  });

  final FeedbackMessage message;
  final User? author;
  final StructuredBug? structuredBug;
  final bool canReply;
  final String? projectId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (message.type) {
      case FeedbackType.systemFixed:
        return _SystemBanner(
          icon: AppIcons.checkCircle,
          tint: scheme.tertiary,
          message: message.content,
          time: message.createdAt,
        );
      case FeedbackType.aiStructured:
        return _SystemBanner(
          icon: AppIcons.sparkles,
          tint: scheme.secondary,
          message: message.content,
          time: message.createdAt,
        );
      case FeedbackType.testerMessage:
        return _ReportCard(
          message: message,
          author: author,
          linkedBug: structuredBug,
          canReply: canReply,
          projectId: projectId,
        );
    }
  }
}

class _ReportCard extends StatefulWidget {
  const _ReportCard({
    required this.message,
    required this.author,
    this.linkedBug,
    this.canReply = false,
    this.projectId,
  });

  final FeedbackMessage message;
  final User? author;
  final StructuredBug? linkedBug;
  final bool canReply;
  final String? projectId;

  @override
  State<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<_ReportCard> {
  final _replyController = TextEditingController();
  bool _showReply = false;
  bool _submitting = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final body = _replyController.text.trim();
    if (body.isEmpty || widget.projectId == null) return;
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AppScope.of(context).addFeedbackComment(
        projectId: widget.projectId!,
        feedbackId: widget.message.id,
        body: body,
      );
      if (!mounted) return;
      _replyController.clear();
      setState(() {
        _submitting = false;
        _showReply = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final author = widget.author;
    final linkedBug = widget.linkedBug;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);
    final name = author?.name.isNotEmpty == true ? author!.name : 'Unknown';
    final hasMeta =
        message.platform != null ||
        message.device != null ||
        message.appVersion != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.lg - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Initials(
                  name: name,
                  color: avatarColorForUser(author, scheme),
                  size: 32,
                ),
                const SizedBox(width: AppSpace.md - 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleSmall),
                      Text(
                        '${author?.roleLabel ?? 'Member'} · '
                        '${formatRelativeTime(message.createdAt)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (linkedBug != null) ...[
                  const SizedBox(width: AppSpace.sm),
                  _BugStatusPill(bug: linkedBug),
                ],
              ],
            ),
            const SizedBox(height: AppSpace.md + 2),

            if (message.title != null) ...[
              Text(message.title!, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpace.sm - 2),
            ],

            Text(message.content, style: theme.textTheme.bodyMedium),

            if (hasMeta) ...[
              const SizedBox(height: AppSpace.md + 2),
              Wrap(
                spacing: AppSpace.sm - 2,
                runSpacing: AppSpace.sm - 2,
                children: [
                  if (message.platform != null)
                    _MetaChip(
                      icon:
                          platformById(message.platform!)?.icon ??
                          AppIcons.devices,
                      label:
                          platformById(message.platform!)?.label ??
                          message.platform!,
                    ),
                  if (message.device != null)
                    _MetaChip(
                      icon: AppIcons.smartphone,
                      label: message.device!,
                    ),
                  if (message.appVersion != null)
                    _MetaChip(icon: AppIcons.tag, label: message.appVersion!),
                ],
              ),
            ],

            if (message.screenshots.isNotEmpty) ...[
              const SizedBox(height: AppSpace.md + 2),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.screenshots.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSpace.sm),
                  itemBuilder: (context, i) =>
                      _ScreenshotThumb(screenshot: message.screenshots[i]),
                ),
              ),
            ],

            if (message.comments.isNotEmpty) ...[
              const SizedBox(height: AppSpace.lg),
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: tones.canvas,
                  borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < message.comments.length; i++) ...[
                      if (i > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.md,
                          ),
                          child: Divider(color: tones.hairline),
                        ),
                      _Comment(comment: message.comments[i]),
                    ],
                  ],
                ),
              ),
            ],

            if (widget.canReply) ...[
              if (_showReply) ...[
                const SizedBox(height: AppSpace.md),
                TextField(
                  controller: _replyController,
                  maxLines: 3,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Reply to the tester…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _showReply = false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    FilledButton(
                      onPressed: _submitting ? null : _submitReply,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.lg,
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Send'),
                    ),
                  ],
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpace.sm),
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showReply = true),
                      icon: const Icon(AppIcons.send, size: 15),
                      label: const Text('Reply'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({required this.comment});

  final FeedbackComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Initials(
          name: comment.authorName,
          color: theme.colorScheme.primary,
          size: 26,
        ),
        const SizedBox(width: AppSpace.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      comment.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    formatRelativeTime(comment.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xxs),
              Text(comment.body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.name,
    required this.color,
    required this.size,
  });

  final String name;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        initialsFor(name),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm + 2,
        vertical: AppSpace.xs + 1,
      ),
      decoration: BoxDecoration(
        color: tones.canvas,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: tones.hairline, width: AppStroke.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpace.xs + 2),
          // Long device strings truncate rather than push past the card.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status of the structured bug linked to a report — updated in place when the
/// bug is fixed, so the feed never fills up with "marked as fixed" messages.
class _BugStatusPill extends StatelessWidget {
  const _BugStatusPill({required this.bug});

  final StructuredBug bug;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = AppTones.of(context);

    final (Color color, IconData icon, String label) = switch (bug.status) {
      BugStatus.fixed => (scheme.tertiary, AppIcons.checkCircle, 'Fixed'),
      BugStatus.suggested => (scheme.secondary, AppIcons.sparkles, 'Suggested'),
      BugStatus.needsInfo => (scheme.primary, AppIcons.flag, 'Needs info'),
      BugStatus.open => (tones.warning, AppIcons.bug, 'Open bug'),
    };

    return StatusPill(label: label, color: color, icon: icon);
  }
}

class _ScreenshotThumb extends StatelessWidget {
  const _ScreenshotThumb({required this.screenshot});

  final Screenshot screenshot;

  Color get _color =>
      HSLColor.fromAHSL(1, screenshot.hue.toDouble(), 0.45, 0.5).toColor();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!screenshot.hasMedia) return _placeholderTile();

    final url = AppScope.of(context).mediaUrl(screenshot.url!);
    return GestureDetector(
      onTap: () =>
          screenshot.isVideo ? _openExternal(url) : _openImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        child: SizedBox(
          width: 76,
          height: 100,
          child: screenshot.isVideo
              ? ColoredBox(
                  color: const Color(0xFF16171A),
                  child: const Center(
                    child: Icon(AppIcons.play, color: Colors.white, size: 26),
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(
                      AppIcons.imageBroken,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _placeholderTile() {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm + 2),
        gradient: LinearGradient(
          colors: [_color.withValues(alpha: 0.8), _color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(AppIcons.image, color: Colors.white, size: 22),
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(AppSpace.md),
        child: Stack(
          children: [
            InteractiveViewer(child: Center(child: Image.network(url))),
            Positioned(
              top: AppSpace.sm,
              right: AppSpace.sm,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(AppIcons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Automated entry in the feed: a fix shipping, or AI structuring a report.
class _SystemBanner extends StatelessWidget {
  const _SystemBanner({
    required this.icon,
    required this.tint,
    required this.message,
    required this.time,
  });

  final IconData icon;
  final Color tint;
  final String message;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: tint.withValues(alpha: 0.22),
          width: AppStroke.thin,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: tint),
          const SizedBox(width: AppSpace.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpace.xxs),
                Text(
                  formatRelativeTime(time),
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
