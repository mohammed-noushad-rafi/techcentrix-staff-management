import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workspace.dart';
import '../services/app_state.dart';
import 'board_list_screen.dart';
import 'notifications_screen.dart';

class WorkspaceListScreen extends StatefulWidget {
  const WorkspaceListScreen({super.key});

  @override
  State<WorkspaceListScreen> createState() => _WorkspaceListScreenState();
}

class _WorkspaceListScreenState extends State<WorkspaceListScreen> {
  late Future<List<Workspace>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Workspace>> _load() async {
    final raw = await context.read<AppState>().api.getWorkspaces();
    return raw.map((e) => Workspace.fromJson(e)).toList();
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New workspace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await context.read<AppState>().api.createWorkspace(nameCtrl.text.trim(), descCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (created == true) _refresh();
  }

  Future<void> _showJoinDialog() async {
    final codeCtrl = TextEditingController();
    final joined = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join workspace'),
        content: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(labelText: 'Invite code'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<AppState>().api.joinWorkspace(codeCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (joined == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workspaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined),
            tooltip: 'Join workspace',
            onPressed: _showJoinDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Workspace>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final workspaces = snapshot.data ?? [];
            if (workspaces.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No workspaces yet. Create one to get started.')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: workspaces.length,
              itemBuilder: (context, i) {
                final ws = workspaces[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.workspaces_outlined)),
                    title: Text(ws.name),
                    subtitle: Text(ws.description.isEmpty
                        ? '${ws.memberCount} member(s)'
                        : '${ws.description} · ${ws.memberCount} member(s)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => BoardListScreen(workspace: ws)),
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
        label: const Text('New workspace'),
      ),
    );
  }
}
