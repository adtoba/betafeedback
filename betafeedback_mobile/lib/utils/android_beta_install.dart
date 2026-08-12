import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../models/project.dart';

/// Play closed-testing URL from platform links, if set.
String? androidPlayTestingUrl(Project project) {
  for (final link in project.platformLinks) {
    if (link.platform == 'android' && link.url.trim().isNotEmpty) {
      return link.url.trim();
    }
  }
  return null;
}

/// Whether the project has Android distribution info worth showing to testers.
bool projectHasAndroidBetaInstall(Project project) {
  final group = project.googleGroupJoinUrl?.trim() ?? '';
  return group.isNotEmpty || androidPlayTestingUrl(project) != null;
}

bool shouldOfferAndroidBetaInstallSheet() {
  if (kIsWeb) return false;
  return Platform.isAndroid;
}
