import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

/// A platform a project can target. [id] is the canonical value persisted in a
/// [PlatformLink], while [label], [icon], and [hint] drive the UI.
class ProjectPlatform {
  const ProjectPlatform({
    required this.id,
    required this.label,
    required this.icon,
    required this.hint,
  });

  final String id;
  final String label;
  final IconData icon;
  final String hint;
}

/// The platforms offered when creating a project, in display order.
const List<ProjectPlatform> kProjectPlatforms = [
  ProjectPlatform(
    id: 'ios',
    label: 'iOS',
    icon: AppIcons.platformIos,
    hint: 'TestFlight or App Store link',
  ),
  ProjectPlatform(
    id: 'android',
    label: 'Android',
    icon: AppIcons.platformAndroid,
    hint: 'Play Store or APK link',
  ),
  ProjectPlatform(
    id: 'web',
    label: 'Web',
    icon: AppIcons.platformWeb,
    hint: 'https://your-beta.app',
  ),
  ProjectPlatform(
    id: 'macos',
    label: 'macOS',
    icon: AppIcons.platformMac,
    hint: 'Download or build link',
  ),
  ProjectPlatform(
    id: 'windows',
    label: 'Windows',
    icon: AppIcons.platformWindows,
    hint: 'Download or build link',
  ),
  ProjectPlatform(
    id: 'linux',
    label: 'Linux',
    icon: AppIcons.platformLinux,
    hint: 'Download or build link',
  ),
];

/// Looks up the catalog entry for a stored platform id, or null if unknown.
ProjectPlatform? platformById(String id) {
  for (final platform in kProjectPlatforms) {
    if (platform.id == id) return platform;
  }
  return null;
}
