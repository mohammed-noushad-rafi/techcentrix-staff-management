import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_usernameCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your username and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppState>().login(_usernameCtrl.text.trim(), _passwordCtrl.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(children: [
        Container(
          height: size.height * 0.52,
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        ),
        Positioned(bottom: 0, left: 0, right: 0,
          child: Container(height: size.height * 0.55, color: const Color(0xFFF0F8FF))),
        SafeArea(child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(children: [
            SizedBox(
              height: size.height * 0.38,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 110, height: 110,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                RichText(text: const TextSpan(children: [
                  TextSpan(text: 'tech', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white70)),
                  TextSpan(text: 'Centrix', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFF7941D))),
                ])),
                const SizedBox(height: 4),
                const Text('Staff Management System',
                    style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 0.8)),
              ]),
            ),
            Expanded(child: SlideTransition(
              position: _slideAnim,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(width: 4, height: 24, decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 10),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Welcome back', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                      Text('Sign in to your account', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                    ]),
                  ]),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _usernameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      prefixIconColor: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      prefixIconColor: AppTheme.primary,
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20, color: Colors.grey.shade500),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppTheme.headerGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _loading ? null : _submit,
                        child: Center(child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _chip('Admin', Icons.admin_panel_settings_outlined),
                    const SizedBox(width: 8),
                    _chip('Employee', Icons.work_outline_rounded),
                    const SizedBox(width: 8),
                    _chip('Intern', Icons.school_outlined),
                  ]),
                ])),
              ),
            )),
          ]),
        )),
      ]),
    );
  }

  Widget _chip(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppTheme.primary),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
    ]),
  );
}
