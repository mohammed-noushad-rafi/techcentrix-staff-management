import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';
import 'intern_profile_screen.dart';

class InternHome extends StatefulWidget {
  const InternHome({super.key});

  @override
  State<InternHome> createState() => _InternHomeState();
}

class _InternHomeState extends State<InternHome> {
  List<TaskItem> _tasks = [];
  bool _loading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getMyTasks();
    setState(() {
      _tasks = raw.map((t) => TaskItem.fromJson(t)).toList();
      _loading = false;
    });
  }

  Future<void> _moveTask(TaskItem task, int newColumnId, String newColumnName) async {
    // Optimistic update
    setState(() {
      final idx = _tasks.indexWhere((t) => t.id == task.id);
      if (idx != -1) _tasks[idx] = task.copyWith(column: newColumnId);
    });
    try {
      await context.read<AppState>().api.internMoveTask(task.id, newColumnId, 0);
    } catch (_) {
      _loadTasks();
    }
  }

  // Get unique columns from tasks in order
  List<MapEntry<int, String>> get _columns {
    final seen = <int>{};
    final result = <MapEntry<int, String>>[];
    for (final t in _tasks) {
      if (!seen.contains(t.column)) {
        seen.add(t.column);
        result.add(MapEntry(t.column, t.columnName));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final profile = user?.internProfile;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TechCentric Interns', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(profile?.department.isNotEmpty == true ? profile!.department : 'Intern Portal', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTasks),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => context.read<AppState>().logout()),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _tasksView(),
          const InternProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.task_outlined), selectedIcon: Icon(Icons.task), label: 'My Tasks'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'My Profile'),
        ],
      ),
    );
  }

  Widget _tasksView() {
    final done = _tasks.where((t) => t.isCompleted).length;
    final total = _tasks.length;

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No tasks assigned to you yet.'),
            Text('Your manager will assign tasks soon.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTasks,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('My Progress', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('$done / $total tasks done', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: total == 0 ? 0 : done / total,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Group by column (pipeline stage)
          ..._groupedTaskSliver(),
        ],
      ),
    );
  }

  List<Widget> _groupedTaskSliver() {
    final grouped = <int, List<TaskItem>>{};
    final colNames = <int, String>{};
    for (final t in _tasks) {
      grouped.putIfAbsent(t.column, () => []).add(t);
      colNames[t.column] = t.columnName;
    }
    final result = <Widget>[];
    for (final col in grouped.entries) {
      result.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(colNames[col.key] ?? 'Stage', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
        ),
      ));
      result.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final task = col.value[i];
            return _TaskTile(task: task, onMove: _moveTask, allColumns: _columns);
          },
          childCount: col.value.length,
        ),
      ));
    }
    return result;
  }
}

class _TaskTile extends StatelessWidget {
  final TaskItem task;
  final Future<void> Function(TaskItem, int, String) onMove;
  final List<MapEntry<int, String>> allColumns;

  const _TaskTile({required this.task, required this.onMove, required this.allColumns});

  Color _priorityColor(String p) {
    switch (p) { case 'urgent': return Colors.red; case 'high': return Colors.orange; case 'medium': return Colors.blue; default: return Colors.green; }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(color: _priorityColor(task.priority), borderRadius: BorderRadius.circular(2)),
        ),
        title: Text(task.title, style: TextStyle(fontWeight: FontWeight.w500, decoration: task.isCompleted ? TextDecoration.lineThrough : null)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.dueDate != null)
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 11, color: task.isOverdue ? Colors.red : Colors.grey),
                const SizedBox(width: 4),
                Text(task.dueDate!, style: TextStyle(fontSize: 11, color: task.isOverdue ? Colors.red : Colors.grey)),
              ]),
            Text(task.priority.toUpperCase(), style: TextStyle(fontSize: 10, color: _priorityColor(task.priority), fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: task.isCompleted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : PopupMenuButton<MapEntry<int, String>>(
                icon: const Icon(Icons.arrow_forward_outlined),
                tooltip: 'Move to...',
                itemBuilder: (_) => allColumns.where((c) => c.key != task.column).map((c) =>
                  PopupMenuItem(value: c, child: Text('Move to ${c.value}'))
                ).toList(),
                onSelected: (col) => onMove(task, col.key, col.value),
              ),
      ),
    );
  }
}
