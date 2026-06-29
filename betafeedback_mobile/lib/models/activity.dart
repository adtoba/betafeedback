enum ActivityType { bugStructured, bugFixed, releaseShipped }

ActivityType activityTypeFromString(String value) => switch (value) {
      'bug_fixed' => ActivityType.bugFixed,
      'release_shipped' => ActivityType.releaseShipped,
      _ => ActivityType.bugStructured,
    };

/// A project-wide event recorded for everyone to see (bug structured, bug
/// fixed, or release shipped). Surfaced in the Activity log.
class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.projectId,
    required this.actorId,
    required this.actorName,
    required this.type,
    required this.subject,
    required this.createdAt,
    this.note,
  });

  final String id;
  final String projectId;
  final String actorId;
  final String actorName;
  final ActivityType type;
  final String subject;
  final DateTime createdAt;
  final String? note;

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        actorId: json['actor_id'] as String,
        actorName: json['actor_name'] as String? ?? 'Someone',
        type: activityTypeFromString(json['type'] as String),
        subject: json['subject'] as String? ?? '',
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
