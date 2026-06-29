import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import '../models/project_platform.dart';
import '../models/user.dart';

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
          color: scheme.primaryContainer,
          textColor: scheme.onPrimaryContainer,
          message: message.content,
          time: message.createdAt,
        );
      case FeedbackType.aiStructured:
        return _SystemBanner(
          icon: AppIcons.sparkles,
          color: scheme.tertiaryContainer,
          textColor: scheme.onTertiaryContainer,
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
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final author = widget.author;
    final linkedBug = widget.linkedBug;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = author?.name ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: avatarColorForUser(author, scheme),
                  child: Text(
                    initialsFor(name),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        author?.roleLabel ?? 'Member',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRelativeTime(message.createdAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Linked bug status (e.g. "Bug logged" / "Fixed")
            if (linkedBug != null) ...[
              _BugStatusBadge(bug: linkedBug),
              const SizedBox(height: 12),
            ],

            // Title
            if (message.title != null) ...[
              Text(
                message.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Platform / device / build chips
            if (message.platform != null ||
                message.device != null ||
                message.appVersion != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (message.platform != null)
                    _MetaChip(
                      icon: platformById(message.platform!)?.icon ??
                          AppIcons.devices,
                      label: platformById(message.platform!)?.label ??
                          message.platform!,
                    ),
                  if (message.device != null)
                    _MetaChip(
                      icon: AppIcons.smartphone,
                      label: message.device!,
                    ),
                  if (message.appVersion != null)
                    _MetaChip(
                      icon: AppIcons.tag,
                      label: message.appVersion!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Description
            Text(
              message.content,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),

            // Screenshots
            if (message.screenshots.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.screenshots.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => _ScreenshotThumb(
                    screenshot: message.screenshots[i],
                  ),
                ),
              ),
            ],

            if (message.comments.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              for (final comment in message.comments) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        initialsFor(comment.authorName),
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                comment.authorName,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                formatRelativeTime(comment.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment.body,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],

            if (widget.canReply) ...[
              const SizedBox(height: 4),
              if (_showReply)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _replyController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Reply to the tester…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _submitReply,
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(AppIcons.send, size: 16),
                        label: const Text('Send reply'),
                      ),
                    ),
                  ],
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showReply = true),
                    icon: const Icon(AppIcons.send, size: 16),
                    label: const Text('Reply'),
                  ),
                ),
            ],
          ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact badge shown on a tester report once it has been turned into a
/// structured bug — and updated in place when that bug is marked fixed, so the
/// feed never fills up with "marked as fixed" system messages.
class _BugStatusBadge extends StatelessWidget {
  const _BugStatusBadge({required this.bug});

  final StructuredBug bug;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (Color bg, Color fg, IconData icon, String label) =
        switch (bug.status) {
      BugStatus.fixed => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          AppIcons.checkCircle,
          'Fixed',
        ),
      BugStatus.suggested => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          AppIcons.sparkles,
          'Bug suggested',
        ),
      BugStatus.needsInfo => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          AppIcons.flag,
          'Needs info',
        ),
      BugStatus.open => (
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
          AppIcons.sparkles,
          'Bug logged',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenshotThumb extends StatelessWidget {
  const _ScreenshotThumb({required this.screenshot});

  final Screenshot screenshot;

  Color get _color =>
      HSLColor.fromAHSL(1, screenshot.hue.toDouble(), 0.5, 0.55).toColor();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (!screenshot.hasMedia) {
      return _placeholderTile();
    }

    final url = AppScope.of(context).mediaUrl(screenshot.url!);
    return GestureDetector(
      onTap: () => screenshot.isVideo
          ? _openExternal(url)
          : _openImage(context, url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          height: 96,
          child: screenshot.isVideo
              ? Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Icon(AppIcons.play,
                        color: Colors.white, size: 28),
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(AppIcons.imageBroken,
                        color: scheme.onSurfaceVariant),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _placeholderTile() {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [_color.withValues(alpha: 0.85), _color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(AppIcons.image, color: Colors.white, size: 24),
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
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url)),
            ),
            Positioned(
              top: 8,
              right: 8,
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

class _SystemBanner extends StatelessWidget {
  const _SystemBanner({
    required this.icon,
    required this.color,
    required this.textColor,
    required this.message,
    required this.time,
  });

  final IconData icon;
  final Color color;
  final Color textColor;
  final String message;
  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRelativeTime(time),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
