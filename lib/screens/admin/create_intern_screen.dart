import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';

class CreateInternScreen extends StatefulWidget {
  const CreateInternScreen({super.key});

  @override
  State<CreateInternScreen> createState() => _CreateInternScreenState();
}

class _CreateInternScreenState extends State<CreateInternScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  // Account
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  // Profile
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _mentorCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppState>().api.createIntern({
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'full_name': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'id_number': _idNumberCtrl.text.trim(),
        'college': _collegeCtrl.text.trim(),
        'degree': _degreeCtrl.text.trim(),
        'skills': _skillsCtrl.text.trim(),
        'department': _departmentCtrl.text.trim(),
        'mentor': _mentorCtrl.text.trim(),
        if (_startDate != null) 'start_date': '${_startDate!.year}-${_startDate!.month.toString().padLeft(2,'0')}-${_startDate!.day.toString().padLeft(2,'0')}',
        if (_endDate != null) 'end_date': '${_endDate!.year}-${_endDate!.month.toString().padLeft(2,'0')}-${_endDate!.day.toString().padLeft(2,'0')}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_fullNameCtrl.text} added successfully!')));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl, {bool required = false, int maxLines = 1, TextInputType? keyboardType, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
          suffixIcon: ctrl == _passwordCtrl ? IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure = !_obscure)) : null,
        ),
        validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: value ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
          if (d != null) onPicked(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
          child: Text(value != null ? '${value.year}-${value.month.toString().padLeft(2,'0')}-${value.day.toString().padLeft(2,'0')}' : 'Tap to select', style: TextStyle(color: value != null ? null : Colors.grey)),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Intern')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Login Account'),
            _field('Username', _usernameCtrl, required: true),
            _field('Email', _emailCtrl, required: true, keyboardType: TextInputType.emailAddress),
            _field('Password', _passwordCtrl, required: true, obscure: _obscure),

            _section('Personal Info'),
            _field('Full Name', _fullNameCtrl, required: true),
            _field('Phone', _phoneCtrl, keyboardType: TextInputType.phone),
            _field('ID / Student Number', _idNumberCtrl),

            _section('Academic'),
            _field('College / University', _collegeCtrl),
            _field('Degree / Program', _degreeCtrl),
            _field('Skills (comma-separated)', _skillsCtrl, maxLines: 2),

            _section('Internship Details'),
            _field('Department', _departmentCtrl),
            _field('Mentor / Supervisor', _mentorCtrl),
            _datePicker('Start Date', _startDate, (d) => setState(() => _startDate = d)),
            _datePicker('End Date', _endDate, (d) => setState(() => _endDate = d)),

            if (_error != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _loading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Create Intern Account', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
