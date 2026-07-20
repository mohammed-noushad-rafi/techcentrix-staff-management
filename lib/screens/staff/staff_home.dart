import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import '../shared/notifications_screen.dart';
import '../attendance/checkin_screen.dart';
import '../attendance/my_attendance_screen.dart';
import 'my_profile_screen.dart';
import 'task_detail_screen.dart';
import 'team_board_screen.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});
  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  List<TaskItem> _tasks = [];
  bool _loading = true;
  int _currentIndex = 0;
  String _filterPriority = 'all';

  @override
  void initState() { super.initState(); _loadTasks(); }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final raw = await context.read<AppState>().api.getMyTasks();
      setState(() { _tasks = raw.map((t) => TaskItem.fromJson(t)).toList(); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>();
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: IndexedStack(index: _currentIndex, children: [
        _tasksView(user),
        const CheckInScreen(),
        const MyAttendanceScreen(),
        const MyProfileScreen(),
        const TeamBoardScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) {
          setState(() => _currentIndex = i);
          if (i == 0) _loadTasks();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.task_outlined), selectedIcon: Icon(Icons.task_rounded), label: 'My Tasks'),
          NavigationDestination(icon: Icon(Icons.fingerprint_outlined), selectedIcon: Icon(Icons.fingerprint), label: 'Check In'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Team Board'),
        ],
      ),
    );
  }

  Widget _tasksView(AppState user) {
    final done     = _tasks.where((t) => t.isCompleted).length;
    final total    = _tasks.length;
    final pending  = _tasks.where((t) => t.submittedForReview && !t.isCompleted).length;
    final progress = total == 0 ? 0.0 : done / total;

    // Column counts
    final colCounts = <String, int>{};
    for (final t in _tasks) {
      final col = t.columnName.isNotEmpty ? t.columnName : _statusToCol(t.status);
      colCounts[col] = (colCounts[col] ?? 0) + 1;
    }

    // Priority groups (filter applied)
    final priorities = ['urgent', 'high', 'medium', 'low'];
    Map<String, List<TaskItem>> grouped = {};
    for (final pr in priorities) {
      final items = _tasks.where((t) =>
        t.priority == pr &&
        (_filterPriority == 'all' || _filterPriority == pr)
      ).toList();
      if (items.isNotEmpty) grouped[pr] = items;
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [

        // ── Collapsing hero ───────────────────────
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            IconButton(icon: const Icon(Icons.logout_rounded),
              onPressed: () => context.read<AppState>().logout()),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Hello, ${user.displayName.split(' ').first} 👋',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Text('My Tasks', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ),

        if (_loading)
          const SliverToBoxAdapter(child: SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))))

        else if (_tasks.isEmpty)
          SliverToBoxAdapter(child: _emptyState())

        else ...[

          // ── Progress card ──────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
                borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Overall Progress', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                  Text('$done of $total done', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: progress, minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Colors.white))),
                if (pending > 0) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.pending_actions_rounded, size: 13, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text('$pending submitted — awaiting admin verification',
                        style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ]),
                ],
              ]),
            ),
          )),

          // ── Board column strip ────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('Board Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: _buildColStrip(colCounts)),
              ),
            ]),
          )),

          // ── Priority filter chips ─────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 3, height: 14, decoration: BoxDecoration(color: AppTheme.secondary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('Filter by Priority', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              ]),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _filterChip('all',    'All Tasks', Colors.grey),
                  _filterChip('urgent', 'Urgent',    AppTheme.error),
                  _filterChip('high',   'High',      AppTheme.secondary),
                  _filterChip('medium', 'Medium',    AppTheme.primary),
                  _filterChip('low',    'Low',       AppTheme.success),
                ]),
              ),
            ]),
          )),

          // ── Priority groups ───────────────────
          if (grouped.isEmpty)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('No ${_filterPriority == 'all' ? '' : _filterPriority} tasks',
                    style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              ])),
            ))
          else
            ...grouped.entries.map((entry) => SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _priorityGroupHeader(entry.key, entry.value.length),
                const SizedBox(height: 8),
                ...entry.value.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TaskCard(
                    task: t,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => StaffTaskDetailScreen(task: t))).then((_) => _loadTasks()),
                  ),
                )),
              ]),
            ))),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ]),
    );
  }

  List<Widget> _buildColStrip(Map<String, int> colCounts) {
    final cols = [
      {'name': 'Backlog',     'color': const Color(0xFF6B7280), 'icon': Icons.inbox_outlined},
      {'name': 'To Do',       'color': AppTheme.info,           'icon': Icons.radio_button_unchecked_rounded},
      {'name': 'In Progress', 'color': AppTheme.primary,        'icon': Icons.play_circle_rounded},
      {'name': 'Review',      'color': AppTheme.secondary,      'icon': Icons.rate_review_rounded},
      {'name': 'Done',        'color': AppTheme.success,        'icon': Icons.check_circle_rounded},
    ];
    return cols.map((c) {
      final name  = c['name'] as String;
      final color = c['color'] as Color;
      final icon  = c['icon'] as IconData;
      final count = colCounts.entries
          .where((e) => e.key.toLowerCase().contains(name.toLowerCase().split(' ').first))
          .fold(0, (sum, e) => sum + e.value);
      return Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: count > 0 ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: count > 0 ? color.withValues(alpha: 0.3) : Colors.grey.shade200),
        ),
        child: Column(children: [
          Icon(icon, color: count > 0 ? color : Colors.grey.shade300, size: 20),
          const SizedBox(height: 6),
          Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: count > 0 ? color : Colors.grey.shade300)),
          Text(name, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: count > 0 ? color : Colors.grey.shade300)),
        ]),
      );
    }).toList();
  }

  Widget _filterChip(String value, String label, Color color) {
    final sel = _filterPriority == value;
    return GestureDetector(
      onTap: () => setState(() => _filterPriority = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.2)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: sel ? Colors.white : color)),
      ),
    );
  }

  Widget _priorityGroupHeader(String priority, int count) {
    final color = AppTheme.priorityColor(priority);
    final icons = {
      'urgent': Icons.priority_high_rounded,
      'high':   Icons.arrow_upward_rounded,
      'medium': Icons.remove_rounded,
      'low':    Icons.arrow_downward_rounded,
    };
    final labels = {
      'urgent': '🔴  URGENT',
      'high':   '🟠  HIGH',
      'medium': '🔵  MEDIUM',
      'low':    '🟢  LOW',
    };
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icons[priority], color: color, size: 14)),
      const SizedBox(width: 10),
      Text(labels[priority] ?? priority.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.5)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
    ]);
  }

  String _statusToCol(String status) {
    switch (status) {
      case 'in_progress': return 'In Progress';
      case 'review':      return 'Review';
      case 'done_pending':
      case 'completed':   return 'Done';
      default:            return 'To Do';
    }
  }

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      const SizedBox(height: 40),
      Container(width: 100, height: 100,
        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.task_outlined, size: 48, color: AppTheme.primary)),
      const SizedBox(height: 20),
      const Text('No tasks yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Text('Your manager will assign tasks to you soon.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500), textAlign: TextAlign.center),
    ]),
  );
}

