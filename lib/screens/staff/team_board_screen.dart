import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import 'task_detail_screen.dart';

class TeamBoardScreen extends StatefulWidget {
  const TeamBoardScreen({super.key});
  @override
  State<TeamBoardScreen> createState() => _TeamBoardScreenState();
}

class _TeamBoardScreenState extends State<TeamBoardScreen> {
  List<dynamic> _teamData = [];
  bool _loading = true;
  int? _expandedTeam;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await context.read<AppState>().api.getMyTeamTasks();
      setState(() { _teamData = raw; _loading = false;
        if (raw.isNotEmpty) _expandedTeam = (raw.first as Map)['team_id'];
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));

    if (_teamData.isEmpty) return _emptyState();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _teamData.length,
        itemBuilder: (_, i) => _teamSection(_teamData[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _teamSection(Map<String, dynamic> data) {
    final teamId   = data['team_id'] as int;
    final name     = data['team_name'] as String;
    final dept     = data['department'] as String? ?? '';
    final members  = (data['members'] as List? ?? []);
    final tasks    = (data['tasks'] as List? ?? [])
        .map((t) => TaskItem.fromJson(t as Map<String, dynamic>)).toList();
    final expanded = _expandedTeam == teamId;
    final colors   = [AppTheme.primary, AppTheme.secondary, const Color(0xFF10B981),
                      const Color(0xFF8B5CF6), const Color(0xFF0D9488)];
    final color    = colors[name.codeUnitAt(0) % colors.length];

    final done    = tasks.where((t) => t.isCompleted).length;
    final pending = tasks.where((t) => t.submittedForReview && !t.isCompleted).length;
    final pct     = tasks.isEmpty ? 0.0 : done / tasks.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0,4))]),
      child: Column(children: [
        // Team header — tappable to expand
        GestureDetector(
          onTap: () => setState(() => _expandedTeam = expanded ? null : teamId),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.03)]),
              borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom: expanded ? Radius.zero : const Radius.circular(18))),
            child: Column(children: [
              Row(children: [
                Container(width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A2E))),
                  if (dept.isNotEmpty) Text(dept, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ])),
                // Task stats
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${tasks.length} task${tasks.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  if (pending > 0) Text('$pending pending',
                      style: const TextStyle(fontSize: 10, color: AppTheme.warning)),
                ]),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Icon(Icons.expand_more_rounded, color: color)),
              ]),
              const SizedBox(height: 12),
              // Progress bar
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Team Progress', style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
                  Text('$done/${tasks.length} done', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: pct, minHeight: 8,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color))),
              ]),
              const SizedBox(height: 12),
              // Member strip
              Row(children: [
                const Text('Team: ', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ...members.take(6).map((m) {
                  final mname = (m['full_name'] as String? ?? m['username'] as String? ?? '?');
                  return Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(gradient: AppTheme.avatarGradient(mname), shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                    alignment: Alignment.center,
                    child: Tooltip(message: mname,
                      child: Text(mname[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))));
                }),
                if (members.length > 6)
                  Text(' +${members.length-6}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ]),
            ]),
          ),
        ),

        // Expanded task list
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: tasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Icon(Icons.task_outlined, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text('No tasks assigned to this team yet',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                  ]))
              : Column(children: [
                  // Status summary chips
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _countChip('All', tasks.length, Colors.grey),
                        _countChip('To Do', tasks.where((t) => t.status=='todo').length, const Color(0xFF6B7280)),
                        _countChip('In Progress', tasks.where((t) => t.status=='in_progress').length, AppTheme.primary),
                        _countChip('Pending', tasks.where((t) => t.submittedForReview && !t.isCompleted).length, AppTheme.warning),
                        _countChip('Done', tasks.where((t) => t.isCompleted).length, AppTheme.success),
                      ]),
                    ),
                  ),
                  ...tasks.map((task) => _sharedTaskCard(task, color)),
                  const SizedBox(height: 8),
                ]),
          secondChild: const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _countChip(String label, int count, Color color) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: count > 0 ? color.withValues(alpha: 0.08) : AppTheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: count > 0 ? color.withValues(alpha: 0.3) : Colors.grey.shade200)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
          color: count > 0 ? color : Colors.grey.shade400)),
      const SizedBox(width: 6),
      Container(width: 18, height: 18,
        decoration: BoxDecoration(color: count > 0 ? color : Colors.grey.shade200, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text('$count', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
            color: count > 0 ? Colors.white : Colors.grey.shade400))),
    ]),
  );

  Widget _sharedTaskCard(TaskItem task, Color teamColor) {
    final pColor = AppTheme.priorityColor(task.priority);
    final sColor = AppTheme.statusColor(task.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => StaffTaskDetailScreen(task: task))).then((_) => _load()),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border(left: BorderSide(color: pColor, width: 4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0,2))]),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(task.title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ? Colors.grey : const Color(0xFF1A1A2E)))),
                  const SizedBox(width: 8),
                  if (task.submittedForReview && !task.isCompleted)
                    _pill('Pending', AppTheme.warning)
                  else if (task.isCompleted)
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: sColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(task.statusLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sColor))),
                  const SizedBox(width: 8),
                  // Priority
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: pColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(task.priorityLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: pColor))),
                  if (task.dueDate != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_rounded, size: 10,
                        color: task.isOverdue ? AppTheme.error : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 3),
                    Text(task.dueDate!, style: TextStyle(fontSize: 10,
                        color: task.isOverdue ? AppTheme.error : const Color(0xFF9CA3AF))),
                  ],
                  // Assignee (if individually assigned within team)
                  if (task.assigneeName.isNotEmpty) ...[
                    const Spacer(),
                    Container(width: 20, height: 20,
                      decoration: BoxDecoration(gradient: AppTheme.avatarGradient(task.assigneeName), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(task.assigneeName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 4),
                    Text(task.assigneeName.split(' ').first,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                  ],
                ]),
                if (task.subtaskCount > 0) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: task.subtaskDoneCount / task.subtaskCount, minHeight: 4,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.success)))),
                    const SizedBox(width: 8),
                    Text('${task.subtaskDoneCount}/${task.subtaskCount} subtasks',
                        style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
                  ]),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)));

  Widget _emptyState() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 90, height: 90,
      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
      child: const Icon(Icons.groups_outlined, size: 44, color: AppTheme.primary)),
    const SizedBox(height: 16),
    const Text('No team tasks yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A2E))),
    const SizedBox(height: 8),
    Text('When your admin assigns tasks to your team,\nthey\'ll appear here for all members to see.',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
  ]));
}
