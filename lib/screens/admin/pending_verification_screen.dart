import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';
import 'assign_task_screen.dart';

class PendingVerificationScreen extends StatefulWidget {
  const PendingVerificationScreen({super.key});
  @override
  State<PendingVerificationScreen> createState() => _PendingVerificationScreenState();
}

class _PendingVerificationScreenState extends State<PendingVerificationScreen> {
  List<TaskItem> _tasks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getTasks(status: 'done_pending');
    setState(() {
      _tasks = raw.map((t) => TaskItem.fromJson(t)).toList();
      _loading = false;
    });
  }

  Future<void> _verify(TaskItem task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify & Complete?'),
        content: Text('Mark "${task.title}" as completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.green), onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify & Complete')),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<AppState>().api.verifyTask(task.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${task.title}" marked as completed!')));
      _load();
    }
  }

  Future<void> _reassign(TaskItem task) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _ReassignScreen(task: task)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Verification'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_outlined, size: 64, color: Colors.green),
                  SizedBox(height: 12),
                  Text('All clear! No tasks pending verification.'),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _tasks.length,
                    itemBuilder: (context, i) {
                      final task = _tasks[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
                                  _priorityChip(task.priority),
                                ],
                              ),
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              ],
                              const SizedBox(height: 8),
                              if (task.assigneeName.isNotEmpty) Row(children: [
                                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('Submitted by ${task.assigneeName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ]),
                              if (task.dueDate != null) Row(children: [
                                Icon(Icons.calendar_today_outlined, size: 14, color: task.isOverdue ? Colors.red : Colors.grey),
                                const SizedBox(width: 4),
                                Text('Due: ${task.dueDate}', style: TextStyle(fontSize: 12, color: task.isOverdue ? Colors.red : Colors.grey)),
                              ]),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: OutlinedButton.icon(
                                    onPressed: () => _reassign(task),
                                    icon: const Icon(Icons.assignment_return_outlined, size: 16),
                                    label: const Text('Reassign'),
                                  )),
                                  const SizedBox(width: 10),
                                  Expanded(child: FilledButton.icon(
                                    onPressed: () => _verify(task),
                                    icon: const Icon(Icons.verified_outlined, size: 16),
                                    label: const Text('Verify & Complete'),
                                    style: FilledButton.styleFrom(backgroundColor: Colors.green),
                                  )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _priorityChip(String priority) {
    final colors = {'urgent': Colors.red, 'high': Colors.orange, 'medium': Colors.blue, 'low': Colors.green};
    final color = colors[priority] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color)),
      child: Text(priority.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _ReassignScreen extends StatefulWidget {
  final TaskItem task;
  const _ReassignScreen({required this.task});
  @override
  State<_ReassignScreen> createState() => _ReassignScreenState();
}

class _ReassignScreenState extends State<_ReassignScreen> {
  List<dynamic> _staff = [];
  int? _selectedUserId;
  bool _loading = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final raw = await context.read<AppState>().api.searchStaff();
    setState(() => _staff = raw);
  }

  Future<void> _submit() async {
    if (_selectedUserId == null) return;
    setState(() => _loading = true);
    await context.read<AppState>().api.reassignTask(widget.task.id, _selectedUserId!);
    if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task reassigned!'))); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reassign: ${widget.task.title}')),
      body: Column(children: [
        Expanded(child: ListView.builder(
          itemCount: _staff.length,
          itemBuilder: (ctx, i) {
            final s = _staff[i];
            final id = s['user']['id'];
            return ListTile(
              leading: CircleAvatar(child: Text((s['full_name'] ?? '?')[0].toUpperCase())),
              title: Text(s['full_name'] ?? ''),
              subtitle: Text('${s['department'] ?? ''} · ${s['user']?['role'] ?? ''}'),
              trailing: _selectedUserId == id ? const Icon(Icons.check_circle, color: Colors.indigo) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
              onTap: () => setState(() => _selectedUserId = id),
            );
          },
        )),
        Padding(padding: const EdgeInsets.all(16), child: FilledButton(
          onPressed: _loading || _selectedUserId == null ? null : _submit,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: _loading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Confirm Reassign'),
        )),
      ]),
    );
  }
}
