import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/project_detail_screen.dart';

/// Parses Universal Links / custom-scheme URLs and opens the matching screen.
///
/// Supported:
/// - `https://betafeedback.com/open/projects/{id}`
/// - `betafeedback://projects/{id}`
/// - `betafeedback://open/projects/{id}`
class DeepLinkService {
  DeepLinkService();

  final _appLinks = AppLinks();
  GlobalKey<NavigatorState>? navigatorKey;

  StreamSubscription<Uri>? _sub;
  Uri? _pending;
  bool _canNavigate = false;
  bool _started = false;

  /// Call once after [navigatorKey] is assigned.
  Future<void> start() async {
    if (_started || kIsWeb) return;
    _started = true;

    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handle(initial);
      }
    } catch (e) {
      debugPrint('DeepLinkService initial link failed: $e');
    }

    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (Object e) => debugPrint('DeepLinkService stream error: $e'),
    );
  }

  /// Allow navigation only when the user is signed in and bootstrap finished.
  void setNavigationReady(bool ready) {
    _canNavigate = ready;
    if (ready) {
      _flushPending();
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  void _handle(Uri uri) {
    final projectId = parseProjectId(uri);
    if (projectId == null || projectId.isEmpty) {
      debugPrint('DeepLinkService: ignored $uri');
      return;
    }
    if (!_canNavigate) {
      _pending = uri;
      return;
    }
    openProject(projectId);
  }

  void _flushPending() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    _handle(pending);
  }

  void openProject(String projectId) {
    final nav = navigatorKey?.currentState;
    if (nav == null) {
      _pending = Uri(scheme: 'betafeedback', path: '/projects/$projectId');
      return;
    }
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    );
  }

  /// Extracts a project id from supported deep-link shapes.
  static String? parseProjectId(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // https://betafeedback.com/open/projects/{id}
    if ((host == 'betafeedback.com' || host == 'www.betafeedback.com') &&
        segments.length >= 3 &&
        segments[0] == 'open' &&
        segments[1] == 'projects') {
      return segments[2];
    }

    // betafeedback://projects/{id}
    // betafeedback://open/projects/{id}
    // Some platforms put the first path segment in [host].
    if (uri.scheme == 'betafeedback') {
      if (host == 'projects' && segments.isNotEmpty) {
        return segments.first;
      }
      if (host == 'open' &&
          segments.length >= 2 &&
          segments[0] == 'projects') {
        return segments[1];
      }
      if (segments.length >= 2 &&
          segments[0] == 'projects') {
        return segments[1];
      }
      if (segments.length >= 3 &&
          segments[0] == 'open' &&
          segments[1] == 'projects') {
        return segments[2];
      }
    }

    return null;
  }
}
