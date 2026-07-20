class AppUser {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatar;

  AppUser({
    required this.id,
    required this.username,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.avatar,
  });

  String get displayName =>
      (firstName.isNotEmpty || lastName.isNotEmpty) ? '$firstName $lastName'.trim() : username;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      avatar: json['avatar'],
    );
  }
}
