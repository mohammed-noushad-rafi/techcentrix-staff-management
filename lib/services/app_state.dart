import 'package:flutter/foundation.dart';
import '../models/staff.dart';
import 'api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService api = ApiService();
  bool isLoggedIn = false;
  AppUserInfo? currentUser;

  bool get isAdmin => currentUser?.isAdmin ?? false;
  bool get isIntern => currentUser?.isIntern ?? false;
  bool get isEmployee => currentUser?.isEmployee ?? false;
  String get displayName => currentUser?.staffProfile?.fullName.isNotEmpty == true
      ? currentUser!.staffProfile!.fullName
      : currentUser?.username ?? '';
  String get role => currentUser?.role ?? '';

  Future<void> checkSession() async {
    isLoggedIn = await api.isLoggedIn();
    if (isLoggedIn) {
      try {
        final data = await api.me();
        currentUser = AppUserInfo.fromJson(data);
      } catch (_) {
        isLoggedIn = false;
      }
    }
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final data = await api.login(username, password);
    currentUser = AppUserInfo.fromJson(data['user']);
    isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    isLoggedIn = false;
    currentUser = null;
    notifyListeners();
  }
}
