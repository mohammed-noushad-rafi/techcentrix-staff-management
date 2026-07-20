import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/board.dart';
import '../models/workspace.dart';
import '../services/app_state.dart';
import 'kanban_board_screen.dart';

class BoardListScreen extends StatefulWidget {
  final Workspace workspace;
  const BoardListScreen({super.key, required this.workspace});

  @override
  State<BoardListScreen> createState() => _BoardListScreenState();
}

class _BoardListScreenState extends State<BoardListScreen> {
  late Future<List<Board>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Board>> _load() async {
    final raw = await context.read<AppState>().api.getBoards();
    return raw
        .map((e) => Board.fromJson(e))
        .where((b) => b.workspace == widget.workspace.id)
        .toList();
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Board name')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await context
                  .read<AppState>()
                  .api
                  .createBoard(widget.workspace.id, nameCtrl.text.trim(), descCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.workspace.name)),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Board>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final boards = snapshot.data ?? [];
            if (boards.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No boards yet. Create one to start planning.')),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: boards.length,
              itemBuilder: (context, i) {
                final board = boards[i];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => KanbanBoardScreen(boardId: board.id)))
                        .then((_) => _refresh()),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.view_kanban_outlined, size: 28, color: Color(0xFF4F46E5)),
                          const Spacer(),
                          Text(board.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('${board.columns.length} columns',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New board'),
      ),
    );
  }
}
