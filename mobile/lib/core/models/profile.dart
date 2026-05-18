class Profile {
  final String id;
  final String fullName;
  final String role; // 'analyst' | 'pm'

  const Profile({required this.id, required this.fullName, required this.role});

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        fullName: j['full_name'] as String? ?? '',
        role: j['role'] as String? ?? 'analyst',
      );

  bool get isPM => role == 'pm';
}
