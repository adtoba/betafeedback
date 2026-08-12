import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../models/project.dart';
import '../theme/app_icons.dart';
import '../theme/app_tokens.dart';

/// Creator sheet to set Play testing URL and optional Google Group join link.
Future<void> showEditDistributionSheet(
  BuildContext context, {
  required Project project,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _EditDistributionSheet(project: project),
  );
}

class _EditDistributionSheet extends StatefulWidget {
  const _EditDistributionSheet({required this.project});

  final Project project;

  @override
  State<_EditDistributionSheet> createState() => _EditDistributionSheetState();
}

class _EditDistributionSheetState extends State<_EditDistributionSheet> {
  late final TextEditingController _playController;
  late final TextEditingController _groupController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    var playUrl = '';
    for (final link in widget.project.platformLinks) {
      if (link.platform == 'android') {
        playUrl = link.url;
        break;
      }
    }
    _playController = TextEditingController(text: playUrl);
    _groupController = TextEditingController(
      text: widget.project.googleGroupJoinUrl ?? '',
    );
  }

  @override
  void dispose() {
    _playController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Enter a valid URL (https://…)';
    }
    return null;
  }

  Future<void> _save() async {
    final playUrl = _playController.text.trim();
    final groupUrl = _groupController.text.trim();

    if (playUrl.isNotEmpty && _validateUrl(playUrl) != null) return;
    if (groupUrl.isNotEmpty && _validateUrl(groupUrl) != null) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final links = <PlatformLink>[
        for (final link in widget.project.platformLinks)
          if (link.platform != 'android') link,
        if (playUrl.isNotEmpty)
          PlatformLink(platform: 'android', url: playUrl),
      ];

      await AppScope.of(context).updateProjectDistribution(
        projectId: widget.project.id,
        googleGroupJoinUrl: groupUrl.isEmpty ? null : groupUrl,
        platformLinks: links,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Android testing links updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpace.gutter,
          right: AppSpace.gutter,
          top: AppSpace.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Android closed testing',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Testers who join will see a checklist with these links. Add '
              'their emails in Play Console or via your Google Group.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            TextFormField(
              controller: _playController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Play testing link',
                hintText: 'https://play.google.com/apps/testing/…',
                prefixIcon: Icon(AppIcons.platformAndroid),
              ),
              validator: _validateUrl,
            ),
            const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: _groupController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Google Group join link (optional)',
                hintText: 'https://groups.google.com/g/…',
                prefixIcon: Icon(AppIcons.people),
              ),
              validator: _validateUrl,
            ),
            const SizedBox(height: AppSpace.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