// ── Task Card ─────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onTap;
  const _TaskCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pColor = AppTheme.priorityColor(task.priority);
    final sColor = AppTheme.statusColor(task.status);
    final colName = task.columnName.isNotEmpty ? task.columnName : _statusLabel(task.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: pColor.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            // Priority left bar
            Container(
              width: 4, height: 80,
              decoration: BoxDecoration(
                color: pColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)))),
            const SizedBox(width: 14),
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Title row
                Row(children: [
                  Expanded(child: Text(task.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        color: task.isCompleted ? Colors.grey : const Color(0xFF1A1A2E)))),
                  const SizedBox(width: 8),
                  if (task.submittedForReview && !task.isCompleted)
                    _pill('Pending', AppTheme.warning)
                  else if (task.isCompleted)
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20)
                  else
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF), size: 20),
                ]),
                const SizedBox(height: 6),
                // Meta row
                Row(children: [
                  // Column/status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(colName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: sColor))),
                  if (task.dueDate != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_rounded, size: 11,
                        color: task.isOverdue ? AppTheme.error : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Text(task.dueDate!, style: TextStyle(fontSize: 11,
                        color: task.isOverdue ? AppTheme.error : const Color(0xFF9CA3AF))),
                  ],
                  if (task.isOverdue) ...[
                    const SizedBox(width: 6),
                    _pill('Overdue', AppTheme.error),
                  ],
                ]),
                // Subtask progress
                if (task.subtaskCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: task.subtaskCount == 0 ? 0 : task.subtaskDoneCount / task.subtaskCount,
                        minHeight: 4, backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.success)))),
                    const SizedBox(width: 8),
                    Text('${task.subtaskDoneCount}/${task.subtaskCount}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ]),
                ],
              ]),
            )),
            const SizedBox(width: 14),
          ]),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );

  String _statusLabel(String s) {
    switch (s) {
      case 'in_progress':  return 'In Progress';
      case 'done_pending': return 'Pending Review';
      case 'completed':    return 'Done';
      case 'review':       return 'Review';
      default:             return 'To Do';
    }
  }
}
