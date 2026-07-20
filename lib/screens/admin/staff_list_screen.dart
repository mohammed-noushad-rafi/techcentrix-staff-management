import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../services/app_state.dart';
import 'staff_detail_screen.dart';
import 'create_staff_screen.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});
  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<StaffProfile> _all = [], _interns = [], _employees = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<AppState>().api;
    final search = _searchCtrl.text;
    final statusArg = _statusFilter == 'all' ? null : _statusFilter;
    final all = await api.getStaff(search: search, status: statusArg);
    final interns = await api.getStaff(role: 'intern', search: search, status: statusArg);
    final employees = await api.getStaff(role: 'employee', search: search, status: statusArg);
    setState(() {
      _all = all.map((e) => StaffProfile.fromJson(e)).toList();
      _interns = interns.map((e) => StaffProfile.fromJson(e)).toList();
      _employees = employees.map((e) => StaffProfile.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _toggle(StaffProfile s) async {
    await context.read<AppState>().api.toggleStaffStatus(s.id);
    _load();
  }

  Future<void> _delete(StaffProfile s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('Delete ${s.fullName}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) { await context.read<AppState>().api.deleteStaff(s.id); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff'),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name, job role, college...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _load(); }) : null,
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 12),
                ...[('all', 'All'), ('active', 'Active'), ('inactive', 'Inactive')].map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(s.$2), selected: _statusFilter == s.$1,
                    onSelected: (_) { setState(() => _statusFilter = s.$1); _load(); }),
                )),
              ],
            ),
            TabBar(controller: _tabs, tabs: const [Tab(text: 'All'), Tab(text: 'Interns'), Tab(text: 'Employees')]),
          ]),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.person_add_outlined), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStaffScreen())).then((_) => _load())),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabs, children: [
              _list(_all),
              _list(_interns),
              _list(_employees),
            ]),
    );
  }

  Widget _list(List<StaffProfile> items) {
    if (items.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.people_outline, size: 56, color: Colors.grey),
      const SizedBox(height: 12),
      const Text('No staff found.'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStaffScreen())).then((_) => _load()), icon: const Icon(Icons.person_add_outlined), label: const Text('Add Staff')),
    ]));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final s = items[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              leading: _avatar(s, 22),
              title: Row(children: [
                Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _roleBadge(s),
              ]),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (s.isEmployee && s.jobRole.isNotEmpty) Text(s.jobRole, style: const TextStyle(fontSize: 12)),
                if (s.isIntern && s.college.isNotEmpty) Text(s.college, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (s.department.isNotEmpty) Text(s.department, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(children: [
                  _statusBadge(s),
                  const SizedBox(width: 8),
                  Text('${s.taskCount} tasks', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  if (s.pendingVerificationCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                      child: Text('${s.pendingVerificationCount} pending', style: const TextStyle(fontSize: 10, color: Colors.white))),
                  ],
                ]),
              ]),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'view') Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDetailScreen(staffId: s.id))).then((_) => _load());
                  else if (val == 'toggle') _toggle(s);
                  else if (val == 'delete') _delete(s);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility_outlined, size: 18), SizedBox(width: 8), Text('View')])),
                  PopupMenuItem(value: 'toggle', child: Row(children: [Icon(s.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18), const SizedBox(width: 8), Text(s.isActive ? 'Deactivate' : 'Activate')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                ],
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StaffDetailScreen(staffId: s.id))).then((_) => _load()),
            ),
          );
        },
      ),
    );
  }

  Widget _avatar(StaffProfile s, double radius) {
    if (s.photoUrl != null && s.photoUrl!.isNotEmpty) return CircleAvatar(radius: radius, backgroundImage: NetworkImage(s.photoUrl!));
    return CircleAvatar(radius: radius, backgroundColor: s.isIntern ? Colors.blue.shade100 : Colors.teal.shade100,
      child: Text(s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
        style: TextStyle(fontWeight: FontWeight.bold, color: s.isIntern ? Colors.blue : Colors.teal)));
  }

  Widget _roleBadge(StaffProfile s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: s.isIntern ? Colors.blue.shade50 : Colors.teal.shade50, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: s.isIntern ? Colors.blue.shade200 : Colors.teal.shade200)),
    child: Text(s.isIntern ? 'Intern' : 'Employee', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: s.isIntern ? Colors.blue.shade700 : Colors.teal.shade700)),
  );

  Widget _statusBadge(StaffProfile s) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: s.isActive ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: s.isActive ? Colors.green.shade300 : Colors.orange.shade300)),
    child: Text(s.isActive ? 'Active' : 'Inactive', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: s.isActive ? Colors.green.shade700 : Colors.orange.shade700)),
  );
}
