import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../services/app_state.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  StaffProfile? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AppState>().api.me();
      final user = AppUserInfo.fromJson(data);
      setState(() { _profile = user.staffProfile; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_profile == null) return const Center(child: Text('Profile not found.'));
    final p = _profile!;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Header
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          p.photoUrl != null && p.photoUrl!.isNotEmpty
              ? CircleAvatar(radius: 44, backgroundImage: NetworkImage(p.photoUrl!))
              : CircleAvatar(radius: 44, backgroundColor: p.isIntern ? Colors.blue.shade100 : Colors.teal.shade100,
                  child: Text(p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: p.isIntern ? Colors.blue : Colors.teal))),
          const SizedBox(height: 12),
          Text(p.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          if (p.isEmployee && p.jobRole.isNotEmpty) Text(p.jobRole, style: const TextStyle(color: Colors.grey)),
          if (p.isIntern && p.department.isNotEmpty) Text(p.department, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: p.isIntern ? Colors.blue.shade50 : Colors.teal.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.isIntern ? Colors.blue : Colors.teal)),
              child: Text(p.isIntern ? '🎓 Intern' : '💼 Employee', style: TextStyle(color: p.isIntern ? Colors.blue.shade700 : Colors.teal.shade700, fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: p.isActive ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: p.isActive ? Colors.green : Colors.orange)),
              child: Text(p.isActive ? '● Active' : '○ Inactive', style: TextStyle(color: p.isActive ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 12))),
          ]),
        ]))),
        const SizedBox(height: 12),

        // Progress
        if (p.taskCount > 0) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Task Progress', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${p.completedTaskCount}/${p.taskCount}', style: const TextStyle(color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: p.taskProgress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
          if (p.pendingVerificationCount > 0) ...[
            const SizedBox(height: 6),
            Text('${p.pendingVerificationCount} pending admin review', style: const TextStyle(color: Colors.orange, fontSize: 12)),
          ],
        ]))),

        const SizedBox(height: 12),
        _section('Personal', [
          if (p.phone.isNotEmpty) _row(Icons.phone_outlined, 'Phone', p.phone),
          if (p.idNumber.isNotEmpty) _row(Icons.badge_outlined, 'ID Number', p.idNumber),
        ]),

        if (p.isIntern) _section('Academic', [
          if (p.college.isNotEmpty) _row(Icons.school_outlined, 'College', p.college),
          if (p.degree.isNotEmpty) _row(Icons.menu_book_outlined, 'Degree', p.degree),
        ]) else _section('Professional', [
          if (p.jobRole.isNotEmpty) _row(Icons.work_outlined, 'Job Role', p.jobRole),
          if (p.experienceType.isNotEmpty) _row(Icons.timeline_outlined, 'Experience', p.experienceType == 'fresher' ? 'Fresher' : '${p.yearsOfExperience ?? 0}+ years experienced'),
        ]),

        if (p.skillsList.isNotEmpty) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Skills', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: p.skillsList.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)), backgroundColor: cs.primaryContainer, visualDensity: VisualDensity.compact)).toList()),
        ]))),

        const SizedBox(height: 8),
        _section('Internship / Work Details', [
          if (p.department.isNotEmpty) _row(Icons.business_outlined, 'Department', p.department),
          if (p.mentor.isNotEmpty) _row(Icons.supervisor_account_outlined, 'Mentor', p.mentor),
          if (p.startDate != null) _row(Icons.calendar_today_outlined, 'Start Date', p.startDate!),
          if (p.endDate != null) _row(Icons.event_outlined, 'End Date', p.endDate!),
        ]),
      ]),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    final nonEmpty = rows.where((w) => w is! SizedBox).toList();
    if (nonEmpty.isEmpty) return const SizedBox.shrink();
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 8),
      ...rows,
    ])));
  }

  Widget _row(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
      Icon(icon, size: 18, color: Colors.grey),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ]),
    ]));
  }
}
