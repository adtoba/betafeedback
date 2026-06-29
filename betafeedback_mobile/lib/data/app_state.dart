import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity.dart';
import '../models/app_notification.dart';
import '../models/feedback.dart';
import '../models/project.dart';
import '../models/release.dart';
import '../models/subscription.dart';
import '../models/test_item.dart';
import '../models/user.dart';
import '../services/api_client.dart';

/// Application state backed by the BetaFeedback API. Network calls populate
/// in-memory caches; the UI reads those caches synchronously via getters and
/// rebuilds through [notifyListeners].
class AppState extends ChangeNotifier {
  AppState({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  SharedPreferences? _prefs;

  static const _tokenKey = 'auth_token';
  static const _themeKey = 'theme_mode';
  static const _viewedPrefix = 'viewed_';

  static const Subscription _defaultSubscription = Subscription(
    plan: SubscriptionPlan.free,
    status: SubscriptionStatus.active,
    projectLimit: 1,
  );

  // --- Auth / lifecycle ---
  bool _bootstrapped = false;
  bool _signedIn = false;
  User? _currentUser;

  bool get isBootstrapped => _bootstrapped;
  bool get isSignedIn => _signedIn;
  User get currentUser =>
      _currentUser ?? const User(id: '', name: '', email: '');

  // --- Caches ---
  final Map<String, Project> _projectsById = {};
  List<String> _projectOrder = [];
  final Map<String, User> _users = {};
  final Map<String, List<ActivityLog>> _activityByProject = {};
  List<AppNotification> _notifications = [];
  Subscription? _subscription;

  // --- Loading / error state ---
  bool isLoadingProjects = false;
  String? projectsError;
  final Set<String> _loadingProjects = {};
  final Map<String, String?> _projectErrors = {};

  bool isProjectLoading(String id) => _loadingProjects.contains(id);
  String? projectError(String id) => _projectErrors[id];

  // --- Theme ---
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _prefs?.setString(_themeKey, _themeMode.name);
    notifyListeners();
  }

  // --- Bootstrap ---

  /// Restores theme and any stored session, then loads initial data.
  Future<void> bootstrap() async {
    _prefs = await SharedPreferences.getInstance();
    final storedTheme = _prefs?.getString(_themeKey);
    if (storedTheme != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == storedTheme,
        orElse: () => ThemeMode.system,
      );
    }

    final token = _prefs?.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      _api.setToken(token);
      try {
        final me = await _api.get('/v1/me');
        _currentUser = User.fromJson(me as Map<String, dynamic>);
        _signedIn = true;
        await Future.wait([loadProjects(), loadNotifications(), loadSubscription()]);
      } on ApiException {
        // Token invalid/expired or server unreachable — fall back to sign-in.
        await _clearSession();
      }
    }

