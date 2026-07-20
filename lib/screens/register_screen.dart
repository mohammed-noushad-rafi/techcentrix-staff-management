import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().register(
            _usernameCtrl.text.trim(),
            _emailCtrl.text.trim(),
            _passwordCtrl.text,
            _password2Ctrl.text,
          );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.isEmpty) ? 'Enter a username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.length < 8) ? 'Minimum 8 characters' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password2Ctrl,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
                      validator: (v) =>
                          v != _passwordCtrl.text ? 'Passwords do not match' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Sign Up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
