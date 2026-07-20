import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/intern.dart';
import '../../services/app_state.dart';
import 'intern_detail_screen.dart';
import 'create_intern_screen.dart';

class InternListScreen extends StatefulWidget {
  const InternListScreen({super.key});

  @override
  State<InternListScreen> createState() => _InternListScreenState();
}

class _InternListScreenState extends State<InternListScreen> {
  List<InternProfile> _interns = [];
  bool _loading = true;
  String _statusFilter = 'all';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getInterns(
          status: _statusFilter == 'all' ? null : _statusFilter,
          search: _searchCtrl.text,
        );
    setState(() {
      _interns = raw.map((e) => InternProfile.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _toggle(InternProfile intern) async {
    await context.read<AppState>().api.toggleInternStatus(intern.id);
    _load();
  }

  Future<void> _delete(InternProfile intern) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete intern?'),
        content: Text('This will permanently delete ${intern.fullName} and all their data.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<AppState>().api.deleteIntern(intern.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interns'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or college...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['all', 'active', 'inactive'].map((s) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s[0].toUpperCase() + s.substring(1)),
                      selected: _statusFilter == s,
                      onSelected: (_) { setState(() => _statusFilter = s); _load(); },
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateInternScreen())).then((_) => _load()),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _interns.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(_searchCtrl.text.isNotEmpty ? 'No results found.' : 'No interns yet.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateInternScreen())).then((_) => _load()),
                        icon: const Icon(Icons.person_add_outlined),
                        label: const Text('Add Intern'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _interns.length,
                    itemBuilder: (context, i) {
                      final intern = _interns[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: _InternAvatar(intern: intern, radius: 24),
                          title: Text(intern.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (intern.department.isNotEmpty) Text(intern.department),
                              if (intern.college.isNotEmpty) Text(intern.college, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: intern.isActive ? Colors.green.shade50 : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: intern.isActive ? Colors.green.shade300 : Colors.orange.shade300),
                                  ),
                                  child: Text(
                                    intern.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(fontSize: 11, color: intern.isActive ? Colors.green.shade700 : Colors.orange.shade700, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${intern.taskCount} tasks', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ]),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'view') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => InternDetailScreen(internId: intern.id))).then((_) => _load());
                              } else if (val == 'toggle') {
                                _toggle(intern);
                              } else if (val == 'delete') {
                                _delete(intern);
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 8), Text('View profile')])),
                              PopupMenuItem(value: 'toggle', child: Row(children: [Icon(intern.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18), const SizedBox(width: 8), Text(intern.isActive ? 'Deactivate' : 'Activate')])),
                              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InternDetailScreen(internId: intern.id))).then((_) => _load()),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _InternAvatar extends StatelessWidget {
  final InternProfile intern;
  final double radius;
  const _InternAvatar({required this.intern, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (intern.photoUrl != null && intern.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(intern.photoUrl!),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        intern.fullName.isNotEmpty ? intern.fullName[0].toUpperCase() : '?',
        style: TextStyle(fontSize: radius * 0.7, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
