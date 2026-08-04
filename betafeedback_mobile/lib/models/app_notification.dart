enum NotificationKind {
  release,
  testerInvite,
  memberInvite,
  swapInvite,
  feedback,
  bug,
  other,
}

NotificationKind notificationKindFromString(String value) => switch (value) {
  'tester_invite' => NotificationKind.testerInvite,
  'member_invite' => NotificationKind.memberInvite,
  'swap_invite' => NotificationKind.swapInvite,
  'feedback' => NotificationKind.feedback,
  'bug' => NotificationKind.bug,
  'release' => NotificationKind.release,
  _ => NotificationKind.other,
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
