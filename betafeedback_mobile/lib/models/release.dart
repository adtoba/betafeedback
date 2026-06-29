class Release {
  const Release({
    required this.id,
    required this.projectId,
    required this.version,
    required this.postedBy,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String projectId;
  final String version;
  final String? notes;
  final String postedBy;
  final DateTime createdAt;

  factory Release.fromJson(Map<String, dynamic> json) => Release(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        version: json['version'] as String? ?? '',
        notes: json['notes'] as String?,
        postedBy: json['posted_by'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
