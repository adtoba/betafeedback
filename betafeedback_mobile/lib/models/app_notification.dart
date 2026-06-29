enum NotificationKind { release }

NotificationKind notificationKindFromString(String value) => switch (value) {
      _ => NotificationKind.release,
    };

/// An in-app notification delivered to the signed-in user.
class AppNotification {
  AppNotification({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String projectId;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  bool read;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        kind: notificationKindFromString(json['kind'] as String? ?? 'release'),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
