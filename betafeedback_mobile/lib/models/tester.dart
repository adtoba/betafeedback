class TesterProfile {
  const TesterProfile({
    required this.id,
    required this.name,
    this.email = '',
    this.avatarHue,
    this.bio = '',
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.completedCount = 0,
    this.alreadyMember = false,
    this.invitePending = false,
  });

  final String id;
  final String name;
  final String email;
  final int? avatarHue;
  final String bio;
  final double ratingAvg;
  final int ratingCount;
  final int completedCount;
  final bool alreadyMember;
  final bool invitePending;

  bool get canInvite => !alreadyMember && !invitePending;

  String get ratingLabel {
    if (ratingCount == 0) return 'New tester';
    return '${ratingAvg.toStringAsFixed(1)} · $ratingCount '
        '${ratingCount == 1 ? "rating" : "ratings"}';
  }

  factory TesterProfile.fromJson(Map<String, dynamic> json) => TesterProfile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatarHue: (json['avatar_hue'] as num?)?.toInt(),
    bio: json['tester_bio'] as String? ?? '',
    ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0,
    ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
    completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
    alreadyMember: json['already_member'] as bool? ?? false,
    invitePending: json['invite_pending'] as bool? ?? false,
  );

  TesterProfile copyWith({
    bool? alreadyMember,
    bool? invitePending,
  }) {
    return TesterProfile(
      id: id,
      name: name,
      email: email,
      avatarHue: avatarHue,
      bio: bio,
      ratingAvg: ratingAvg,
      ratingCount: ratingCount,
      completedCount: completedCount,
      alreadyMember: alreadyMember ?? this.alreadyMember,
      invitePending: invitePending ?? this.invitePending,
    );
  }
}

enum TesterInviteStatus { pending, accepted, declined, cancelled }

TesterInviteStatus testerInviteStatusFromString(String? value) =>
    switch (value) {
      'accepted' => TesterInviteStatus.accepted,
      'declined' => TesterInviteStatus.declined,
      'cancelled' => TesterInviteStatus.cancelled,
      _ => TesterInviteStatus.pending,
    };

String testerInviteStatusLabel(TesterInviteStatus status) => switch (status) {
  TesterInviteStatus.pending => 'Pending',
  TesterInviteStatus.accepted => 'Accepted',
  TesterInviteStatus.declined => 'Declined',
  TesterInviteStatus.cancelled => 'Cancelled',
};

class TesterInvitation {
  const TesterInvitation({
    required this.id,
    required this.projectId,
    required this.projectName,
    this.projectDescription = '',
    this.projectLogoUrl,
    this.testerCount = 0,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.toUserName,
    this.message = '',
    this.status = TesterInviteStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  final String id;
  final String projectId;
  final String projectName;
  final String projectDescription;
  final String? projectLogoUrl;
  final int testerCount;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final String toUserName;
  final String message;
  final TesterInviteStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  bool get isPending => status == TesterInviteStatus.pending;

  factory TesterInvitation.fromJson(Map<String, dynamic> json) =>
      TesterInvitation(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        projectName: json['project_name'] as String? ?? '',
        projectDescription: json['project_description'] as String? ?? '',
        projectLogoUrl: json['project_logo_url'] as String?,
        testerCount: (json['tester_count'] as num?)?.toInt() ?? 0,
        fromUserId: json['from_user_id'] as String,
        fromUserName: json['from_user_name'] as String? ?? '',
        toUserId: json['to_user_id'] as String,
        toUserName: json['to_user_name'] as String? ?? '',
        message: json['message'] as String? ?? '',
        status: testerInviteStatusFromString(json['status'] as String?),
        createdAt: DateTime.parse(json['created_at'] as String),
        respondedAt: json['responded_at'] == null
            ? null
            : DateTime.parse(json['responded_at'] as String),
      );
}

class TesterRating {
  const TesterRating({
    required this.id,
    required this.projectId,
    this.projectName = '',
    required this.raterId,
    this.raterName = '',
    required this.testerId,
    required this.score,
    this.comment = '',
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String projectName;
  final String raterId;
  final String raterName;
  final String testerId;
  final int score;
  final String comment;
  final DateTime createdAt;

  factory TesterRating.fromJson(Map<String, dynamic> json) => TesterRating(
    id: json['id'] as String,
    projectId: json['project_id'] as String,
    projectName: json['project_name'] as String? ?? '',
    raterId: json['rater_id'] as String,
    raterName: json['rater_name'] as String? ?? '',
    testerId: json['tester_id'] as String,
    score: (json['score'] as num).toInt(),
    comment: json['comment'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
