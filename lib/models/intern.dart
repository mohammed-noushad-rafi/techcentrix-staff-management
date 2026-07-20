class InternProfile {
  final int id;
  final int userId;
  final String username;
  final String email;

  // Identity
  final String fullName;
  final String phone;
  final String idNumber;
  final String? photoUrl;

  // Academic
  final String college;
  final String degree;
  final String skills;
  final List<String> skillsList;

  // Internship
  final String department;
  final String mentor;
  final String? startDate;
  final String? endDate;
  final String status; // active / inactive

  // Notes
  final String notes;

  // Stats
  final int taskCount;
  final int completedTaskCount;

  InternProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    this.phone = '',
    this.idNumber = '',
    this.photoUrl,
    this.college = '',
    this.degree = '',
    this.skills = '',
    this.skillsList = const [],
    this.department = '',
    this.mentor = '',
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.notes = '',
    this.taskCount = 0,
    this.completedTaskCount = 0,
  });

  bool get isActive => status == 'active';

  double get taskProgress =>
      taskCount == 0 ? 0 : completedTaskCount / taskCount;

  factory InternProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return InternProfile(
      id: json['id'] ?? 0,
      userId: user['id'] ?? 0,
      username: json['username'] ?? user['username'] ?? '',
      email: json['email'] ?? user['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      idNumber: json['id_number'] ?? '',
      photoUrl: json['photo'],
      college: json['college'] ?? '',
      degree: json['degree'] ?? '',
      skills: json['skills'] ?? '',
      skillsList: (json['skills_list'] as List? ?? []).cast<String>(),
      department: json['department'] ?? '',
      mentor: json['mentor'] ?? '',
      startDate: json['start_date'],
      endDate: json['end_date'],
      status: json['status'] ?? 'active',
      notes: json['notes'] ?? '',
      taskCount: json['task_count'] ?? 0,
      completedTaskCount: json['completed_task_count'] ?? 0,
    );
  }
}

class AppUserInfo {
  final int id;
  final String username;
  final String email;
  final String role;
  final InternProfile? internProfile;

  AppUserInfo({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.internProfile,
  });

  bool get isAdmin => role == 'admin';

  factory AppUserInfo.fromJson(Map<String, dynamic> json) {
    return AppUserInfo(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'intern',
      internProfile: json['intern_profile'] != null
          ? InternProfile.fromJson(json['intern_profile'])
          : null,
    );
  }
}
