import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../screens/project_detail_screen.dart';

/// Parses Universal Links / custom-scheme URLs and opens the matching screen.
///
/// Supported:
/// - `https://betafeedback.com/open/projects/{id}`
/// - `https://betafeedback.com/join/{code}`
/// - `betafeedback://projects/{id}`
/// - `betafeedback://join/{code}`
class DeepLinkService {
  DeepLinkService();

  final _appLinks = AppLinks();
  GlobalKey<NavigatorState>? navigatorKey;

  /// Joins a project by invite code and returns the project id, or null on failure.
  Future<String?> Function(String code)? joinWithCode;

  StreamSubscription<Uri>? _sub;
  Uri? _pending;
  bool _canNavigate = false;
  bool _started = false;
  bool _ready = false;

  /// Last project opened via deep link (dedupe repeated deliveries).
  String? _lastOpenedProjectId;
  DateTime? _lastOpenedAt;
  String? _lastJoinedCode;
  DateTime? _lastJoinedAt;

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
  /// Only reacts when [ready] changes so AppState rebuilds don't re-flush.
  void setNavigationReady(bool ready) {
    if (_ready == ready) return;
    _ready = ready;
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
    final joinCode = parseJoinCode(uri);
    if (joinCode != null && joinCode.isNotEmpty) {
      if (!_canNavigate) {
        _pending = uri;
        return;
      }
      unawaited(_joinAndOpen(joinCode));
      return;
    }

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

  Future<void> _joinAndOpen(String code) async {
    final now = DateTime.now();
    if (_lastJoinedCode == code &&
        _lastJoinedAt != null &&
        now.difference(_lastJoinedAt!) < const Duration(seconds: 3)) {
      debugPrint('DeepLinkService: skipping duplicate join for $code');
      return;
    }
    _lastJoinedCode = code;
    _lastJoinedAt = now;

    final join = joinWithCode;
    if (join == null) {
      debugPrint('DeepLinkService: joinWithCode not wired');
      return;
    }

    try {
      final projectId = await join(code);
      if (projectId == null || projectId.isEmpty) return;
      openProject(projectId);
    } catch (e) {
      debugPrint('DeepLinkService: join failed for $code: $e');
      final nav = navigatorKey?.currentState;
      if (nav == null || !nav.mounted) return;
      ScaffoldMessenger.maybeOf(nav.context)?.showSnackBar(
        SnackBar(
          content: Text('Couldn\'t join with that invite link: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void openProject(String projectId) {
    final now = DateTime.now();
    if (_lastOpenedProjectId == projectId &&
        _lastOpenedAt != null &&
        now.difference(_lastOpenedAt!) < const Duration(seconds: 2)) {
      debugPrint('DeepLinkService: skipping duplicate open for $projectId');
      return;
    }

    final nav = navigatorKey?.currentState;
    if (nav == null) {
      _pending = Uri(
        scheme: 'betafeedback',
        host: 'projects',
        path: '/$projectId',
      );
      return;
    }

    _lastOpenedProjectId = projectId;
    _lastOpenedAt = now;

    nav.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/projects/$projectId'),
        builder: (_) => ProjectDetailScreen(projectId: projectId),
      ),
    );
  }

  /// Extracts a join invite code from supported deep-link shapes.
  static String? parseJoinCode(Uri uri) {
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    // https://betafeedback.com/join/{code}
    if ((host == 'betafeedback.com' || host == 'www.betafeedback.com') &&
        segments.length >= 2 &&
        segments[0] == 'join') {
      return Uri.decodeComponent(segments[1]);
    }

    // betafeedback://join/{code}
    if (uri.scheme == 'betafeedback') {
      if (host == 'join' && segments.isNotEmpty) {
        return Uri.decodeComponent(segments.first);
      }
      if (segments.length >= 2 && segments[0] == 'join') {
        return Uri.decodeComponent(segments[1]);
      }
    }

    return null;
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
    if (uri.scheme == 'betafeedback') {
      if (host == 'projects' && segments.isNotEmpty) {
        return segments.first;
      }
      if (host == 'open' &&
          segments.length >= 2 &&
          segments[0] == 'projects') {
        return segments[1];
      }
      if (segments.length >= 2 && segments[0] == 'projects') {
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
