import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_scope.dart';
import '../models/feedback.dart';
import '../models/project.dart';
import '../models/project_platform.dart';
import '../services/device_info.dart';

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
  late final _titleController =
      TextEditingController(text: widget.initialTitle ?? '');
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
    final scheme = theme.colorScheme;
    final project = AppScope.of(context).projectById(widget.projectId);
    final platformLinks = project?.platformLinks ?? const <PlatformLink>[];
    final showPlatformReadOnly = _selectedPlatform != null &&
        (platformLinks.isEmpty || platformLinks.length == 1);
    final showPlatformPicker = platformLinks.length > 1;

    return Scaffold(
      appBar: AppBar(title: const Text('New feedback')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _Label('Title'),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Short summary of the issue',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Add a short title' : null,
            ),
            const SizedBox(height: 20),
            _Label('Description'),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText:
                    'What happened? What did you expect? Steps to reproduce…',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Describe what went wrong'
                  : null,
            ),
            if (showPlatformReadOnly) ...[
              const SizedBox(height: 20),
              _Label('Platform'),
              _DetectedPlatformRow(platformId: _selectedPlatform!),
              const SizedBox(height: 4),
              Text(
                'Detected automatically and attached to your report.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (showPlatformPicker) ...[
              const SizedBox(height: 20),
              _Label('Platform you\'re testing'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final link in platformLinks)
                    ChoiceChip(
                      avatar: Icon(
                        platformById(link.platform)?.icon ?? AppIcons.devices,
                        size: 18,
                      ),
                      label: Text(
                        platformById(link.platform)?.label ?? link.platform,
                      ),
                      selected: _selectedPlatform == link.platform,
                      onSelected: (selected) => setState(() {
                        _selectedPlatform = selected ? link.platform : null;
                        _platformAutoSelected = false;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _platformAutoSelected
                    ? 'Pre-selected from your device. Tap another platform if you\'re testing elsewhere.'
                    : 'Select the build you\'re testing.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _Label('Device'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(AppIcons.smartphone,
                      size: 18, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _device ?? 'Detecting your device…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _device == null
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Detected automatically and attached to your report.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            _Label('Screenshots & recordings'),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _AddScreenshotTile(onTap: _pickMedia),
                  for (var i = 0; i < _attachments.length; i++) ...[
                    const SizedBox(width: 10),
                    _AttachmentTile(
                      attachment: _attachments[i],
                      onRemove: () => setState(() => _attachments.removeAt(i)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Attach screenshots or screen recordings from your gallery.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _submitting || _uploadsInFlight ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(AppIcons.send, size: 18),
              label: const Text('Submit feedback'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectedPlatformRow extends StatelessWidget {
  const _DetectedPlatformRow({required this.platformId});

  final String platformId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final platform = platformById(platformId);
    final label = platform?.label ?? platformId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            platform?.icon ?? AppIcons.devices,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AddScreenshotTile extends StatelessWidget {
  const _AddScreenshotTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.imageAdd,
                color: scheme.onSurfaceVariant, size: 22),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
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
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(width: 72, height: 96, child: content),
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(AppIcons.error,
                    color: scheme.onErrorContainer, size: 24),
              ),
            ),
          ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
