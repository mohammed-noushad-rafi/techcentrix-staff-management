import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import 'pending_verification_screen.dart';
import 'assign_task_screen.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});
  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<TaskItem> _tasks = [];
  bool _loading = true;
  String _search = '';
  String _priorityFilter = 'all';
  final _searchCtrl = TextEditingController();

  // Group views
  static const _views = ['By Status', 'By Priority', 'By Person'];
  int _viewIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await context.read<AppState>().api.getTasks();
      setState(() {
        _tasks = raw.map((t) => TaskItem.fromJson(t)).toList();
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  List<TaskItem> get _filtered {
    var list = _tasks.where((t) {
      final matchSearch = _search.isEmpty ||
          t.title.toLowerCase().contains(_search.toLowerCase()) ||
          t.assigneeName.toLowerCase().contains(_search.toLowerCase());
      final matchPriority = _priorityFilter == 'all' || t.priority == _priorityFilter;
      return matchSearch && matchPriority;
    }).toList();
    return list;
  }

  // Stats
  int get _total    => _tasks.length;
  int get _pending  => _tasks.where((t) => t.submittedForReview && !t.isCompleted).length;
  int get _overdue  => _tasks.where((t) => t.isOverdue && !t.isCompleted).length;
  int get _done     => _tasks.where((t) => t.isCompleted).length;
  int get _inProg   => _tasks.where((t) => t.status == 'in_progress').length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedDelegate(
              child: _buildControls(),
              height: 110,
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : _filtered.isEmpty
                ? _emptyState()
                : _viewIndex == 0 ? _byStatusView()
                : _viewIndex == 1 ? _byPriorityView()
                : _byPersonView(),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AssignTaskScreen())).then((_) => _load()),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_task_rounded, color: Colors.white),
        label: const Text('Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      gradient: AppTheme.heroGradient,
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Task Board', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            Text('All assigned tasks', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
          if (_pending > 0)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingVerificationScreen())).then((_) => _load()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.warning, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text('$_pending pending', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 16),
        // Stats pills
        Row(children: [
          _heroPill('$_total',   'Total',      Colors.white),
          const SizedBox(width: 8),
          _heroPill('$_inProg',  'In Progress', const Color(0xFF93C5FD)),
          const SizedBox(width: 8),
          _heroPill('$_done',    'Completed',  const Color(0xFF86EFAC)),
          const SizedBox(width: 8),
          _heroPill('$_overdue', 'Overdue',    const Color(0xFFFCA5A5)),
        ]),
      ]),
    )),
  );

  Widget _heroPill(String val, String label, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
    child: Column(children: [
      Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, height: 1)),
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9)),
    ]),
  ));

  Widget _buildControls() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Column(children: [
      // Search
      TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'Search tasks or assignee…',
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primary),
          suffixIcon: _search.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16),
                  onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
              : null,
          filled: true, fillColor: AppTheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
      const SizedBox(height: 8),
      // View toggle + priority filter
      Row(children: [
        // View mode
        Container(
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: _views.asMap().entries.map((e) {
            final sel = e.key == _viewIndex;
            return GestureDetector(
              onTap: () => setState(() => _viewIndex = e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
                child: Text(e.value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: sel ? Colors.white : Colors.grey.shade500)),
              ),
            );
          }).toList()),
        ),
        const SizedBox(width: 8),
        // Priority filter
        Expanded(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _pChip('all',    'All'),
            _pChip('urgent', '🔴 Urgent'),
            _pChip('high',   '🟠 High'),
            _pChip('medium', '🔵 Medium'),
            _pChip('low',    '🟢 Low'),
          ]),
        )),
      ]),
    ]),
  );

  Widget _pChip(String val, String label) {
    final sel = _priorityFilter == val;
    final color = val == 'all' ? AppTheme.primary
        : val == 'urgent' ? AppTheme.error
        : val == 'high'   ? AppTheme.warning
        : val == 'medium' ? AppTheme.primary
        : AppTheme.success;
    return GestureDetector(
      onTap: () => setState(() => _priorityFilter = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.2))),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
            color: sel ? Colors.white : color)),
      ),
    );
  }

  // ── Views ─────────────────────────────────────────

  Widget _byStatusView() {
    final groups = {
      'To Do':          {'color': const Color(0xFF6B7280), 'icon': Icons.radio_button_unchecked_rounded,  'statuses': ['todo']},
      'In Progress':    {'color': AppTheme.primary,        'icon': Icons.play_circle_rounded,             'statuses': ['in_progress']},
      'Review':         {'color': AppTheme.warning,        'icon': Icons.rate_review_rounded,             'statuses': ['review']},
      'Pending Review': {'color': const Color(0xFFF7941D), 'icon': Icons.pending_actions_rounded,         'statuses': ['done_pending']},
      'Completed':      {'color': AppTheme.success,        'icon': Icons.check_circle_rounded,            'statuses': ['completed']},
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        ...groups.entries.map((entry) {
          final items = _filtered.where((t) =>
              (entry.value['statuses'] as List).contains(t.status)).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return _group(
            entry.key, items,
            entry.value['color'] as Color,
            entry.value['icon'] as IconData,
          );
        }),
      ]),
    );
  }

  Widget _byPriorityView() {
    final groups = {
      'Urgent': {'color': AppTheme.error,    'icon': Icons.priority_high_rounded,  'priority': 'urgent'},
      'High':   {'color': AppTheme.warning,  'icon': Icons.arrow_upward_rounded,   'priority': 'high'},
      'Medium': {'color': AppTheme.primary,  'icon': Icons.remove_rounded,         'priority': 'medium'},
      'Low':    {'color': AppTheme.success,  'icon': Icons.arrow_downward_rounded, 'priority': 'low'},
    };

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        ...groups.entries.map((entry) {
          final items = _filtered.where((t) => t.priority == entry.value['priority']).toList();
          if (items.isEmpty) return const SizedBox.shrink();
          return _group(entry.key, items, entry.value['color'] as Color, entry.value['icon'] as IconData);
        }),
      ]),
    );
  }

  Widget _byPersonView() {
    final people = <String, List<TaskItem>>{};
    for (final t in _filtered) {
      final name = t.assigneeName.isNotEmpty ? t.assigneeName : 'Unassigned';
      people.putIfAbsent(name, () => []).add(t);
    }
    final sorted = people.entries.toList()
      ..sort((a,b) => b.value.length.compareTo(a.value.length));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        ...sorted.map((entry) {
          final done = entry.value.where((t) => t.isCompleted).length;
          final pending = entry.value.where((t) => t.submittedForReview && !t.isCompleted).length;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Person header
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(gradient: AppTheme.avatarGradient(entry.key), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(entry.key[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A1A2E))),
                  Text('${entry.value.length} tasks · $done done${pending > 0 ? ' · $pending pending review' : ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                if (pending > 0) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3))),
                  child: Text('$pending pending', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.warning))),
              ]),
            ),
            ...entry.value.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskRow(task: t, onRefresh: _load))),
            const SizedBox(height: 8),
            const Divider(),
          ]);
        }),
      ]),
    );
  }

  Widget _group(String title, List<TaskItem> items, Color color, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 14)),
          const SizedBox(width: 10),
          Text(title.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
              color: color, letterSpacing: 0.5)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text('${items.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
        ]),
      ),
      ...items.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8),
          child: _TaskRow(task: t, onRefresh: _load))),
      const SizedBox(height: 8),
    ],
  );

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 90, height: 90,
      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
      child: const Icon(Icons.task_outlined, size: 44, color: AppTheme.primary)),
    const SizedBox(height: 16),
    const Text('No tasks found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A2E))),
    const SizedBox(height: 8),
    Text(_search.isNotEmpty ? 'Try a different search term' : 'Assign a task to get started',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
  ]));
}

