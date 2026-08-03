import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import '../models/project.dart';
import '../models/project_platform.dart';
import '../services/device_info.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// An attachment the tester picked, tracked through its upload lifecycle.
class _Attachment {
  _Attachment({required this.name, required this.isVideo, this.preview});

  final String name;
  final bool isVideo;
  final Uint8List? preview; // image bytes for the thumbnail (null for video)
  Screenshot? uploaded; // set once the upload succeeds
  bool uploading = true;
  bool failed = false;
}

/// A structured form for submitting a test report: title, device, build,
/// description, and screenshot attachments.
class NewFeedbackScreen extends StatefulWidget {
  const NewFeedbackScreen({
    super.key,
    required this.projectId,
    this.initialTitle,
  });

  final String projectId;

  /// Pre-fills the title, e.g. when reporting against a specific test item.
  final String? initialTitle;

  @override
  State<NewFeedbackScreen> createState() => _NewFeedbackScreenState();
}

class _NewFeedbackScreenState extends State<NewFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.initialTitle ?? '',
  );
  final _descriptionController = TextEditingController();

  final List<_Attachment> _attachments = [];

  /// Platform id the tester selected, from the project's configured platforms.
  String? _selectedPlatform;

  /// Auto-detected device description (e.g. "Pixel 8 · Android 14").
  String? _device;

  /// Whether [_selectedPlatform] was set automatically (vs. user override).
  bool _platformAutoSelected = false;

  @override
  void initState() {
    super.initState();
    _initDeviceAndPlatform();
  }

  Future<void> _initDeviceAndPlatform() async {
    final detectedPlatform = currentPlatformId();
    final device = await describeCurrentDevice();
    if (!mounted) return;

    final project = AppScope.of(context).projectById(widget.projectId);
    final links = project?.platformLinks ?? const <PlatformLink>[];

    String? selected;
    var autoSelected = false;

    if (links.isEmpty) {
      selected = detectedPlatform;
      autoSelected = detectedPlatform != null;
    } else if (detectedPlatform != null &&
        links.any((l) => l.platform == detectedPlatform)) {
      selected = detectedPlatform;
      autoSelected = true;
    } else if (links.length == 1) {
      selected = links.first.platform;
      autoSelected = true;
    }

    setState(() {
      _device = device;
      _selectedPlatform = selected;
      _platformAutoSelected = autoSelected;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final messenger = ScaffoldMessenger.of(context);
    final List<XFile> files;
    try {
      files = await ImagePicker().pickMultipleMedia();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    for (final file in files) {
      await _addAndUpload(file);
    }
  }

  Future<void> _addAndUpload(XFile file) async {
    final contentType = _contentTypeFor(file);
    final isVideo = contentType.startsWith('video/');
    final bytes = await file.readAsBytes();
    final attachment = _Attachment(
      name: file.name,
      isVideo: isVideo,
      preview: isVideo ? null : bytes,
    );
    if (!mounted) return;
    setState(() => _attachments.add(attachment));
    try {
      final shot = await AppScope.of(context).uploadAttachment(
        projectId: widget.projectId,
        bytes: bytes,
        filename: file.name,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        attachment.uploaded = shot;
        attachment.uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        attachment.uploading = false;
        attachment.failed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _contentTypeFor(XFile file) {
    final mime = file.mimeType;
    if (mime != null && mime.isNotEmpty) return mime;
    final ext = file.name.contains('.') ? file.name.split('.').last : '';
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'application/octet-stream';
    }
  }

  bool get _uploadsInFlight => _attachments.any((a) => a.uploading);

  bool _submitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      await AppScope.of(context).sendFeedback(
        projectId: widget.projectId,
        title: _titleController.text,
        content: _descriptionController.text,
        device: _device,
        platform: _selectedPlatform,
        screenshots: [
          for (final a in _attachments)
            if (a.uploaded != null) a.uploaded!,
        ],
      );
      navigator.pop();
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
    final platformLinks = project?.platformLinks ?? const <PlatformLink>[];
    final showPlatformReadOnly =
        _selectedPlatform != null &&
        (platformLinks.isEmpty || platformLinks.length == 1);
    final showPlatformPicker = platformLinks.length > 1;

    final selectedPlatform = _selectedPlatform == null
        ? null
        : platformById(_selectedPlatform!);

    return Scaffold(
      appBar: AppBar(title: const Text('New report')),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.gutter + AppSpace.xs,
                  AppSpace.lg,
                  AppSpace.gutter + AppSpace.xs,
                  AppSpace.xxl,
                ),
                children: [
                  const _FieldLabel('Title'),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Short summary of the issue',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Add a short title'
                        : null,
                  ),
                  const SizedBox(height: AppSpace.xl),
                  const _FieldLabel('What happened'),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 6,
                    minLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'Steps you took, what you expected, what happened '
                          'instead…',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Describe what went wrong'
                        : null,
                  ),
                  if (showPlatformPicker) ...[
                    const SizedBox(height: AppSpace.xl),
                    const _FieldLabel('Build you\'re testing'),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.sm,
                      children: [
                        for (final link in platformLinks)
                          ChoiceChip(
                            avatar: Icon(
                              platformById(link.platform)?.icon ??
                                  AppIcons.devices,
                              size: 16,
                            ),
                            label: Text(
                              platformById(link.platform)?.label ??
                                  link.platform,
                            ),
                            selected: _selectedPlatform == link.platform,
                            onSelected: (selected) => setState(() {
                              _selectedPlatform = selected
                                  ? link.platform
                                  : null;
                              _platformAutoSelected = false;
                            }),
                          ),
                      ],
                    ),
                    if (_platformAutoSelected) ...[
                      const SizedBox(height: AppSpace.sm),
                      Text(
                        'Pre-selected from your device — change it if you\'re '
                        'testing somewhere else.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpace.xl),
                  const _FieldLabel('Screenshots & recordings'),
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _AddScreenshotTile(onTap: _pickMedia),
                        for (var i = 0; i < _attachments.length; i++) ...[
                          const SizedBox(width: AppSpace.sm + 2),
                          _AttachmentTile(
                            attachment: _attachments[i],
                            onRemove: () =>
                                setState(() => _attachments.removeAt(i)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  _AutoContext(
                    device: _device,
                    platformLabel: showPlatformReadOnly
                        ? (selectedPlatform?.label ?? _selectedPlatform)
                        : null,
                    platformIcon: selectedPlatform?.icon,
                  ),
                ],
              ),
            ),
            _SubmitBar(
              busy: _submitting,
              uploading: _uploadsInFlight,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// The read-only facts we staple onto every report. Grouped into one panel so
/// the form itself stays to the fields the tester actually fills in.
class _AutoContext extends StatelessWidget {
  const _AutoContext({
    required this.device,
    required this.platformLabel,
    required this.platformIcon,
  });

  final String? device;
  final String? platformLabel;
  final IconData? platformIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md + 2,
      ),
      decoration: BoxDecoration(
        color: tones.sunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: tones.hairline, width: AppStroke.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ATTACHED AUTOMATICALLY', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpace.md - 2),
          _AutoRow(
            icon: AppIcons.smartphone,
            value: device ?? 'Detecting your device…',
            muted: device == null,
          ),
          if (platformLabel != null) ...[
            const SizedBox(height: AppSpace.sm),
            _AutoRow(
              icon: platformIcon ?? AppIcons.devices,
              value: platformLabel!,
              muted: false,
            ),
          ],
          const SizedBox(height: AppSpace.md - 2),
          Text(
            'Developers use this to reproduce the issue on the right build.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoRow extends StatelessWidget {
  const _AutoRow({
    required this.icon,
    required this.value,
    required this.muted,
  });

  final IconData icon;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpace.sm + 2),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.busy,
    required this.uploading,
    required this.onSubmit,
  });

  final bool busy;
  final bool uploading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = AppTones.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tones.hairline, width: AppStroke.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.gutter,
            AppSpace.md,
            AppSpace.gutter,
            AppSpace.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (uploading) ...[
                Text(
                  'Waiting for attachments to finish uploading…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              FilledButton(
                onPressed: busy || uploading ? null : onSubmit,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Send report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Eyebrow label above a form field — same treatment as grouped section
/// headers so forms and lists read as one system.
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

class _AddScreenshotTile extends StatelessWidget {
  const _AddScreenshotTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: tones.hairline, width: AppStroke.thin),
          color: tones.sunken,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.imageAdd, color: scheme.primary, size: 20),
            const SizedBox(height: AppSpace.xs + 2),
            Text(
              'Attach',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.onRemove});

  final _Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget content;
    if (attachment.isVideo) {
      content = Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(AppIcons.play, color: Colors.white, size: 28),
        ),
      );
    } else if (attachment.preview != null) {
      content = Image.memory(attachment.preview!, fit: BoxFit.cover);
    } else {
      content = Container(color: scheme.surfaceContainerHighest);
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(width: 76, height: 100, child: content),
        ),
        if (attachment.uploading)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.black45),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        if (attachment.failed)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Center(
                child: Icon(
                  AppIcons.error,
                  color: scheme.onErrorContainer,
                  size: 24,
                ),
              ),
            ),
          ),
        Positioned(
          top: AppSpace.xs,
          right: AppSpace.xs,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.close, color: Colors.white, size: 13),
            ),
          ),
        ),
      ],
    );
  }
}
