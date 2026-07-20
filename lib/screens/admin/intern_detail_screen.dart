import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/intern.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';

class InternDetailScreen extends StatefulWidget {
  final int internId;
  const InternDetailScreen({super.key, required this.internId});

  @override
  State<InternDetailScreen> createState() => _InternDetailScreenState();
}

class _InternDetailScreenState extends State<InternDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  InternProfile? _intern;
  List<TaskItem> _tasks = [];
  bool _loading = true;
  bool _saving = false;

  // Form controllers
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idNumberCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _mentorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AppState>().api;
    final data = await api.getIntern(widget.internId);
    final taskData = await api.getInternTasks(widget.internId);
    final intern = InternProfile.fromJson(data);
    _fillForm(intern);
    setState(() {
      _intern = intern;
      _tasks = taskData.map((t) => TaskItem.fromJson(t)).toList();
      _loading = false;
    });
  }

  void _fillForm(InternProfile p) {
    _fullNameCtrl.text = p.fullName;
    _phoneCtrl.text = p.phone;
    _idNumberCtrl.text = p.idNumber;
    _collegeCtrl.text = p.college;
    _degreeCtrl.text = p.degree;
    _skillsCtrl.text = p.skills;
    _departmentCtrl.text = p.department;
    _mentorCtrl.text = p.mentor;
    _notesCtrl.text = p.notes;
    _startDate = p.startDate != null ? DateTime.tryParse(p.startDate!) : null;
    _endDate = p.endDate != null ? DateTime.tryParse(p.endDate!) : null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().api.updateIntern(widget.internId, {
        'full_name': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'id_number': _idNumberCtrl.text.trim(),
        'college': _collegeCtrl.text.trim(),
        'degree': _degreeCtrl.text.trim(),
        'skills': _skillsCtrl.text.trim(),
        'department': _departmentCtrl.text.trim(),
        'mentor': _mentorCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        if (_startDate != null) 'start_date': _startDate!.toIso8601String().split('T').first,
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T').first,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
        _load();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle() async {
    await context.read<AppState>().api.toggleInternStatus(widget.internId);
    _load();
  }

  Future<void> _resetPassword() async {
    final pwCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(controller: pwCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 6 chars)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true && pwCtrl.text.length >= 6) {
      await context.read<AppState>().api.resetInternPassword(widget.internId, pwCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    await context.read<AppState>().api.uploadInternPhoto(widget.internId, picked.path);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final intern = _intern!;
    return Scaffold(
      appBar: AppBar(
        title: Text(intern.fullName),
        actions: [
          IconButton(icon: const Icon(Icons.lock_reset), tooltip: 'Reset password', onPressed: _resetPassword),
          TextButton(
            onPressed: _toggle,
            child: Text(intern.isActive ? 'Deactivate' : 'Activate',
                style: TextStyle(color: intern.isActive ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Profile'), Tab(text: 'Tasks'), Tab(text: 'Account')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _profileTab(intern),
          _tasksTab(),
          _accountTab(intern),
        ],
      ),
    );
  }

  Widget _profileTab(InternProfile intern) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo + status banner
          Center(
            child: Stack(
              children: [
                intern.photoUrl != null && intern.photoUrl!.isNotEmpty
                    ? CircleAvatar(radius: 52, backgroundImage: NetworkImage(intern.photoUrl!))
                    : CircleAvatar(
                        radius: 52,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Text(intern.fullName.isNotEmpty ? intern.fullName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                      ),
                Positioned(
                  bottom: 0, right: 0,
                  child: InkWell(
                    onTap: _pickPhoto,
                    child: const CircleAvatar(radius: 16, backgroundColor: Colors.indigo, child: Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: intern.isActive ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: intern.isActive ? Colors.green : Colors.orange),
              ),
              child: Text(intern.isActive ? '● Active' : '○ Inactive',
                  style: TextStyle(color: intern.isActive ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),

          _sectionHeader('Personal Info'),
          _field('Full Name', _fullNameCtrl),
          _field('Phone', _phoneCtrl, keyboardType: TextInputType.phone),
          _field('ID / Student Number', _idNumberCtrl),

          const SizedBox(height: 12),
          _sectionHeader('Academic'),
          _field('College / University', _collegeCtrl),
          _field('Degree / Program', _degreeCtrl),
          _field('Skills (comma-separated)', _skillsCtrl, maxLines: 2),

          const SizedBox(height: 12),
          _sectionHeader('Internship Details'),
          _field('Department', _departmentCtrl),
          _field('Mentor / Supervisor', _mentorCtrl),
          _datePicker('Start Date', _startDate, (d) => setState(() => _startDate = d)),
          _datePicker('End Date', _endDate, (d) => setState(() => _endDate = d)),

          const SizedBox(height: 12),
          _sectionHeader('Admin Notes'),
          _field('Notes (internal)', _notesCtrl, maxLines: 4),

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Profile'),
          ),
        ],
      ),
    );
  }

  Widget _tasksTab() {
    if (_tasks.isEmpty) {
      return const Center(child: Text('No tasks assigned yet.'));
    }
    // Group by column name
    final byCol = <String, List<TaskItem>>{};
    for (final t in _tasks) {
      byCol.putIfAbsent(t.columnName, () => []).add(t);
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Progress bar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_intern!.completedTaskCount}/${_intern!.taskCount} completed'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _intern!.taskProgress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...byCol.entries.map((entry) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            ),
            ...entry.value.map((t) => Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                leading: Icon(_priorityIcon(t.priority), color: _priorityColor(t.priority), size: 20),
                title: Text(t.title, style: TextStyle(decoration: t.isCompleted ? TextDecoration.lineThrough : null)),
                subtitle: t.dueDate != null ? Text('Due: ${t.dueDate}', style: const TextStyle(fontSize: 11)) : null,
                trailing: t.isCompleted ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null,
              ),
            )),
          ],
        )),
      ],
    );
  }

  Widget _accountTab(InternProfile intern) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoTile('Username', intern.username, Icons.person_outline),
        _infoTile('Email', intern.email, Icons.email_outlined),
        _infoTile('Account ID', '#${intern.userId}', Icons.badge_outlined),
        _infoTile('Status', intern.isActive ? 'Active' : 'Inactive', Icons.circle, color: intern.isActive ? Colors.green : Colors.orange),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _resetPassword,
          icon: const Icon(Icons.lock_reset),
          label: const Text('Reset Password'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _toggle,
          icon: Icon(intern.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
          label: Text(intern.isActive ? 'Deactivate Account' : 'Activate Account'),
          style: FilledButton.styleFrom(
            backgroundColor: intern.isActive ? Colors.orange : Colors.green,
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (d != null) onPicked(d);
        },
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
          child: Text(value != null ? '${value.year}-${value.month.toString().padLeft(2,'0')}-${value.day.toString().padLeft(2,'0')}' : 'Not set', style: TextStyle(color: value != null ? null : Colors.grey)),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  IconData _priorityIcon(String p) {
    switch (p) { case 'urgent': return Icons.priority_high; case 'high': return Icons.arrow_upward; default: return Icons.remove; }
  }

  Color _priorityColor(String p) {
    switch (p) { case 'urgent': return Colors.red; case 'high': return Colors.orange; case 'medium': return Colors.blue; default: return Colors.green; }
  }
}


