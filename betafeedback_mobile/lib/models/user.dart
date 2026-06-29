enum UserRole { creator, tester, developer }

UserRole? userRoleFromString(String? value) => switch (value) {
      'creator' => UserRole.creator,
      'tester' => UserRole.tester,
      'developer' => UserRole.developer,
      _ => null,
    };

String userRoleToString(UserRole role) => switch (role) {
      UserRole.creator => 'creator',
      UserRole.tester => 'tester',
      UserRole.developer => 'developer',
    };

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.avatarColor,
    this.emailNotifications = false,
  });

  final String id;
  final String name;
  final String email;

  /// Role within a specific project. Null for the signed-in user viewed
  /// outside any project context (roles are per-project on the backend).
  final UserRole? role;
  final int? avatarColor;
  final bool emailNotifications;

  String get roleLabel => switch (role) {
        UserRole.creator => 'Creator',
        UserRole.tester => 'Tester',
        UserRole.developer => 'Developer',
        null => 'Member',
      };

  /// Parses either a `/me`-style user (`id`) or a project member (`user_id`,
  /// `role`).
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['user_id']) as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: userRoleFromString(json['role'] as String?),
      avatarColor: (json['avatar_hue'] as num?)?.toInt(),
      emailNotifications: json['email_notifications'] as bool? ?? false,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    int? avatarColor,
    bool? emailNotifications,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      avatarColor: avatarColor ?? this.avatarColor,
      emailNotifications: emailNotifications ?? this.emailNotifications,
    );
  }
}