// ── Task Row ──────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onRefresh;
  const _TaskRow({required this.task, required this.onRefresh});

  Color get _pColor => AppTheme.priorityColor(task.priority);
  Color get _sColor => AppTheme.statusColor(task.status);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: _pColor.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Row(children: [
          // Priority bar
          Container(width: 4, height: 80,
            decoration: BoxDecoration(color: _pColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)))),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title + action
              Row(children: [
                Expanded(child: Text(task.title, style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14,
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted ? Colors.grey : const Color(0xFF1A1A2E)))),
                if (task.submittedForReview && !task.isCompleted)
                  _quickVerify(context)
                else if (task.isOverdue && !task.isCompleted)
                  _pill('Overdue', AppTheme.error)
                else if (task.isCompleted)
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
              ]),
              const SizedBox(height: 5),
              // Meta row
              Row(children: [
                // Assignee avatar + name
                if (task.assigneeName.isNotEmpty) ...[
                  Container(width: 18, height: 18,
                    decoration: BoxDecoration(gradient: AppTheme.avatarGradient(task.assigneeName), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(task.assigneeName[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 5),
                  Text(task.assigneeName, style: const TextStyle(fontSize: 11, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                ],
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _sColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(task.statusLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _sColor))),
                if (task.dueDate != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today_rounded, size: 10,
                      color: task.isOverdue ? AppTheme.error : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 3),
                  Text(task.dueDate!, style: TextStyle(fontSize: 10,
                      color: task.isOverdue ? AppTheme.error : const Color(0xFF9CA3AF))),
                ],
              ]),
              // Subtask mini progress
              if (task.subtaskCount > 0) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: task.subtaskDoneCount / task.subtaskCount, minHeight: 4,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: const AlwaysStoppedAnimation(AppTheme.success)))),
                  const SizedBox(width: 6),
                  Text('${task.subtaskDoneCount}/${task.subtaskCount}',
                      style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
                ]),
              ],
            ]),
          )),
          const SizedBox(width: 10),
        ]),
      ),
    );
  }

  Widget _quickVerify(BuildContext context) => GestureDetector(
    onTap: () async {
      final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Verify & Complete?'),
        content: Text('Mark "${task.title}" as completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.success,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Verify')),
        ],
      ));
      if (ok == true) {
        await context.read<AppState>().api.verifyTask(task.id);
        onRefresh();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8), Text('Task verified!')]),
          backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
      }
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.success, Color(0xFF059669)]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_rounded, color: Colors.white, size: 13),
        SizedBox(width: 4),
        Text('Verify', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    ),
  );

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
  );
}

// ── Pinned header delegate ─────────────────────────────
class _PinnedDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  const _PinnedDelegate({required this.child, required this.height});
  @override double get minExtent => height;
  @override double get maxExtent => height;
  @override Widget build(_, __, ___) => child;
  @override bool shouldRebuild(_PinnedDelegate old) => old.child != child;
}
