enum FeedbackType { testerMessage, systemFixed, aiStructured }

enum BugStatus { suggested, open, needsInfo, fixed }

/// A feedback attachment. Real uploads carry a [url] and [contentType]; older
/// placeholders fall back to a [label] + [hue] styled thumbnail.
class Screenshot {
  const Screenshot({
    required this.label,
    required this.hue,
    this.url,
    this.contentType,
  });

  final String label;
  final int hue;

  /// Server path to the uploaded file, e.g. `/media/{project}/{id}.png`.
  final String? url;
  final String? contentType;

  bool get isVideo => contentType?.startsWith('video/') ?? false;
  bool get hasMedia => url != null && url!.isNotEmpty;

  factory Screenshot.fromJson(Map<String, dynamic> json) => Screenshot(
        label: json['label'] as String? ?? '',
        hue: (json['hue'] as num?)?.toInt() ?? 200,
        url: (json['url'] as String?)?.isEmpty ?? true
            ? null
            : json['url'] as String,
        contentType: (json['content_type'] as String?)?.isEmpty ?? true
            ? null
            : json['content_type'] as String,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'hue': hue,
        if (url != null) 'url': url,
        if (contentType != null) 'content_type': contentType,
      };
}

class FeedbackComment {
  const FeedbackComment({
    required this.id,
    required this.feedbackId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String feedbackId;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory FeedbackComment.fromJson(Map<String, dynamic> json) =>
      FeedbackComment(
        id: json['id'] as String,
        feedbackId: json['feedback_id'] as String,
        authorId: json['author_id'] as String,
        authorName: json['author_name'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class StructuredBug {
  const StructuredBug({
    required this.id,
    required this.feedbackId,
    required this.title,
    required this.stepsToReproduce,
    required this.expectedBehavior,
    required this.actualBehavior,
    required this.severity,
    required this.status,
    required this.structuredAt,
    this.fixedAt,
    this.reporterName,
    this.fixNote,
    this.fixedInReleaseId,
    this.fixedInReleaseVersion,
  });

  final String id;
  final String feedbackId;
  final String title;
  final List<String> stepsToReproduce;
  final String expectedBehavior;
  final String actualBehavior;
  final String severity;
  final BugStatus status;
  final DateTime structuredAt;
  final DateTime? fixedAt;
  final String? reporterName;
  final String? fixNote;
  final String? fixedInReleaseId;
  final String? fixedInReleaseVersion;

  factory StructuredBug.fromJson(Map<String, dynamic> json) {
    return StructuredBug(
      id: json['id'] as String,
      feedbackId: json['feedback_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      stepsToReproduce:
          (json['steps'] as List?)?.map((e) => e as String).toList() ?? [],
      expectedBehavior: json['expected'] as String? ?? '',
      actualBehavior: json['actual'] as String? ?? '',
      severity: json['severity'] as String? ?? 'Low',
      status: switch (json['status']) {
        'fixed' => BugStatus.fixed,
        'suggested' => BugStatus.suggested,
        'needs_info' => BugStatus.needsInfo,
        _ => BugStatus.open,
      },
      reporterName: json['reporter_name'] as String?,
      structuredAt: DateTime.parse(json['structured_at'] as String),
      fixedAt: json['fixed_at'] == null
          ? null
          : DateTime.parse(json['fixed_at'] as String),
      fixNote: json['fix_note'] as String?,
      fixedInReleaseId: json['fixed_in_release_id'] as String?,
      fixedInReleaseVersion: json['fixed_in_release_version'] as String?,
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        'title': title,
        'steps': stepsToReproduce,
        'expected': expectedBehavior,
        'actual': actualBehavior,
        'severity': severity,
      };
}

class FeedbackMessage {
  const FeedbackMessage({
    required this.id,
    required this.projectId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.type,
    this.title,
    this.device,
    this.appVersion,
    this.platform,
    this.screenshots = const [],
    this.structuredBugId,
    this.comments = const [],
  });

  final String id;
  final String projectId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final FeedbackType type;
  final String? title;
  final String? device;
  final String? appVersion;

  /// Platform id the tester selected (e.g. 'ios'), from the project's platforms.
  final String? platform;
  final List<Screenshot> screenshots;
  final String? structuredBugId;
  final List<FeedbackComment> comments;

  bool get hasTestDetails =>
      title != null ||
      device != null ||
      appVersion != null ||
      platform != null ||
      screenshots.isNotEmpty;

  factory FeedbackMessage.fromJson(Map<String, dynamic> json) {
    return FeedbackMessage(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? '',
      content: json['body'] as String? ?? '',
      title: json['title'] as String?,
      device: json['device'] as String?,
      appVersion: json['app_version'] as String?,
      platform: json['platform'] as String?,
      screenshots: (json['screenshots'] as List?)
              ?.map((e) => Screenshot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      comments: (json['comments'] as List?)
              ?.map((e) => FeedbackComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
      type: FeedbackType.testerMessage,
    );
  }
}
