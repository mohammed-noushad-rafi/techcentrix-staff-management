import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000/api';
  final _storage = const FlutterSecureStorage();

  Future<String?> get accessToken => _storage.read(key: 'access_token');
  Future<String?> get refreshToken => _storage.read(key: 'refresh_token');

  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> logout() async => await _storage.deleteAll();
  Future<bool> isLoggedIn() async => (await accessToken) != null;

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await accessToken;
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    var res = await request();
    if (res.statusCode == 401) {
      if (await _tryRefresh()) res = await request();
    }
    return res;
  }

  Future<bool> _tryRefresh() async {
    final refresh = await refreshToken;
    if (refresh == null) return false;
    final res = await http.post(Uri.parse('$baseUrl/auth/login/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}));
    if (res.statusCode == 200) {
      await _storage.write(key: 'access_token', value: jsonDecode(res.body)['access']);
      return true;
    }
    return false;
  }

  // ─── AUTH ────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(Uri.parse('$baseUrl/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) { await _saveTokens(data['access'], data['refresh']); return data; }
    throw ApiException(_extractError(data));
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/auth/me/'), headers: await _headers()));
    return _decode(res);
  }

  // ─── ADMIN DASHBOARD ─────────────────────────────────
  Future<Map<String, dynamic>> getAdminDashboard() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/admin/dashboard/'), headers: await _headers()));
    return _decode(res);
  }

  // ─── STAFF ───────────────────────────────────────────
  Future<List<dynamic>> getStaff({String? role, String? department, String? status, String? search, String? experienceType}) async {
    final q = <String, String>{};
    if (role != null) q['role'] = role;
    if (department != null && department.isNotEmpty) q['department'] = department;
    if (status != null) q['status'] = status;
    if (search != null && search.isNotEmpty) q['search'] = search;
    if (experienceType != null) q['experience_type'] = experienceType;
    final uri = Uri.parse('$baseUrl/staff/').replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStaffMember(int id) async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/staff/$id/'), headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> data) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/staff/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateStaff(int id, Map<String, dynamic> data) async {
    final res = await _send(() async => http.patch(Uri.parse('$baseUrl/staff/$id/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<void> deleteStaff(int id) async {
    await _send(() async => http.delete(Uri.parse('$baseUrl/staff/$id/'), headers: await _headers()));
  }

  Future<Map<String, dynamic>> toggleStaffStatus(int id) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/staff/$id/toggle_status/'), headers: await _headers()));
    return _decode(res);
  }

  Future<void> resetStaffPassword(int id, String password) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/staff/$id/reset_password/'),
        headers: await _headers(), body: jsonEncode({'password': password})));
    _decode(res);
  }

  Future<List<dynamic>> getStaffTasks(int staffId) async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/staff/$staffId/tasks/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> uploadStaffPhoto(int staffId, String filePath) async {
    final token = await accessToken;
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/staff/$staffId/upload_photo/'));
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('photo', filePath));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  // ─── STAFF SEARCH ────────────────────────────────────
  Future<List<dynamic>> searchStaff({String? role, String? department, String? skills, String? experienceType, String? search}) async {
    final q = <String, String>{};
    if (role != null) q['role'] = role;
    if (department != null && department.isNotEmpty) q['department'] = department;
    if (skills != null && skills.isNotEmpty) q['skills'] = skills;
    if (experienceType != null) q['experience_type'] = experienceType;
    if (search != null && search.isNotEmpty) q['search'] = search;
    final uri = Uri.parse('$baseUrl/staff-search/').replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  // ─── TEAMS ───────────────────────────────────────────
  Future<List<dynamic>> getTeams() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/teams/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTeam(Map<String, dynamic> data) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/teams/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateTeam(int id, Map<String, dynamic> data) async {
    final res = await _send(() async => http.patch(Uri.parse('$baseUrl/teams/$id/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<void> deleteTeam(int id) async {
    await _send(() async => http.delete(Uri.parse('$baseUrl/teams/$id/'), headers: await _headers()));
  }

  Future<Map<String, dynamic>> addTeamMember(int teamId, int userId) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/teams/$teamId/add_member/'),
        headers: await _headers(), body: jsonEncode({'user_id': userId})));
    return _decode(res);
  }

  Future<Map<String, dynamic>> removeTeamMember(int teamId, int userId) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/teams/$teamId/remove_member/'),
        headers: await _headers(), body: jsonEncode({'user_id': userId})));
    return _decode(res);
  }

  Future<List<dynamic>> getTeamTasks(int teamId) async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/teams/$teamId/tasks/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  // ─── TASKS ───────────────────────────────────────────
  Future<List<dynamic>> getTasks({int? boardId, int? assigneeId, String? status}) async {
    final q = <String, String>{};
    if (boardId != null) q['board'] = boardId.toString();
    if (assigneeId != null) q['assignee'] = assigneeId.toString();
    if (status != null) q['status'] = status;
    final uri = Uri.parse('$baseUrl/tasks/').replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/tasks/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateTask(int id, Map<String, dynamic> data) async {
    final res = await _send(() async => http.patch(Uri.parse('$baseUrl/tasks/$id/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<void> deleteTask(int id) async {
    await _send(() async => http.delete(Uri.parse('$baseUrl/tasks/$id/'), headers: await _headers()));
  }

  Future<Map<String, dynamic>> verifyTask(int taskId) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/tasks/$taskId/verify/'), headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> reassignTask(int taskId, int assigneeId) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/tasks/$taskId/reassign/'),
        headers: await _headers(), body: jsonEncode({'assignee_id': assigneeId})));
    return _decode(res);
  }

  Future<List<dynamic>> getMyTasks() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/my-tasks/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<List<dynamic>> getMyTeams() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/my-teams/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> submitTask(int taskId) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/tasks/$taskId/submit/'), headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> moveTask(int taskId, int columnId, int order) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/tasks/$taskId/move/'),
        headers: await _headers(), body: jsonEncode({'column': columnId, 'order': order})));
    return _decode(res);
  }

  // ─── SUBTASKS ────────────────────────────────────────
  Future<List<dynamic>> getSubtasks(int taskId) async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/tasks/$taskId/subtasks/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSubtask(int taskId, String title) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/tasks/$taskId/subtasks/'),
        headers: await _headers(), body: jsonEncode({'title': title})));
    return _decode(res);
  }

  Future<Map<String, dynamic>> toggleSubtask(int subtaskId, bool isDone) async {
    final res = await _send(() async => http.patch(Uri.parse('$baseUrl/tasks/subtasks/$subtaskId/'),
        headers: await _headers(), body: jsonEncode({'is_done': isDone})));
    return _decode(res);
  }

  // ─── COMMENTS ────────────────────────────────────────
  Future<List<dynamic>> getComments(int taskId) async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/tasks/$taskId/comments/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> addComment(int taskId, String body) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/tasks/$taskId/comments/'),
        headers: await _headers(), body: jsonEncode({'body': body})));
    return _decode(res);
  }

  // ─── NOTIFICATIONS ───────────────────────────────────
  Future<List<dynamic>> getNotifications() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/tasks/notifications/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<void> markNotificationRead(int id) async {
    await _send(() async => http.post(Uri.parse('$baseUrl/tasks/notifications/$id/read/'), headers: await _headers()));
  }

  Future<void> markAllNotificationsRead() async {
    await _send(() async => http.post(Uri.parse('$baseUrl/tasks/notifications/read_all/'), headers: await _headers()));
  }

  // ─── BOARDS ──────────────────────────────────────────
  Future<List<dynamic>> getBoards() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/boards/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getBoard(int id) async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/boards/$id/'), headers: await _headers()));
    return _decode(res);
  }

  Future<List<dynamic>> getWorkspaces() async {
    final res = await _send(() async => http.get(Uri.parse('$baseUrl/workspaces/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createBoard(int workspaceId, String name) async {
    final res = await _send(() async => http.post(Uri.parse('$baseUrl/boards/'),
        headers: await _headers(), body: jsonEncode({'workspace': workspaceId, 'name': name, 'description': ''})));
    return _decode(res);
  }

  // ─── ATTENDANCE ──────────────────────────────────────
  Future<Map<String, dynamic>> checkIn(double lat, double lng) async {
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/check-in/'),
        headers: await _headers(),
        body: jsonEncode({'lat': lat, 'lng': lng})));
    return _decode(res);
  }

  Future<Map<String, dynamic>> checkOut(double lat, double lng) async {
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/check-out/'),
        headers: await _headers(),
        body: jsonEncode({'lat': lat, 'lng': lng})));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getMyAttendance({int? month, int? year}) async {
    final q = <String, String>{};
    if (month != null) q['month'] = month.toString();
    if (year != null) q['year'] = year.toString();
    final uri = Uri.parse('$baseUrl/attendance/my/').replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> checkNearby(double lat, double lng) async {
    final uri = Uri.parse('$baseUrl/attendance/nearby/')
        .replace(queryParameters: {'lat': lat.toString(), 'lng': lng.toString()});
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getAdminToday() async {
    final res = await _send(() async => http.get(
        Uri.parse('$baseUrl/attendance/admin/today/'), headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getAdminStaffAttendance(int userId, {int? month, int? year}) async {
    final q = <String, String>{};
    if (month != null) q['month'] = month.toString();
    if (year != null) q['year'] = year.toString();
    final uri = Uri.parse('$baseUrl/attendance/admin/staff/$userId/')
        .replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> adminOverrideAttendance(int userId, String date, String status, {String notes = ''}) async {
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/admin/override/'),
        headers: await _headers(),
        body: jsonEncode({'user_id': userId, 'date': date, 'status': status, 'notes': notes})));
    return _decode(res);
  }

  Future<List<dynamic>> getOfficeLocations() async {
    final res = await _send(() async => http.get(
        Uri.parse('$baseUrl/attendance/office-locations/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createOfficeLocation(Map<String, dynamic> data) async {
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/office-locations/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<Map<String, dynamic>> updateOfficeLocation(int id, Map<String, dynamic> data) async {
    final res = await _send(() async => http.patch(
        Uri.parse('$baseUrl/attendance/office-locations/$id/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<void> deleteOfficeLocation(int id) async {
    await _send(() async => http.delete(
        Uri.parse('$baseUrl/attendance/office-locations/$id/'), headers: await _headers()));
  }

  Future<List<dynamic>> getMyLeaves() async {
    final res = await _send(() async => http.get(
        Uri.parse('$baseUrl/attendance/leaves/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> applyLeave(Map<String, dynamic> data) async {
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/leaves/'),
        headers: await _headers(), body: jsonEncode(data)));
    return _decode(res);
  }

  Future<List<dynamic>> getPendingLeaves() async {
    final res = await _send(() async => http.get(
        Uri.parse('$baseUrl/attendance/admin/leaves/pending/'), headers: await _headers()));
    return _decode(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> approveLeave(int id, {String note = ''}) async {
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/leaves/$id/approve/'),
        headers: await _headers(), body: jsonEncode({'note': note})));
    return _decode(res);
  }

  Future<Map<String, dynamic>> rejectLeave(int id, {String note = ''}) async {
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/leaves/$id/reject/'),
        headers: await _headers(), body: jsonEncode({'note': note})));
    return _decode(res);
  }

  // ─── HELPERS ─────────────────────────────────────────
  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    final data = res.body.isNotEmpty ? jsonDecode(res.body) : {};
    throw ApiException(_extractError(data));
  }

  String _extractError(dynamic data) {
    if (data is Map) {
      if (data['detail'] != null) return data['detail'].toString();
      final k = data.keys.isNotEmpty ? data.keys.first : null;
      if (k != null) { final v = data[k]; return v is List ? '$k: ${v.first}' : '$k: $v'; }
    }
    return 'Something went wrong. Please try again.';
  }
  Future<Map<String, dynamic>> markAbsentNow({String? date}) async {
    final body = date != null ? {'date': date} : <String, dynamic>{};
    final res = await _send(() async => http.post(
        Uri.parse('$baseUrl/attendance/admin/mark-absent/'),
        headers: await _headers(),
        body: jsonEncode(body)));
    return _decode(res);
  }
  Future<Map<String, dynamic>> getAttendanceReport({int? staffId, String? fromDate, String? toDate}) async {
    final q = <String, String>{};
    if (staffId != null) q['staff_id'] = staffId.toString();
    if (fromDate != null) q['from_date'] = fromDate;
    if (toDate != null) q['to_date'] = toDate;
    final uri = Uri.parse('$baseUrl/attendance/reports/').replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res);
  }

  Future<Map<String, dynamic>> getAttendanceReportAll({String? fromDate, String? toDate}) async {
    final q = <String, String>{};
    if (fromDate != null) q['from_date'] = fromDate;
    if (toDate != null) q['to_date'] = toDate;
    final uri = Uri.parse('$baseUrl/attendance/reports/all/').replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers()));
    return _decode(res);
  }

  Future<void> downloadAttendanceReportPDF({int? staffId, String? fromDate, String? toDate}) async {
    final q = <String, String>{};
    if (staffId != null) q['staff_id'] = staffId.toString();
    if (fromDate != null) q['from_date'] = fromDate;
    if (toDate != null) q['to_date'] = toDate;
    final uri = Uri.parse('$baseUrl/attendance/reports/pdf/').replace(queryParameters: q.isEmpty ? null : q);
    final res = await _send(() async => http.get(uri, headers: await _headers(json: false)));
    if (res.statusCode != 200) throw ApiException('Failed to generate PDF');
    // PDF bytes available in res.bodyBytes — open via platform channel or share
  }

  Future<List<dynamic>> getMyTeamTasks() async {
    final res = await _send(() async => http.get(
        Uri.parse('$baseUrl/my-team-tasks/'), headers: await _headers()));
    final data = _decode(res);
    return data is List ? data : [];
  }

}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
