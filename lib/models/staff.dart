class StaffProfile {
  final int id;
  final int userId;
  final String username;
  final String email;
  final String role; // intern / employee

  // Identity
  final String fullName;
  final String phone;
  final String idNumber;
  final String? photoUrl;

  // Academic (intern)
  final String college;
  final String degree;

  // Professional (employee)
  final String jobRole;
  final String experienceType; // fresher / experienced
  final int? yearsOfExperience;

  // Common
  final String department;
  final String skills;
  final List<String> skillsList;
  final String mentor;
  final String? startDate;
  final String? endDate;
  final String status;
  final String notes;

  // Stats
  final int taskCount;
  final int completedTaskCount;
  final int pendingVerificationCount;

  StaffProfile({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.fullName,
    this.phone = '',
    this.idNumber = '',
    this.photoUrl,
    this.college = '',
    this.degree = '',
    this.jobRole = '',
    this.experienceType = '',
    this.yearsOfExperience,
    this.department = '',
    this.skills = '',
    this.skillsList = const [],
    this.mentor = '',
    this.startDate,
    this.endDate,
    this.status = 'active',
    this.notes = '',
    this.taskCount = 0,
    this.completedTaskCount = 0,
    this.pendingVerificationCount = 0,
  });

  bool get isActive => status == 'active';
  bool get isIntern => role == 'intern';
  bool get isEmployee => role == 'employee';
  double get taskProgress => taskCount == 0 ? 0 : completedTaskCount / taskCount;

  factory StaffProfile.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    return StaffProfile(
      id: json['id'] ?? 0,
      userId: user['id'] ?? 0,
      username: json['username'] ?? user['username'] ?? '',
      email: json['email'] ?? user['email'] ?? '',
      role: json['role'] ?? user['role'] ?? 'intern',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      idNumber: json['id_number'] ?? '',
      photoUrl: json['photo'],
      college: json['college'] ?? '',
      degree: json['degree'] ?? '',
      jobRole: json['job_role'] ?? '',
      experienceType: json['experience_type'] ?? '',
      yearsOfExperience: json['years_of_experience'],
      department: json['department'] ?? '',
      skills: json['skills'] ?? '',
      skillsList: (json['skills_list'] as List? ?? []).cast<String>(),
      mentor: json['mentor'] ?? '',
      startDate: json['start_date'],
      endDate: json['end_date'],
      status: json['status'] ?? 'active',
      notes: json['notes'] ?? '',
      taskCount: json['task_count'] ?? 0,
      completedTaskCount: json['completed_task_count'] ?? 0,
      pendingVerificationCount: json['pending_verification_count'] ?? 0,
    );
  }
}

class Team {
  final int id;
  final String name;
  final String description;
  final String department;
  final int memberCount;
  final List<dynamic> members;

  Team({
    required this.id,
    required this.name,
    this.description = '',
    this.department = '',
    this.memberCount = 0,
    this.members = const [],
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      department: json['department'] ?? '',
      memberCount: json['member_count'] ?? 0,
      members: json['members'] as List? ?? [],
    );
  }
}

class AppUserInfo {
  final int id;
  final String username;
  final String email;
  final String role;
  final StaffProfile? staffProfile;

  AppUserInfo({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.staffProfile,
  });

  bool get isAdmin => role == 'admin';
  bool get isIntern => role == 'intern';
  bool get isEmployee => role == 'employee';

  factory AppUserInfo.fromJson(Map<String, dynamic> json) {
    return AppUserInfo(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'intern',
      staffProfile: json['staff_profile'] != null
          ? StaffProfile.fromJson(json['staff_profile'])
          : null,
    );
  }
}
