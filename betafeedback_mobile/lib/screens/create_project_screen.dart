import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_scope.dart';
import '../models/project.dart';
import '../models/project_platform.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/grouped_list.dart';
import '../widgets/project_logo.dart';
import '../utils/store_compliance.dart';
import 'find_testers_screen.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  static const _allSteps = [
    _StepMeta(
      label: 'Basics',
      title: 'Project details',
      subtitle: 'Give your project a clear name and short description.',
    ),
    _StepMeta(
      label: 'Platforms',
      title: 'Target platforms',
      subtitle: 'Where testers will run the build. You can skip this.',
    ),
    _StepMeta(
      label: 'Links',
      title: 'App links',
      subtitle: 'TestFlight, Play Store, or web URLs — all optional.',
    ),
  ];

  List<_StepMeta> get _steps => supportsBetaDistributionUi
      ? _allSteps
      : _allSteps.sublist(0, 1);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memberNotesController = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  final _selectedPlatforms = <String>{};
  final _linkControllers = <String, TextEditingController>{};
  final _googleGroupController = TextEditingController();
  Uint8List? _logoBytes;
  String? _logoFilename;
  String? _logoContentType;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberNotesController.dispose();
    for (final controller in _linkControllers.values) {
      controller.dispose();
    }
    _googleGroupController.dispose();
    super.dispose();
  }

  void _togglePlatform(String id) {
    setState(() {
      if (_selectedPlatforms.contains(id)) {
        _selectedPlatforms.remove(id);
      } else {
        _selectedPlatforms.add(id);
        _linkControllers.putIfAbsent(id, TextEditingController.new);
      }
    });
  }

  List<PlatformLink> _collectPlatformLinks() {
    if (!supportsBetaDistributionUi) return const [];
    final links = <PlatformLink>[];
    for (final platform in availableProjectPlatforms) {
      if (!_selectedPlatforms.contains(platform.id)) continue;
      final url = _linkControllers[platform.id]?.text.trim() ?? '';
      if (url.isEmpty) continue;
      links.add(PlatformLink(platform: platform.id, url: url));
    }
    return links;
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _logoBytes = bytes;
      _logoFilename = file.name;
      _logoContentType = _contentTypeForFilename(file.name);
    });
  }

  void _clearLogo() {
    setState(() {
      _logoBytes = null;
      _logoFilename = null;
      _logoContentType = null;
    });
  }

  String _contentTypeForFilename(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _submitting = true);
    try {
      final project = await AppScope.of(context).createProject(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        memberNotes: _memberNotesController.text.trim(),
        googleGroupJoinUrl: supportsAndroidDistributionUi &&
                _selectedPlatforms.contains('android')
            ? _googleGroupController.text.trim()
            : null,
        platformLinks: _collectPlatformLinks(),
        logoBytes: _logoBytes,
        logoFilename: _logoFilename,
        logoContentType: _logoContentType,
      );
      if (!mounted) return;
      navigator.pop();
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => FindTestersScreen(
            projectId: project.id,
            projectName: project.name,
            showSkip: true,
          ),
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

  String? _validateUrl(String? value) {
    final url = value?.trim() ?? '';
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return 'Enter a valid URL (https://…)';
    }
    return null;
  }

  bool _validateCurrentStep() {
    if (_step == 0 || _step == 2) {
      return _formKey.currentState!.validate();
    }
    return true;
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goNext() {
    if (!_validateCurrentStep()) return;
    setState(() => _step++);
  }

  @override
  Widget build(BuildContext context) {
    final meta = _steps[_step];
    final isLastStep = _step == _steps.length - 1;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _goBack),
          title: const Text('New project'),
        ),
        body: AppLayout.adaptiveBody(
          context,
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, 0),
                    children: [
                      _StepProgress(currentStep: _step, steps: _steps),
                      const SizedBox(height: AppSpace.xl),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.gutter + AppSpace.xs,
                        ),
                        child: _StepHeader(
                          title: meta.title,
                          subtitle: meta.subtitle,
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                      AnimatedSwitcher(
                        duration: AppDuration.medium,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _BasicsStep(
                              nameController: _nameController,
                              descriptionController: _descriptionController,
                              memberNotesController: _memberNotesController,
                              logoBytes: _logoBytes,
                              onPickLogo: _pickLogo,
                              onClearLogo: _clearLogo,
                            ),
                            1 => _PlatformsStep(
                              selectedPlatforms: _selectedPlatforms,
                              onToggle: _togglePlatform,
                            ),
                            _ => _LinksStep(
                              selectedPlatforms: _selectedPlatforms,
                              linkControllers: _linkControllers,
                              googleGroupController: _googleGroupController,
                              validateUrl: _validateUrl,
                            ),
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpace.xxl),
                    ],
                  ),
                ),
                _BottomBar(
                  showBack: _step > 0,
                  isLastStep: isLastStep,
                  submitting: _submitting,
                  onBack: _goBack,
                  onPrimary: isLastStep ? _submit : _goNext,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepMeta {
  const _StepMeta({
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final String label;
  final String title;
  final String subtitle;
}

/// Progress as a hairline track split into one segment per step, with the step
/// name spelled out — quieter than numbered dots and it scales to any count.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.currentStep, required this.steps});

  final int currentStep;
  final List<_StepMeta> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tones = AppTones.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.gutter + AppSpace.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < steps.length; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i == steps.length - 1 ? 0 : AppSpace.xs + 1,
                    ),
                    child: AnimatedContainer(
                      duration: AppDuration.medium,
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= currentStep ? scheme.primary : tones.sunken,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.md - 2),
          Text(
            'STEP ${currentStep + 1} OF ${steps.length} · '
            '${steps[currentStep].label.toUpperCase()}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpace.sm - 2),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({
    required this.nameController,
    required this.descriptionController,
    required this.memberNotesController,
    required this.logoBytes,
    required this.onPickLogo,
    required this.onClearLogo,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController memberNotesController;
  final Uint8List? logoBytes;
  final VoidCallback onPickLogo;
  final VoidCallback onClearLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPickLogo,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: logoBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.memory(
                                logoBytes!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            )
                          : ListenableBuilder(
                              listenable: nameController,
                              builder: (context, _) {
                                final previewName = nameController.text.trim();
                                return ProjectLogo(
                                  projectName: previewName.isEmpty
                                      ? 'Project'
                                      : previewName,
                                  size: 64,
                                  borderRadius: AppRadius.md,
                                );
                              },
                            ),
                    ),
                  ),
                  if (logoBytes != null)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Material(
                        color: scheme.surfaceContainerHighest,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: IconButton(
                          tooltip: 'Remove logo',
                          visualDensity: VisualDensity.compact,
                          iconSize: 15,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onPressed: onClearLogo,
                          icon: Icon(
                            AppIcons.close,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onPickLogo,
                      child: Text(
                        logoBytes == null ? 'Add an app logo' : 'Change logo',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    // const SizedBox(height: AppSpace.xxs),
                    // Text(
                    //   'Included with Pro. Otherwise we generate one from the '
                    //   'project name.',
                    //   style: theme.textTheme.bodySmall,
                    // ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Project name',
              hintText: 'e.g. ShopFlow Mobile',
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What is this project about?',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Description is required'
                : null,
          ),
          const SizedBox(height: AppSpace.md),
          TextFormField(
            controller: memberNotesController,
            decoration: const InputDecoration(
              labelText: 'Getting started notes (optional)',
              hintText:
                  'Download links, install steps, staging URLs — '
                  'visible to everyone who joins.',
              alignLabelWithHint: true,
            ),
            maxLines: 5,
          ),
        ],
      ),
    );
  }
}

