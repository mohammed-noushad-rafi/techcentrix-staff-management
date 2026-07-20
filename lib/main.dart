import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/staff/staff_home.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const TechCentricApp());
}

class TechCentricApp extends StatelessWidget {
  const TechCentricApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'TechCentric',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checked = false;
  @override
  void initState() { super.initState(); _check(); }

  Future<void> _check() async {
    await context.read<AppState>().checkSession();
    setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SplashScreen();
    final state = context.watch<AppState>();
    if (!state.isLoggedIn) return const LoginScreen();
    if (state.isAdmin) return const AdminDashboard();
    return const StaffHome();
  }
}
