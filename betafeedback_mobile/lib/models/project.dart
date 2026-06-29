import 'feedback.dart';
import 'release.dart';
import 'test_item.dart';
import 'user.dart';

/// A per-platform test/download link for a project's build, e.g.
/// `{platform: 'ios', url: 'https://testflight.apple.com/join/…'}`.
class PlatformLink {
  const PlatformLink({required this.platform, required this.url});

  final String platform;
  final String url;

  factory PlatformLink.fromJson(Map<String, dynamic> json) => PlatformLink(
        platform: json['platform'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'platform': platform, 'url': url};
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.inviteCode,
    required this.inviteLink,
    required this.createdAt,
    this.creatorName = '',
    this.appLink,
    this.logoUrl,
    this.platformLinks = const [],
    this.members = const [],
    this.feedback = const [],
    this.structuredBugs = const [],
    this.testPlan = const [],
    this.releases = const [],
    this.testerCount = 0,
    this.memberCount = 0,
    this.latestFeedbackAt,
    this.latestActivityAt,
  });

  final String id;
  final String name;
  final String description;
  final String creatorId;
  final String creatorName;
  final String inviteCode;

  /// Shareable join URL, provided by the backend (falls back to a computed URL
  /// only when the server omits it).
  final String inviteLink;
  final String? appLink;

  /// Server path to the project logo (e.g. `/media/{projectId}/…`).
  final String? logoUrl;

  /// Per-platform test links the creator added (iOS, Android, Web, …).
  final List<PlatformLink> platformLinks;
  final DateTime createdAt;

  /// Populated on detail loads; empty for list summaries.
  final List<User> members;
  final List<FeedbackMessage> feedback;
  final List<StructuredBug> structuredBugs;
  final List<TestItem> testPlan;
  final List<Release> releases;

  /// Summary counts (available even when [members] is empty).
  final int testerCount;
  final int memberCount;
  final DateTime? latestFeedbackAt;

  /// Most recent feedback or activity-log event (list summaries from the API).
  final DateTime? latestActivityAt;

  List<String> get testerIds => members
      .where((m) => m.role == UserRole.tester)
      .map((m) => m.id)
      .toList();

  List<String> get developerIds => members
      .where((m) => m.role == UserRole.developer)
      .map((m) => m.id)
      .toList();

  List<String> get allMemberIds => members.map((m) => m.id).toList();

  factory Project.fromJson(Map<String, dynamic> json) {
    final members = (json['members'] as List?)
            ?.map((e) => User.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const <User>[];
    final inviteCode = json['invite_code'] as String? ?? '';
    final inviteLink = (json['invite_link'] as String?)?.isNotEmpty == true
        ? json['invite_link'] as String
        : 'https://betafeedback.com/join/$inviteCode';
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      creatorId: json['creator_id'] as String,
      creatorName: json['creator_name'] as String? ?? '',
      inviteCode: inviteCode,
      inviteLink: inviteLink,
      appLink: json['app_link'] as String?,
      logoUrl: json['logo_url'] as String?,
      platformLinks: (json['platform_links'] as List?)
              ?.map((e) => PlatformLink.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <PlatformLink>[],
      createdAt: DateTime.parse(json['created_at'] as String),
      members: members,
      testerCount: (json['tester_count'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? members.length,
      latestFeedbackAt: json['latest_feedback_at'] == null
          ? null
          : DateTime.parse(json['latest_feedback_at'] as String),
      latestActivityAt: json['latest_activity_at'] == null
          ? null
          : DateTime.parse(json['latest_activity_at'] as String),
    );
  }

  Project copyWith({
    List<User>? members,
    List<FeedbackMessage>? feedback,
    List<StructuredBug>? structuredBugs,
    List<TestItem>? testPlan,
    List<Release>? releases,
    int? testerCount,
    int? memberCount,
    DateTime? latestFeedbackAt,
    DateTime? latestActivityAt,
  }) {
    return Project(
      id: id,
      name: name,
      description: description,
      creatorId: creatorId,
      creatorName: creatorName,
      inviteCode: inviteCode,
      inviteLink: inviteLink,
      appLink: appLink,
      logoUrl: logoUrl,
      platformLinks: platformLinks,
      createdAt: createdAt,
      members: members ?? this.members,
      feedback: feedback ?? this.feedback,
      structuredBugs: structuredBugs ?? this.structuredBugs,
      testPlan: testPlan ?? this.testPlan,
      releases: releases ?? this.releases,
      testerCount: testerCount ?? this.testerCount,
      memberCount: memberCount ?? this.memberCount,
      latestFeedbackAt: latestFeedbackAt ?? this.latestFeedbackAt,
      latestActivityAt: latestActivityAt ?? this.latestActivityAt,
    );
  }
}
