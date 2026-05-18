class Prompt {
  final String id;
  final String? createdBy;
  final String title;
  final String? description;
  final String status; // 'active' | 'closed'
  final String? deadline;
  final String createdAt;

  const Prompt({
    required this.id,
    this.createdBy,
    required this.title,
    this.description,
    required this.status,
    this.deadline,
    required this.createdAt,
  });

  factory Prompt.fromJson(Map<String, dynamic> j) => Prompt(
        id: j['id'] as String,
        createdBy: j['created_by'] as String?,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: j['status'] as String? ?? 'active',
        deadline: j['deadline'] as String?,
        createdAt: j['created_at'] as String,
      );

  bool get isActive => status == 'active';
}
