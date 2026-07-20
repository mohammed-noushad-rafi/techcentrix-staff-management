import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/intern.dart';
import '../../services/app_state.dart';

class InternProfileScreen extends StatefulWidget {
  const InternProfileScreen({super.key});

  @override
  State<InternProfileScreen> createState() => _InternProfileScreenState();
}

class _InternProfileScreenState extends State<InternProfileScreen> {
  InternProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AppState>().api.me();
      final user = AppUserInfo.fromJson(data);
      setState(() { _profile = user.internProfile; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_profile == null) return const Center(child: Text('Profile not found.'));

    final p = _profile!;
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  p.photoUrl != null && p.photoUrl!.isNotEmpty
                      ? CircleAvatar(radius: 44, backgroundImage: NetworkImage(p.photoUrl!))
                      : CircleAvatar(
                          radius: 44,
                          backgroundColor: cs.primaryContainer,
                          child: Text(p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: cs.primary)),
                        ),
                  const SizedBox(height: 12),
                  Text(p.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (p.department.isNotEmpty) Text(p.department, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.isActive ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: p.isActive ? Colors.green : Colors.orange),
                    ),
                    child: Text(p.isActive ? '● Active Intern' : '○ Inactive',
                        style: TextStyle(color: p.isActive ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Progress
          if (p.taskCount > 0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Task Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${p.completedTaskCount}/${p.taskCount}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: p.taskProgress, minHeight: 8, borderRadius: BorderRadius.circular(4)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Info sections
          _section('Personal', [
            _row(Icons.phone_outlined, 'Phone', p.phone),
            _row(Icons.badge_outlined, 'ID Number', p.idNumber),
            _row(Icons.email_outlined, 'Email', context.read<AppState>().currentUser?.email ?? ''),
          ]),

          _section('Academic', [
            _row(Icons.school_outlined, 'College', p.college),
            _row(Icons.menu_book_outlined, 'Degree', p.degree),
          ]),

          if (p.skillsList.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Skills', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: p.skillsList.map((s) => Chip(
                        label: Text(s, style: const TextStyle(fontSize: 12)),
                        backgroundColor: cs.primaryContainer,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),
          _section('Internship', [
            _row(Icons.business_outlined, 'Department', p.department),
            _row(Icons.supervisor_account_outlined, 'Mentor', p.mentor),
            _row(Icons.calendar_today_outlined, 'Start Date', p.startDate ?? 'Not set'),
            _row(Icons.event_outlined, 'End Date', p.endDate ?? 'Not set'),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
