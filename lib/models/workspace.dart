class Workspace {
  final int id;
  final String name;
  final String description;
  final String inviteCode;
  final int memberCount;

  Workspace({
    required this.id,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.memberCount,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      inviteCode: json['invite_code'] ?? '',
      memberCount: json['member_count'] ?? 0,
    );
  }
}
