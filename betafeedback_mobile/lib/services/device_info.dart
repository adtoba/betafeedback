import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Returns the canonical platform id ([ProjectPlatform.id]) for the device
/// this app is running on — e.g. `ios`, `android`, `web`.
String? currentPlatformId() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return null;
  }
}

/// Builds a short, human-readable description of the device the app is running
/// on — e.g. "Pixel 8 · Android 14" — so testers don't have to type it.
/// Returns null if it can't be determined.
Future<String?> describeCurrentDevice() async {
  final info = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final web = await info.webBrowserInfo;
      final browser = web.browserName.name;
      return web.platform == null ? browser : '$browser · ${web.platform}';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model} · Android ${a.version.release}';
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        return '${i.utsname.machine} · iOS ${i.systemVersion}';
      case TargetPlatform.macOS:
        final m = await info.macOsInfo;
        return '${m.model} · macOS ${m.osRelease}';
      case TargetPlatform.windows:
        final w = await info.windowsInfo;
        return w.productName;
      case TargetPlatform.linux:
        final l = await info.linuxInfo;
        return l.prettyName;
      case TargetPlatform.fuchsia:
        return null;
    }
  } catch (_) {
    return null;
  }
}