    _bootstrapped = true;
    notifyListeners();
  }

  // --- Auth ---

  /// Requests an email one-time code. Returns the dev `debug_code` when the
  /// backend is in debug mode, otherwise null.
  Future<String?> requestEmailCode(String email) async {
    final res = await _api.post('/v1/auth/email/start', {'email': email});
    return (res as Map<String, dynamic>?)?['debug_code'] as String?;
  }

  Future<void> verifyEmailCode(String email, String code) async {
    final res = await _api.post(
      '/v1/auth/email/verify',
      {'email': email, 'code': code},
    ) as Map<String, dynamic>;

    final token = res['token'] as String;
    await _prefs?.setString(_tokenKey, token);
    _api.setToken(token);
    _currentUser = User.fromJson(res['user'] as Map<String, dynamic>);
    _signedIn = true;
    notifyListeners();

    await Future.wait([loadProjects(), loadNotifications(), loadSubscription()]);
  }

  Future<void> signOut() async {
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    await _prefs?.remove(_tokenKey);
    _api.setToken(null);
    _signedIn = false;
    _currentUser = null;
    _projectsById.clear();
    _projectOrder = [];
    _users.clear();
    _activityByProject.clear();
    _notifications = [];
    _subscription = null;
  }

  // --- Selectors ---
  List<Project> get myProjects => _projectOrder
      .map((id) => _projectsById[id])
      .whereType<Project>()
      .toList();

  Project? projectById(String id) => _projectsById[id];

  User? userById(String id) => _users[id];

  List<ActivityLog> activityForProject(String projectId) =>
      _activityByProject[projectId] ?? const [];

  List<AppNotification> get myNotifications => _notifications;

  int get unreadNotificationCount =>
      _notifications.where((n) => !n.read).length;

  Subscription get currentSubscription => _subscription ?? _defaultSubscription;
  int get projectsCreatedByCurrentUser =>
      _subscription?.projectsCreated ?? myProjects.length;

  bool get isPro => currentSubscription.plan == SubscriptionPlan.pro;

  bool get canCreateMoreProjects {
    final limit = currentSubscription.projectLimit;
    if (limit == null) return true;
    return projectsCreatedByCurrentUser < limit;
  }

  // --- Unread tracking (client-side) ---

  DateTime? _latestActivityFor(Project project) {
    var latest = project.latestActivityAt ?? project.latestFeedbackAt;
    for (final message in project.feedback) {
      if (latest == null || message.createdAt.isAfter(latest)) {
        latest = message.createdAt;
      }
    }
    for (final entry in _activityByProject[project.id] ?? const []) {
      if (latest == null || entry.createdAt.isAfter(latest)) {
        latest = entry.createdAt;
      }
    }
    return latest;
  }

  bool projectHasUnread(Project project) {
    final latest = _latestActivityFor(project);
    if (latest == null) return false;
    final viewedIso = _prefs?.getString('$_viewedPrefix${project.id}');
    if (viewedIso == null) return true;
    final viewed = DateTime.tryParse(viewedIso);
    return viewed == null || latest.isAfter(viewed);
  }

  Future<void> markProjectViewed(String projectId) async {
    final project = _projectsById[projectId];
    final latest = project == null
        ? DateTime.now()
        : (_latestActivityFor(project) ?? DateTime.now());
    await _prefs?.setString(
      '$_viewedPrefix$projectId',
      latest.toIso8601String(),
    );
    notifyListeners();
  }

  DateTime? _maxTimestamp(Iterable<DateTime> times) {
    DateTime? latest;
    for (final time in times) {
      if (latest == null || time.isAfter(latest)) {
        latest = time;
      }
    }
    return latest;
  }

  // --- Projects ---
  Future<void> loadProjects() async {
    isLoadingProjects = true;
    projectsError = null;
    notifyListeners();
    try {
      final res = await _api.get('/v1/projects') as Map<String, dynamic>;
      final projects = (res['projects'] as List)
          .map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList();
      _projectOrder = projects.map((p) => p.id).toList();
      for (final p in projects) {
        // Preserve any already-loaded detail (members/feedback/etc.).
        final existing = _projectsById[p.id];
        _projectsById[p.id] = existing == null
            ? p
            : p.copyWith(
                members: existing.members,
                feedback: existing.feedback,
                structuredBugs: existing.structuredBugs,
                testPlan: existing.testPlan,
                releases: existing.releases,
                latestActivityAt:
                    p.latestActivityAt ?? existing.latestActivityAt,
              );
      }
    } on ApiException catch (e) {
      projectsError = e.message;
    } finally {
      isLoadingProjects = false;
      notifyListeners();
    }
  }

  /// Loads a project's full detail (members, feedback, bugs, test plan,
  /// activity) and assembles it into the cache.
  Future<void> loadProject(String id) async {
    _loadingProjects.add(id);
    _projectErrors[id] = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.get('/v1/projects/$id'),
        _api.get('/v1/projects/$id/feedback'),
        _api.get('/v1/projects/$id/bugs'),
        _api.get('/v1/projects/$id/test-items'),
        _api.get('/v1/projects/$id/activity'),
        _api.get('/v1/projects/$id/releases'),
      ]);

      var project =
          Project.fromJson(results[0] as Map<String, dynamic>);

      // Cache member users (with their per-project role).
      for (final m in project.members) {
        _users[m.id] = m;
      }

      final feedback = ((results[1] as Map)['feedback'] as List)
          .map((e) => FeedbackMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      // Ensure feedback authors are resolvable even if no longer members.
      for (final f in feedback) {
        _users.putIfAbsent(
          f.authorId,
          () => User(id: f.authorId, name: f.authorName, email: ''),
        );
      }

      final bugs = ((results[2] as Map)['bugs'] as List)
          .map((e) => StructuredBug.fromJson(e as Map<String, dynamic>))
          .toList();
      final testPlan = ((results[3] as Map)['test_items'] as List)
          .map((e) => TestItem.fromJson(e as Map<String, dynamic>))
          .toList();
      final activity = ((results[4] as Map)['activity'] as List)
          .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
          .toList();
      final releases = ((results[5] as Map)['releases'] as List)
          .map((e) => Release.fromJson(e as Map<String, dynamic>))
          .toList();

      final latestFromDetail = _maxTimestamp([
        ...feedback.map((f) => f.createdAt),
        ...activity.map((a) => a.createdAt),
      ]);

      project = project.copyWith(
        feedback: feedback,
        structuredBugs: bugs,
        testPlan: testPlan,
        releases: releases,
        latestActivityAt: latestFromDetail ?? project.latestActivityAt,
      );
      _projectsById[id] = project;
      _activityByProject[id] = activity;
    } on ApiException catch (e) {
      _projectErrors[id] = e.message;
    } finally {
      _loadingProjects.remove(id);
      notifyListeners();
    }
  }

  Future<void> createProject({
    required String name,
    required String description,
    String? appLink,
    List<PlatformLink> platformLinks = const [],
    List<int>? logoBytes,
    String? logoFilename,
    String? logoContentType,
  }) async {
    final res = await _api.post('/v1/projects', {
      'name': name,
      'description': description,
      if (appLink != null && appLink.isNotEmpty) 'app_link': appLink,
      if (platformLinks.isNotEmpty)
        'platform_links': platformLinks.map((l) => l.toJson()).toList(),
    }) as Map<String, dynamic>;
    final project = Project.fromJson(res);

    if (logoBytes != null &&
        logoFilename != null &&
        logoContentType != null &&
        logoBytes.isNotEmpty) {
      final upload = await _api.uploadFile(
        '/v1/projects/${project.id}/media',
        bytes: logoBytes,
        filename: logoFilename,
        contentType: logoContentType,
      ) as Map<String, dynamic>;
      final logoUrl = upload['url'] as String?;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        await _api.patch('/v1/projects/${project.id}', {'logo_url': logoUrl});
      }
    }

    await loadProjects();
  }

  Future<void> addMember({
    required String projectId,
    required String name,
    required String email,
    required UserRole role,
  }) async {
    await _api.post('/v1/projects/$projectId/members', {
      'name': name,
      'email': email,
      'role': userRoleToString(role),
    });
    await loadProject(projectId);
  }

  Future<void> sendFeedback({
    required String projectId,
    required String content,
    String? title,
    String? device,
    String? appVersion,
    String? platform,
    List<Screenshot> screenshots = const [],
  }) async {
    await _api.post('/v1/projects/$projectId/feedback', {
      'body': content,
      if (title != null && title.isNotEmpty) 'title': title,
      if (device != null && device.isNotEmpty) 'device': device,
      if (appVersion != null && appVersion.isNotEmpty) 'app_version': appVersion,
      if (platform != null && platform.isNotEmpty) 'platform': platform,
      'screenshots': screenshots.map((s) => s.toJson()).toList(),
    });
    await loadProject(projectId);
  }

  /// Absolute URL for a server media path (e.g. "/media/…").
  String mediaUrl(String path) =>
      path.startsWith('http') ? path : '${_api.baseUrl}$path';

  /// Uploads one attachment and returns it as a [Screenshot] (with url and
  /// content type) ready to send with feedback.
  Future<Screenshot> uploadAttachment({
    required String projectId,
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final res = await _api.uploadFile(
      '/v1/projects/$projectId/media',
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    ) as Map<String, dynamic>;
    return Screenshot(
      label: res['label'] as String? ?? filename,
      hue: 200,
      url: res['url'] as String?,
      contentType: res['content_type'] as String? ?? contentType,
    );
  }

  StructuredBug? structuredBugForFeedback(String projectId, String feedbackId) {
    final project = projectById(projectId);
    if (project == null) return null;
    for (final bug in project.structuredBugs) {
      if (bug.feedbackId == feedbackId) return bug;
    }
    return null;
  }

  Future<void> structureFeedbackWithAi({
    required String projectId,
    required String feedbackId,
  }) async {
    await _api.post('/v1/projects/$projectId/feedback/$feedbackId/structure');
    await loadProject(projectId);
  }

  Future<void> confirmBug({
    required String projectId,
    required String bugId,
  }) async {
    await _api.post('/v1/projects/$projectId/bugs/$bugId/confirm');
    await loadProject(projectId);
  }

  Future<void> dismissBug({
    required String projectId,
    required String bugId,
  }) async {
    await _api.post('/v1/projects/$projectId/bugs/$bugId/dismiss');
    await loadProject(projectId);
  }

  Future<void> markBugAsFixed({
    required String projectId,
    required String bugId,
    String? note,
    String? releaseId,
  }) async {
    await _api.post('/v1/projects/$projectId/bugs/$bugId/fix', {
      if (note != null && note.isNotEmpty) 'note': note,
      if (releaseId != null && releaseId.isNotEmpty) 'release_id': releaseId,
    });
    await loadProject(projectId);
  }

  Future<void> updateBug({
    required String projectId,
    required StructuredBug bug,
  }) async {
    await _api.patch('/v1/projects/$projectId/bugs/${bug.id}', bug.toUpdateJson());
    await loadProject(projectId);
  }

  Future<void> markBugNeedsInfo({
    required String projectId,
    required String bugId,
    String? note,
  }) async {
    await _api.post('/v1/projects/$projectId/bugs/$bugId/needs-info', {
      if (note != null && note.isNotEmpty) 'note': note,
    });
    await loadProject(projectId);
  }

  Future<void> resumeBug({
    required String projectId,
    required String bugId,
  }) async {
    await _api.post('/v1/projects/$projectId/bugs/$bugId/resume');
    await loadProject(projectId);
  }

  Future<void> reopenBug({
    required String projectId,
    required String bugId,
  }) async {
    await _api.post('/v1/projects/$projectId/bugs/$bugId/reopen');
    await loadProject(projectId);
  }

  Future<void> addFeedbackComment({
    required String projectId,
    required String feedbackId,
    required String body,
  }) async {
    await _api.post(
      '/v1/projects/$projectId/feedback/$feedbackId/comments',
      {'body': body},
    );
    await loadProject(projectId);
  }

  Future<void> postRelease({
    required String projectId,
    required String version,
    String? notes,
  }) async {
    await _api.post('/v1/projects/$projectId/releases', {
      'version': version,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    await loadProject(projectId);
  }

  Future<void> addTestItem({
    required String projectId,
    required String title,
    String? details,
  }) async {
    await _api.post('/v1/projects/$projectId/test-items', {
      'title': title,
      if (details != null && details.isNotEmpty) 'details': details,
    });
    await loadProject(projectId);
  }

  Future<void> removeTestItem({
    required String projectId,
    required String itemId,
  }) async {
    await _api.delete('/v1/projects/$projectId/test-items/$itemId');
    await loadProject(projectId);
  }

  // --- Notifications ---
  Future<void> loadNotifications() async {
    try {
      final res = await _api.get('/v1/notifications') as Map<String, dynamic>;
      _notifications = (res['notifications'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } on ApiException {
      // Non-critical; leave existing list in place.
    }
  }

  Future<void> markNotificationsRead() async {
    final hasUnread = _notifications.any((n) => !n.read);
    if (!hasUnread) return;
    for (final n in _notifications) {
      n.read = true;
    }
    notifyListeners();
    try {
      await _api.post('/v1/notifications/read');
    } on ApiException {
      // Best-effort; UI already reflects read state.
    }
  }

  // --- Subscription ---
  Future<void> loadSubscription() async {
    final res = await _api.get('/v1/me/subscription') as Map<String, dynamic>;
    _subscription = Subscription.fromJson(res);
    notifyListeners();
  }

  Future<void> changePlan(SubscriptionPlan plan) async {
    final res = await _api.put('/v1/me/subscription', {
      'plan': plan.name,
    }) as Map<String, dynamic>;
    _subscription = Subscription.fromJson(res);
    if (!isPro && _currentUser?.emailNotifications == true) {
      _currentUser = _currentUser?.copyWith(emailNotifications: false);
    }
    notifyListeners();
  }

  Future<void> setEmailNotifications(bool enabled) async {
    final res = await _api.put('/v1/me/preferences', {
      'email_notifications': enabled,
    }) as Map<String, dynamic>;
    _currentUser = User.fromJson(res);
    notifyListeners();
  }

  /// Downloads a CSV export (Pro). [type] is `bugs` or `feedback`.
  Future<String> exportProject({
    required String projectId,
    required String type,
  }) async {
    return _api.downloadText('/v1/projects/$projectId/export?type=$type');
  }
}
