/// A single thing the creator wants testers to check, shown in the project's
/// "What to test" plan.
class TestItem {
  const TestItem({
    required this.id,
    required this.title,
    required this.createdAt,
    this.details,
  });

  final String id;
  final String title;
  final String? details;
  final DateTime createdAt;

  factory TestItem.fromJson(Map<String, dynamic> json) => TestItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        details: json['details'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