class _PlatformsStep extends StatelessWidget {
  const _PlatformsStep({
    required this.selectedPlatforms,
    required this.onToggle,
  });

  final Set<String> selectedPlatforms;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GroupedSection(
      header: 'Where testers will run it',
      footer: 'Pick as many as apply — you can change this later.',
      children: [
        for (final platform in availableProjectPlatforms)
          GroupedListTile(
            icon: platform.icon,
            title: platform.label,
            showChevron: false,
            onTap: () => onToggle(platform.id),
            trailing: selectedPlatforms.contains(platform.id)
                ? Icon(AppIcons.check, size: 19, color: scheme.primary)
                : null,
          ),
      ],
    );
  }
}

class _LinksStep extends StatelessWidget {
  const _LinksStep({
    required this.selectedPlatforms,
    required this.linkControllers,
    required this.googleGroupController,
    required this.validateUrl,
  });

  final Set<String> selectedPlatforms;
  final Map<String, TextEditingController> linkControllers;
  final TextEditingController googleGroupController;
  final String? Function(String?) validateUrl;

  @override
  Widget build(BuildContext context) {
    final selected = availableProjectPlatforms
        .where((p) => selectedPlatforms.contains(p.id))
        .toList();

    if (selected.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpace.gutter),
        child: AppEmptyState(
          icon: AppIcons.link,
          title: 'No platforms picked',
          message:
              'Nothing to link yet. Create the project and add build links '
              'from its page whenever you have them.',
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < selected.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpace.md),
            TextFormField(
              controller: linkControllers[selected[i].id],
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: selected[i].label,
                hintText: selected[i].hint,
                prefixIcon: Icon(selected[i].icon),
              ),
              validator: validateUrl,
            ),
            if (supportsAndroidDistributionUi &&
                selected[i].id == 'android') ...[
              const SizedBox(height: AppSpace.md),
              TextFormField(
                controller: googleGroupController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Google Group join link (optional)',
                  hintText: 'https://groups.google.com/g/…',
                  prefixIcon: Icon(AppIcons.people),
                ),
                validator: validateUrl,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.showBack,
    required this.isLastStep,
    required this.submitting,
    required this.onBack,
    required this.onPrimary,
  });

  final bool showBack;
  final bool isLastStep;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
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
          child: Row(
            children: [
              if (showBack) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: submitting ? null : onBack,
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                flex: showBack ? 2 : 1,
                child: FilledButton(
                  onPressed: submitting ? null : onPrimary,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(isLastStep ? 'Create project' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
