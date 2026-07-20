import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

class StaffTaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  const StaffTaskDetailScreen({super.key, required this.task});
  @override
  State<StaffTaskDetailScreen> createState() => _StaffTaskDetailScreenState();
}

class _StaffTaskDetailScreenState extends State<StaffTaskDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late TaskItem _task;
  List<dynamic> _subtasks = [], _comments = [];
  bool _loading = true, _submitting = false;
  final _subtaskCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _task = widget.task;
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AppState>().api;
    final subtasks = await api.getSubtasks(_task.id);
    final comments = await api.getComments(_task.id);
    setState(() { _subtasks = subtasks; _comments = comments; _loading = false; });
  }

  Future<void> _submitForReview() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.send_rounded, color: AppTheme.success, size: 20)),
        const SizedBox(width: 12),
        const Text('Submit for Review?'),
      ]),
      content: const Text('This will notify your admin that the task is ready. They\'ll verify and mark it complete.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
      ],
    ));
    if (confirm == true) {
      final updated = await context.read<AppState>().api.submitTask(_task.id);
      setState(() => _task = TaskItem.fromJson(updated));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Submitted! Admin will verify soon.'),
        ]),
        backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    }
  }

  Future<void> _addSubtask() async {
    final text = _subtaskCtrl.text.trim();
    if (text.isEmpty) return;
    _subtaskCtrl.clear();
    await context.read<AppState>().api.createSubtask(_task.id, text);
    _load();
  }

  Future<void> _toggleSubtask(dynamic s) async {
    await context.read<AppState>().api.toggleSubtask(s['id'], !(s['is_done'] ?? false));
    _load();
  }

  Future<void> _postComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    _commentCtrl.clear();
    await context.read<AppState>().api.addComment(_task.id, text);
    await _load();
    if (mounted) setState(() => _submitting = false);
  }

  Color get _priorityColor => AppTheme.priorityColor(_task.priority);
  Color get _statusColor => AppTheme.statusColor(_task.status);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            expandedHeight: 140,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end, children: [
                  // Priority & status pills
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priorityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _priorityColor.withValues(alpha: 0.4))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.flag_rounded, size: 12, color: _priorityColor),
                        const SizedBox(width: 4),
                        Text(_task.priorityLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _priorityColor)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20)),
                      child: Text(_task.statusLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(_task.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
            actions: [
              if (!_task.isCompleted && !_task.submittedForReview)
                TextButton(
                  onPressed: _submitForReview,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Submit ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              const SizedBox(width: 8),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabHeaderDelegate(
              TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  const Tab(text: 'Details'),
                  Tab(text: _subtasks.isEmpty ? 'Subtasks' : 'Subtasks (${_subtasks.length})'),
                  Tab(text: _comments.isEmpty ? 'Comments' : 'Comments (${_comments.length})'),
                ],
              ),
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
            : TabBarView(controller: _tabs, children: [
                _detailsTab(),
                _subtasksTab(),
                _commentsTab(),
              ]),
      ),
    );
  }

  Widget _detailsTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Status banner
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _statusColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _statusColor.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(_statusIcon(), color: _statusColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_statusHeadline(), style: TextStyle(fontWeight: FontWeight.bold, color: _statusColor, fontSize: 14)),
            Text(_statusSubtitle(), style: TextStyle(fontSize: 12, color: _statusColor.withValues(alpha: 0.8))),
          ])),
          if (_task.isCompleted) const Icon(Icons.verified_rounded, color: AppTheme.success, size: 24),
        ]),
      ),
      const SizedBox(height: 16),

      // Description
      if (_task.description.isNotEmpty) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.notes_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500, letterSpacing: 0.3)),
            ]),
            const SizedBox(height: 8),
            Text(_task.description, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151))),
          ]),
        ),
        const SizedBox(height: 12),
      ],

      // Info grid
      Row(children: [
        Expanded(child: _infoCard(Icons.flag_rounded, 'Priority', _task.priorityLabel, _priorityColor)),
        const SizedBox(width: 10),
        if (_task.dueDate != null)
          Expanded(child: _infoCard(Icons.calendar_today_rounded, 'Due Date', _task.dueDate!,
              _task.isOverdue ? AppTheme.error : const Color(0xFF374151))),
      ]),

      // Move column buttons (only if not submitted/completed)
      if (!_task.isCompleted && !_task.submittedForReview) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.drag_indicator_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text('Move to column', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500, letterSpacing: 0.3)),
            ]),
            const SizedBox(height: 10),
            _columnButtons(),
          ]),
        ),
      ],

      // Verified by
      if (_task.isCompleted && _task.verifiedBy != null) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.success.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.verified_rounded, color: AppTheme.success, size: 20),
            const SizedBox(width: 10),
            Text('Verified by ${_task.verifiedBy!['username']}',
                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
          ]),
        ),
      ],
    ]),
  );

  Widget _columnButtons() => FutureBuilder(
    future: context.read<AppState>().api.getBoard(_task.board),
    builder: (_, snap) {
      if (!snap.hasData) return const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      final cols = snap.data!['columns'] as List? ?? [];
      return Wrap(spacing: 8, runSpacing: 8, children: cols.map((c) {
        final isCurrent = c['id'] == _task.column;
        final color = _colColor(c['name'] ?? '');
        return GestureDetector(
          onTap: isCurrent ? null : () async {
            final updated = await context.read<AppState>().api.moveTask(_task.id, c['id'], 0);
            setState(() => _task = TaskItem.fromJson(updated));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isCurrent ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isCurrent ? color : color.withValues(alpha: 0.3)),
            ),
            child: Text(c['name'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: isCurrent ? Colors.white : color)),
          ),
        );
      }).toList());
    },
  );

  Color _colColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('done') || n.contains('complete')) return AppTheme.success;
    if (n.contains('progress')) return AppTheme.info;
    if (n.contains('review') || n.contains('testing')) return AppTheme.warning;
    return const Color(0xFF6B7280);
  }

  Widget _infoCard(IconData icon, String label, String value, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ]),
    ]),
  );

  // ── Subtasks ────────────────────────────────────────

  Widget _subtasksTab() {
    final done  = _subtasks.where((s) => s['is_done'] == true).length;
    final total = _subtasks.length;
    final canEdit = !_task.isCompleted && !_task.submittedForReview;

    return Column(children: [
      if (total > 0) Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$done of $total completed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${((done/total)*100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.success)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: total == 0 ? 0 : done/total, minHeight: 8,
              backgroundColor: AppTheme.surface,
              valueColor: const AlwaysStoppedAnimation(AppTheme.success))),
        ]),
      ),

      Expanded(child: total == 0
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.checklist_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No subtasks yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Break your task into smaller steps.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: total,
              itemBuilder: (_, i) {
                final s   = _subtasks[i];
                final done = s['is_done'] ?? false;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))]),
                  child: ListTile(
                    leading: GestureDetector(
                      onTap: canEdit ? () => _toggleSubtask(s) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: done ? AppTheme.success : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: done ? AppTheme.success : Colors.grey.shade300, width: 2)),
                        child: done ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                      ),
                    ),
                    title: Text(s['title'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? Colors.grey.shade400 : const Color(0xFF1A1A2E),
                        fontWeight: done ? FontWeight.normal : FontWeight.w500,
                      )),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  ),
                );
              },
            )),

      if (canEdit) Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        color: Colors.white,
        child: SafeArea(top: false, child: Row(children: [
          Expanded(child: TextField(
            controller: _subtaskCtrl,
            decoration: InputDecoration(
              hintText: 'Add a subtask…',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true, fillColor: AppTheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onSubmitted: (_) => _addSubtask(),
          )),
          const SizedBox(width: 10),
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF0E6FA3)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
            child: IconButton(icon: const Icon(Icons.add_rounded, color: Colors.white), onPressed: _addSubtask),
          ),
        ])),
      ),
    ]);
  }

  // ── Comments ────────────────────────────────────────

  Widget _commentsTab() => Column(children: [
    Expanded(child: _comments.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No comments yet', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Start the conversation.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _comments.length,
            itemBuilder: (_, i) {
              final c      = _comments[i] as Map<String, dynamic>;
              final author = c['author'] as Map<String, dynamic>? ?? {};
              final name   = (author['username'] ?? '?') as String;
              final isMe   = author['id'] == context.read<AppState>().currentUser?.id;
              final time   = _formatTime(c['created_at'] ?? '');

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (!isMe) ...[
                      Container(width: 34, height: 34,
                        decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 8),
                    ],
                    Flexible(child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                          ),
                          child: Text(c['body'] ?? '',
                              style: TextStyle(color: isMe ? Colors.white : const Color(0xFF374151), fontSize: 14, height: 1.4)),
                        ),
                        const SizedBox(height: 3),
                        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                      ],
                    )),
                    if (isMe) const SizedBox(width: 8),
                  ],
                ),
              );
            },
          )),

    Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))]),
      child: SafeArea(top: false, child: Row(children: [
        Expanded(child: TextField(
          controller: _commentCtrl,
          minLines: 1, maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Write a comment…',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true, fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        )),
        const SizedBox(width: 10),
        _submitting
            ? const SizedBox(width: 46, height: 46, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)))
            : GestureDetector(
                onTap: _postComment,
                child: Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.secondary, Color(0xFFE07B0A)]),
                    borderRadius: BorderRadius.circular(23),
                    boxShadow: [BoxShadow(color: AppTheme.secondary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
      ])),
    ),
  ]);

  String _statusHeadline() {
    if (_task.isCompleted) return 'Task Completed ✓';
    if (_task.submittedForReview) return 'Submitted for Review';
    switch (_task.status) {
      case 'in_progress': return 'In Progress';
      case 'review': return 'Under Review';
      default: return 'To Do';
    }
  }

  String _statusSubtitle() {
    if (_task.isCompleted) return 'Admin has verified and approved this task.';
    if (_task.submittedForReview) return 'Waiting for admin verification. Hang tight!';
    if (_task.status == 'in_progress') return 'You\'re working on this. Submit when ready.';
    return 'Start working and move it to In Progress.';
  }

  IconData _statusIcon() {
    if (_task.isCompleted) return Icons.check_circle_rounded;
    if (_task.submittedForReview) return Icons.pending_actions_rounded;
    if (_task.status == 'in_progress') return Icons.play_circle_rounded;
    if (_task.status == 'review') return Icons.rate_review_rounded;
    return Icons.radio_button_unchecked_rounded;
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(d);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }
}

class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabHeaderDelegate(this.tabBar);
  @override double get minExtent => tabBar.preferredSize.height;
  @override double get maxExtent => tabBar.preferredSize.height;
  @override Widget build(_, __, ___) => Container(color: AppTheme.primary, child: tabBar);
  @override bool shouldRebuild(_TabHeaderDelegate old) => old.tabBar != tabBar;
}
