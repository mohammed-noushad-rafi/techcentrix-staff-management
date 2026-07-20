import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';
import 'assign_task_screen.dart';

class StaffDetailScreen extends StatefulWidget {
  final int staffId;
  const StaffDetailScreen({super.key, required this.staffId});
  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StaffProfile? _staff;
  List<TaskItem> _tasks = [];
  bool _loading = true, _saving = false;

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _jobRoleCtrl = TextEditingController();
  final _departmentCtrl = TextEditingController();
  final _skillsCtrl = TextEditingController();
  final _mentorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _startDate, _endDate;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AppState>().api;
    final data = await api.getStaffMember(widget.staffId);
    final taskData = await api.getStaffTasks(widget.staffId);
    final s = StaffProfile.fromJson(data);
    _fullNameCtrl.text = s.fullName;
    _phoneCtrl.text = s.phone;
    _idCtrl.text = s.idNumber;
    _collegeCtrl.text = s.college;
    _degreeCtrl.text = s.degree;
    _jobRoleCtrl.text = s.jobRole;
    _departmentCtrl.text = s.department;
    _skillsCtrl.text = s.skills;
    _mentorCtrl.text = s.mentor;
    _notesCtrl.text = s.notes;
    _startDate = s.startDate != null ? DateTime.tryParse(s.startDate!) : null;
    _endDate = s.endDate != null ? DateTime.tryParse(s.endDate!) : null;
    setState(() {
      _staff = s;
      _tasks = taskData.map((t) => TaskItem.fromJson(t)).toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().api.updateStaff(widget.staffId, {
        'full_name': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'id_number': _idCtrl.text.trim(),
        'college': _collegeCtrl.text.trim(),
        'degree': _degreeCtrl.text.trim(),
        'job_role': _jobRoleCtrl.text.trim(),
        'department': _departmentCtrl.text.trim(),
        'skills': _skillsCtrl.text.trim(),
        'mentor': _mentorCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        if (_startDate != null) 'start_date': '${_startDate!.year}-${_startDate!.month.toString().padLeft(2,'0')}-${_startDate!.day.toString().padLeft(2,'0')}',
        if (_endDate != null) 'end_date': '${_endDate!.year}-${_endDate!.month.toString().padLeft(2,'0')}-${_endDate!.day.toString().padLeft(2,'0')}',
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved.'))); _load(); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _saving = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final s = _staff!;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.fullName),
        actions: [
          TextButton(
            onPressed: () async { await context.read<AppState>().api.toggleStaffStatus(s.id); _load(); },
            child: Text(s.isActive ? 'Deactivate' : 'Activate', style: TextStyle(color: s.isActive ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Profile'), Tab(text: 'Tasks'), Tab(text: 'Account')]),
      ),
      body: TabBarView(controller: _tabs, children: [_profileTab(s), _tasksTab(s), _accountTab(s)]),
    );
  }

  Widget _profileTab(StaffProfile s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Stack(children: [
          s.photoUrl != null && s.photoUrl!.isNotEmpty
              ? CircleAvatar(radius: 52, backgroundImage: NetworkImage(s.photoUrl!))
              : CircleAvatar(radius: 52, backgroundColor: s.isIntern ? Colors.blue.shade100 : Colors.teal.shade100,
                  child: Text(s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: s.isIntern ? Colors.blue : Colors.teal))),
          Positioned(bottom: 0, right: 0, child: InkWell(
            onTap: () async {
              final p = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
              if (p == null) return;
              await context.read<AppState>().api.uploadStaffPhoto(s.id, p.path);
              _load();
            },
            child: const CircleAvatar(radius: 16, backgroundColor: Colors.indigo, child: Icon(Icons.camera_alt, size: 16, color: Colors.white)),
          )),
        ])),
        const SizedBox(height: 8),
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: s.isIntern ? Colors.blue.shade50 : Colors.teal.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: s.isIntern ? Colors.blue : Colors.teal)),
            child: Text(s.isIntern ? 'Intern' : 'Employee', style: TextStyle(color: s.isIntern ? Colors.blue.shade700 : Colors.teal.shade700, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: s.isActive ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: s.isActive ? Colors.green : Colors.orange)),
            child: Text(s.isActive ? 'Active' : 'Inactive', style: TextStyle(color: s.isActive ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold))),
        ])),
        const SizedBox(height: 16),

        _fld('Full Name', _fullNameCtrl),
        _fld('Phone', _phoneCtrl, keyboard: TextInputType.phone),
        _fld('ID Number', _idCtrl),
        _fld('Department', _departmentCtrl),
        _fld('Skills (comma-separated)', _skillsCtrl, maxLines: 2),
        _fld('Mentor', _mentorCtrl),
        _dp('Start Date', _startDate, (d) => setState(() => _startDate = d)),
        _dp('End Date', _endDate, (d) => setState(() => _endDate = d)),

        if (s.isIntern) ...[
          const Padding(padding: EdgeInsets.only(top: 8, bottom: 8), child: Text('Academic', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          _fld('College / University', _collegeCtrl),
          _fld('Degree', _degreeCtrl),
        ] else ...[
          const Padding(padding: EdgeInsets.only(top: 8, bottom: 8), child: Text('Professional', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          _fld('Job Role', _jobRoleCtrl),
        ],

        _fld('Admin Notes', _notesCtrl, maxLines: 3),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          child: _saving ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Save Changes')),
      ]),
    );
  }

  Widget _tasksTab(StaffProfile s) {
    final pending = _tasks.where((t) => t.submittedForReview && !t.isCompleted).length;
    final done = _tasks.where((t) => t.isCompleted).length;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Progress', style: TextStyle(fontWeight: FontWeight.bold)),
          Text('$done/${_tasks.length} completed'),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: s.taskProgress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
        if (pending > 0) ...[
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.pending_actions, size: 16, color: Colors.orange), const SizedBox(width: 6), Text('$pending task(s) pending your verification', style: const TextStyle(color: Colors.orange, fontSize: 12))]),
        ],
      ]))),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignTaskScreen())).then((_) => _load()),
        icon: const Icon(Icons.assignment_outlined, size: 16), label: const Text('Assign New Task'), style: FilledButton.styleFrom(visualDensity: VisualDensity.compact)),
      const SizedBox(height: 12),
      ..._tasks.map((t) => Card(margin: const EdgeInsets.symmetric(vertical: 3), child: ListTile(
        leading: Icon(_priorityIcon(t.priority), color: _priorityColor(t.priority), size: 20),
        title: Text(t.title, style: TextStyle(decoration: t.isCompleted ? TextDecoration.lineThrough : null)),
        subtitle: Text(t.statusLabel, style: TextStyle(fontSize: 11, color: _statusColor(t.status))),
        trailing: t.submittedForReview && !t.isCompleted ? const Icon(Icons.pending_actions, color: Colors.orange, size: 18) : (t.isCompleted ? const Icon(Icons.check_circle, color: Colors.green, size: 18) : null),
      ))),
    ]);
  }

  Widget _accountTab(StaffProfile s) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _tile('Username', s.username, Icons.person_outline),
      _tile('Email', s.email, Icons.email_outlined),
      _tile('Role', s.role[0].toUpperCase() + s.role.substring(1), Icons.badge_outlined),
      _tile('Status', s.isActive ? 'Active' : 'Inactive', Icons.circle, color: s.isActive ? Colors.green : Colors.orange),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        icon: const Icon(Icons.lock_reset), label: const Text('Reset Password'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
        onPressed: () async {
          final ctrl = TextEditingController();
          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Reset Password'),
            content: TextField(controller: ctrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 6 chars)')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset'))],
          ));
          if (ok == true && ctrl.text.length >= 6) { await context.read<AppState>().api.resetStaffPassword(s.id, ctrl.text); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.'))); }
        },
      ),
      const SizedBox(height: 10),
      FilledButton.icon(
        icon: Icon(s.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline),
        label: Text(s.isActive ? 'Deactivate Account' : 'Activate Account'),
        style: FilledButton.styleFrom(backgroundColor: s.isActive ? Colors.orange : Colors.green, minimumSize: const Size.fromHeight(44)),
        onPressed: () async { await context.read<AppState>().api.toggleStaffStatus(s.id); _load(); },
      ),
    ]);
  }

  Widget _fld(String label, TextEditingController ctrl, {int maxLines = 1, TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: ctrl, maxLines: maxLines, keyboardType: keyboard, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder())),
  );

  Widget _dp(String label, DateTime? v, ValueChanged<DateTime> onPicked) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      onTap: () async { final d = await showDatePicker(context: context, initialDate: v ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030)); if (d != null) onPicked(d); },
      child: InputDecorator(decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18)),
        child: Text(v != null ? '${v.year}-${v.month.toString().padLeft(2,'0')}-${v.day.toString().padLeft(2,'0')}' : 'Tap to select', style: TextStyle(color: v != null ? null : Colors.grey))),
    ),
  );

  Widget _tile(String label, String value, IconData icon, {Color? color}) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
    subtitle: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
  );

  IconData _priorityIcon(String p) { switch (p) { case 'urgent': return Icons.priority_high; case 'high': return Icons.arrow_upward; default: return Icons.remove; } }
  Color _priorityColor(String p) { switch (p) { case 'urgent': return Colors.red; case 'high': return Colors.orange; case 'medium': return Colors.blue; default: return Colors.green; } }
  Color _statusColor(String s) { switch (s) { case 'done_pending': return Colors.orange; case 'completed': return Colors.green; case 'in_progress': return Colors.blue; default: return Colors.grey; } }
}
