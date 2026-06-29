import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/app_scope.dart';
import '../models/project.dart';
import '../models/project_platform.dart';
import '../theme/app_icons.dart';
import '../theme/app_layout.dart';
import '../widgets/grouped_list.dart';
import '../widgets/plan_picker_sheet.dart';
import '../widgets/project_logo.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  static const _steps = [
    _StepMeta(
      label: 'Basics',
      title: 'Project details',
      subtitle: 'Give your beta a clear name and short description.',
    ),
    _StepMeta(
      label: 'Platforms',
      title: 'Target platforms',
      subtitle: 'Where testers will run the build. You can skip this.',
    ),
    _StepMeta(
      label: 'Links',
      title: 'Test links',
      subtitle: 'TestFlight, Play Store, or web URLs — all optional.',
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _step = 0;
  bool _submitting = false;
  final _selectedPlatforms = <String>{};
  final _linkControllers = <String, TextEditingController>{};
  Uint8List? _logoBytes;
  String? _logoFilename;
  String? _logoContentType;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    for (final controller in _linkControllers.values) {
      controller.dispose();
    }
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
    final links = <PlatformLink>[];
    for (final platform in kProjectPlatforms) {
      if (!_selectedPlatforms.contains(platform.id)) continue;
      final url = _linkControllers[platform.id]?.text.trim() ?? '';
      if (url.isEmpty) continue;
      links.add(PlatformLink(platform: platform.id, url: url));
    }
    return links;
  }

  Future<void> _pickLogo() async {
    final appState = AppScope.of(context);
    if (!appState.isPro) {
      showPlanPickerSheet(
        context,
        title: 'Pro feature',
        currentPlan: appState.currentSubscription.plan,
        onSelect: (plan) => appState.changePlan(plan),
      );
      return;
    }
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
      await AppScope.of(context).createProject(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        platformLinks: _collectPlatformLinks(),
        logoBytes: _logoBytes,
        logoFilename: _logoFilename,
        logoContentType: _logoContentType,
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
                    padding: const EdgeInsets.fromLTRB(0, 20, 0, 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _StepHeader(
                          title: meta.title,
                          subtitle: meta.subtitle,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _StepStrip(currentStep: _step, steps: _steps),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: switch (_step) {
                            0 => _BasicsStep(
                                nameController: _nameController,
                                descriptionController: _descriptionController,
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
                                validateUrl: _validateUrl,
                              ),
                          },
                        ),
                      ),
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

/// Segmented step progress — active step highlighted, completed steps checked.
class _StepStrip extends StatelessWidget {
  const _StepStrip({required this.currentStep, required this.steps});

  final int currentStep;
  final List<_StepMeta> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 22),
                  color: i <= currentStep
                      ? scheme.primary
                      : scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
            _StepDot(
              index: i,
              label: steps[i].label,
              isActive: i == currentStep,
              isComplete: i < currentStep,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isComplete,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final Color fill;
    final Color border;
    final Color labelColor;
    Widget center;

    if (isComplete) {
      fill = scheme.primary;
      border = scheme.primary;
      labelColor = scheme.onSurface;
      center = Icon(AppIcons.check, size: 14, color: scheme.onPrimary);
    } else if (isActive) {
      fill = scheme.primary;
      border = scheme.primary;
      labelColor = scheme.onSurface;
      center = Text(
        '${index + 1}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      fill = scheme.surfaceContainerHighest;
      border = scheme.outlineVariant.withValues(alpha: 0.6);
      labelColor = scheme.onSurfaceVariant;
      center = Text(
        '${index + 1}',
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: isActive ? 0 : 1.5),
          ),
          child: center,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: labelColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
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
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.35,
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
    required this.logoBytes,
    required this.onPickLogo,
    required this.onClearLogo,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final Uint8List? logoBytes;
  final VoidCallback onPickLogo;
  final VoidCallback onClearLogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onPickLogo,
                        borderRadius: BorderRadius.circular(16),
                        child: logoBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  logoBytes!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : ListenableBuilder(
                                listenable: nameController,
                                builder: (context, _) {
                                  final previewName =
                                      nameController.text.trim();
                                  return ProjectLogo(
                                    projectName: previewName.isEmpty
                                        ? 'Project'
                                        : previewName,
                                    size: 80,
                                    borderRadius: 16,
                                  );
                                },
                              ),
                      ),
                    ),
                    if (logoBytes != null)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: Material(
                          color: scheme.surfaceContainerHighest,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: IconButton(
                            tooltip: 'Remove logo',
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
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
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onPickLogo,
                  icon: Icon(
                    logoBytes == null ? AppIcons.imageAdd : AppIcons.image,
                    size: 18,
                  ),
                  label: Text(
                    logoBytes == null
                        ? 'Add app logo (Pro)'
                        : 'Change logo',
                  ),
                ),
                Text(
                  'Custom logos are included on Pro.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 12),
          TextFormField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'What is this beta about?',
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Description is required' : null,
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
      header: 'Select platforms',
      children: [
        for (final platform in kProjectPlatforms)
          GroupedListTile(
            icon: platform.icon,
            title: platform.label,
            showChevron: false,
            onTap: () => onToggle(platform.id),
            trailing: selectedPlatforms.contains(platform.id)
                ? Icon(AppIcons.checkCircle, size: 22, color: scheme.primary)
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
    required this.validateUrl,
  });

  final Set<String> selectedPlatforms;
  final Map<String, TextEditingController> linkControllers;
  final String? Function(String?) validateUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = kProjectPlatforms
        .where((p) => selectedPlatforms.contains(p.id))
        .toList();

    if (selected.isEmpty) {
      return GroupedSection(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              children: [
                Icon(
                  AppIcons.link,
                  size: 32,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
                ),
                const SizedBox(height: 12),
                Text(
                  'No platforms selected',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Skip for now — add links from the project page anytime.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < selected.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.icon(
              onPressed: submitting ? null : onPrimary,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(
                      isLastStep ? AppIcons.check : AppIcons.arrowRight,
                      size: 18,
                    ),
              label: Text(isLastStep ? 'Create project' : 'Continue'),
            ),
            if (showBack) ...[
              const SizedBox(height: 4),
              TextButton(onPressed: onBack, child: const Text('Back')),
            ],
          ],
        ),
      ),
    );
  }
}
