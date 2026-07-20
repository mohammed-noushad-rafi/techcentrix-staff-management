import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/board.dart';
import '../models/task.dart';
import '../services/app_state.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

class KanbanBoardScreen extends StatefulWidget {
  final int boardId;
  const KanbanBoardScreen({super.key, required this.boardId});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  Board? _board;
  Map<int, List<TaskItem>> _tasksByColumn = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppState>().api;
      final boardJson = await api.getBoard(widget.boardId);
      final board = Board.fromJson(boardJson);
      final taskRaw = await api.getTasks(widget.boardId);
      final tasks = taskRaw.map((t) => TaskItem.fromJson(t)).toList();

      final grouped = <int, List<TaskItem>>{};
      for (final col in board.columns) {
        grouped[col.id] = tasks.where((t) => t.column == col.id).toList()
          ..sort((a, b) => a.order.compareTo(b.order));
      }

      setState(() {
        _board = board;
        _tasksByColumn = grouped;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _moveTask(TaskItem task, BoardColumn targetColumn) async {
    if (task.column == targetColumn.id) return;
    final api = context.read<AppState>().api;
    final newOrder = (_tasksByColumn[targetColumn.id]?.length ?? 0);

    // Optimistic UI update
    setState(() {
      _tasksByColumn[task.column]?.removeWhere((t) => t.id == task.id);
      final moved = task.copyWith(column: targetColumn.id, order: newOrder);
      _tasksByColumn.putIfAbsent(targetColumn.id, () => []).add(moved);
    });

    try {
      await api.moveTask(task.id, targetColumn.id, newOrder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move task: $e')),
        );
      }
      _load(); // revert by reloading from server
    }
  }

  Future<void> _showCreateTaskDialog(BoardColumn column) async {
    final titleCtrl = TextEditingController();
    String priority = 'medium';
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('New task in ${column.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Task title'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (v) => setLocal(() => priority = v ?? 'medium'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                await context.read<AppState>().api.createTask(
                      boardId: widget.boardId,
                      columnId: column.id,
                      title: titleCtrl.text.trim(),
                      priority: priority,
                    );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Board')),
        body: Center(child: Text('Error: $_error')),
      );
    }
    final board = _board!;
    return Scaffold(
      appBar: AppBar(
        title: Text(board.name),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: board.columns.map((col) => _buildColumn(col)).toList(),
        ),
      ),
    );
  }

  Widget _buildColumn(BoardColumn column) {
    final tasks = _tasksByColumn[column.id] ?? [];
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(column.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${tasks.length}', style: const TextStyle(fontSize: 12)),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  onPressed: () => _showCreateTaskDialog(column),
                ),
              ],
            ),
          ),
          Expanded(
            child: DragTarget<TaskItem>(
              onWillAcceptWithDetails: (details) => true,
              onAcceptWithDetails: (details) => _moveTask(details.data, column),
              builder: (context, candidateData, rejectedData) {
                final isHovering = candidateData.isNotEmpty;
                return Container(
                  decoration: BoxDecoration(
                    color: isHovering
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: tasks.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('Drop tasks here', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 12),
                          itemCount: tasks.length,
                          itemBuilder: (context, i) {
                            final task = tasks[i];
                            return LongPressDraggable<TaskItem>(
                              data: task,
                              feedback: Material(
                                color: Colors.transparent,
                                child: SizedBox(width: 260, child: TaskCard(task: task)),
                              ),
                              childWhenDragging: Opacity(opacity: 0.3, child: TaskCard(task: task)),
                              child: TaskCard(
                                task: task,
                                onTap: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => TaskDetailScreen(task: task)))
                                    .then((_) => _load()),
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
