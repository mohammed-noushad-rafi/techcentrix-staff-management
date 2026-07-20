import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

const _departments = [
  'Engineering','Design','Product','Marketing','Sales',
  'Human Resources','Finance','Operations','Data Science',
  'QA & Testing','DevOps','Customer Support','Other',
];

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});
  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  List<Team> _teams = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await context.read<AppState>().api.getTeams();
      setState(() { _teams = raw.map((e) => Team.fromJson(e)).toList(); _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 110,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end, children: [
                Row(children: [
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Teams', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Manage your team groups', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ])),
                ]),
              ]),
            ),
          ),
          title: const Text('Teams'),
        ),

        if (_loading)
          const SliverToBoxAdapter(child: SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))))
        else if (_teams.isEmpty)
          SliverToBoxAdapter(child: _emptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _teamCard(_teams[i]),
              childCount: _teams.length,
            )),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTeamScreen())).then((_) => _load()),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.group_add_rounded, color: Colors.white),
        label: const Text('Create Team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _teamCard(Team team) {
    final colors = [AppTheme.primary, AppTheme.secondary, const Color(0xFF10B981),
                    const Color(0xFF8B5CF6), const Color(0xFF0D9488)];
    final color = colors[team.name.codeUnitAt(0) % colors.length];
    final members = team.members.take(4).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetail(team),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header strip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.03)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [color, color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(team.name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(team.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A2E))),
                if (team.department.isNotEmpty)
                  Row(children: [
                    Icon(Icons.business_rounded, size: 12, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(team.department, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${team.memberCount} member${team.memberCount != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
            ]),
          ),

          // Description
          if (team.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(team.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),

          // Members avatars
          if (team.members.isNotEmpty) Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              // Stacked avatars
              SizedBox(
                height: 32,
                width: (members.length * 22 + 12).toDouble().clamp(0, 100),
                child: Stack(children: members.asMap().entries.map((e) {
                  final m = e.value as Map<String, dynamic>;
                  final name = (m['username'] ?? '?') as String;
                  return Positioned(
                    left: e.key * 22.0,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: AppTheme.avatarGradient(name),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList()),
              ),
              if (team.memberCount > 4) ...[
                const SizedBox(width: 8),
                Text('+${team.memberCount - 4} more', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
              const Spacer(),
              Text('Tap to view', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              Icon(Icons.arrow_forward_ios_rounded, size: 11, color: color),
            ]),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _confirmDelete(team),
                icon: const Icon(Icons.delete_outline_rounded, size: 15),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error,
                    side: BorderSide(color: AppTheme.error.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    visualDensity: VisualDensity.compact),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(
                onPressed: () => _showDetail(team),
                icon: const Icon(Icons.people_rounded, size: 15),
                label: const Text('Manage'),
                style: FilledButton.styleFrom(backgroundColor: color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    visualDensity: VisualDensity.compact),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmDelete(Team team) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Team?'),
      content: Text('Delete "${team.name}"? Members won\'t be deleted, only the team group.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (ok == true) {
      await context.read<AppState>().api.deleteTeam(team.id);
      _load();
    }
  }

  void _showDetail(Team team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeamDetailSheet(team: team, onChanged: _load),
    );
  }

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      const SizedBox(height: 60),
      Container(width: 110, height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.1), AppTheme.primary.withValues(alpha: 0.05)]),
          shape: BoxShape.circle),
        child: const Icon(Icons.groups_rounded, size: 54, color: AppTheme.primary)),
      const SizedBox(height: 22),
      const Text('No teams yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Text('Create teams to group your interns and employees together for collaborative work.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 28),
      FilledButton.icon(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTeamScreen())).then((_) => _load()),
        icon: const Icon(Icons.group_add_rounded),
        label: const Text('Create First Team'),
        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
      ),
    ]),
  );
}

// ── Team Detail Sheet ─────────────────────────────────

class _TeamDetailSheet extends StatefulWidget {
  final Team team;
  final VoidCallback onChanged;
  const _TeamDetailSheet({required this.team, required this.onChanged});
  @override
  State<_TeamDetailSheet> createState() => _TeamDetailSheetState();
}

class _TeamDetailSheetState extends State<_TeamDetailSheet> {
  late Team _team;
  List<dynamic> _allStaff = [];
  bool _loadingStaff = false;
  bool _showAddMembers = false;
  Set<int> _toAdd = {};

  @override
  void initState() { super.initState(); _team = widget.team; }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    final raw = await context.read<AppState>().api.searchStaff();
    setState(() { _allStaff = raw; _loadingStaff = false; });
  }

  Future<void> _removeMember(int userId) async {
    await context.read<AppState>().api.removeTeamMember(_team.id, userId);
    final raw = await context.read<AppState>().api.getTeams();
    final updated = raw.firstWhere((t) => t['id'] == _team.id, orElse: () => null);
    if (updated != null) setState(() => _team = Team.fromJson(updated));
    widget.onChanged();
  }

  Future<void> _addMembers() async {
    for (final id in _toAdd) {
      await context.read<AppState>().api.addTeamMember(_team.id, id);
    }
    setState(() { _toAdd = {}; _showAddMembers = false; });
    final raw = await context.read<AppState>().api.getTeams();
    final updated = raw.firstWhere((t) => t['id'] == _team.id, orElse: () => null);
    if (updated != null) setState(() => _team = Team.fromJson(updated));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final existingIds = _team.members.map((m) => (m as Map)['id'] as int).toSet();
    final available = _allStaff.where((s) => !existingIds.contains((s['user']?['id'] ?? 0) as int)).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false, initialChildSize: 0.65, maxChildSize: 0.92,
        builder: (_, sc) => Column(children: [
          // Handle
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),

          // Header
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF0E6FA3)]),
                  borderRadius: BorderRadius.circular(13)),
              alignment: Alignment.center,
              child: Text(_team.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_team.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
              Text('${_team.memberCount} member${_team.memberCount != 1 ? 's' : ''}${_team.department.isNotEmpty ? " · ${_team.department}" : ""}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
          ])),

          const Divider(height: 1),

          Expanded(child: !_showAddMembers
              ? _membersList(sc)
              : _addMembersPanel(available, sc)),

          // Footer
          SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.all(16),
            child: !_showAddMembers
                ? FilledButton.icon(
                    onPressed: () { _loadStaff(); setState(() => _showAddMembers = true); },
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Members', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.primary,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  )
                : Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => setState(() { _showAddMembers = false; _toAdd = {}; }),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: const Size(0, 50)),
                      child: const Text('Cancel'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(
                      onPressed: _toAdd.isEmpty ? null : _addMembers,
                      style: FilledButton.styleFrom(backgroundColor: AppTheme.primary,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text(_toAdd.isEmpty ? 'Select members' : 'Add ${_toAdd.length} member${_toAdd.length > 1 ? 's' : ''}'),
                    )),
                  ]),
          )),
        ]),
      ),
    );
  }

  Widget _membersList(ScrollController sc) {
    if (_team.members.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade300),
      const SizedBox(height: 12),
      Text('No members yet', style: TextStyle(color: Colors.grey.shade500)),
    ]));

    return ListView.builder(
      controller: sc,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _team.members.length,
      itemBuilder: (_, i) {
        final m = _team.members[i] as Map<String, dynamic>;
        final name = (m['username'] ?? '?') as String;
        final role = (m['role'] ?? '') as String;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(role[0].toUpperCase() + role.substring(1),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.error, size: 20),
              onPressed: () => _removeMember(m['id']),
              tooltip: 'Remove',
            ),
          ]),
        );
      },
    );
  }

  Widget _addMembersPanel(List<dynamic> available, ScrollController sc) {
    if (_loadingStaff) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (available.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, size: 48, color: AppTheme.success),
      const SizedBox(height: 12),
      const Text('All staff are already members!', style: TextStyle(fontWeight: FontWeight.bold)),
    ]));

    return ListView.builder(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      itemCount: available.length,
      itemBuilder: (_, i) {
        final s = available[i] as Map<String, dynamic>;
        final uid = (s['user']?['id'] ?? 0) as int;
        final name = (s['full_name'] ?? '') as String;
        final role = (s['user']?['role'] ?? '') as String;
        final dept = (s['department'] ?? '') as String;
        final sel = _toAdd.contains(uid);

        return GestureDetector(
          onTap: () => setState(() => sel ? _toAdd.remove(uid) : _toAdd.add(uid)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sel ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? AppTheme.primary : Colors.transparent, width: 2),
            ),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${role[0].toUpperCase()}${role.substring(1)}${dept.isNotEmpty ? " · $dept" : ""}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ])),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 26, height: 26,
                decoration: BoxDecoration(
                  color: sel ? AppTheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade300, width: 2),
                ),
                child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Create Team Screen ────────────────────────────────

class CreateTeamScreen extends StatefulWidget {
  const CreateTeamScreen({super.key});
  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _dept;
  List<dynamic> _allStaff = [];
  Set<int> _selectedIds = {};
  bool _loadingStaff = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadStaff(); }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final raw = await context.read<AppState>().api.searchStaff();
      setState(() { _allStaff = raw; _loadingStaff = false; });
    } catch (_) { setState(() => _loadingStaff = false); }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter a team name.'); return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await context.read<AppState>().api.createTeam({
        'name': _nameCtrl.text.trim(),
        'department': _dept ?? '',
        'description': _descCtrl.text.trim(),
        'member_ids': _selectedIds.toList(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text('Team "${_nameCtrl.text}" created!'),
          ]),
          backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Create Team', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Group your staff into a team', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : _submit,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          )),
        ),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Team info card
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1)))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.groups_rounded, color: AppTheme.primary, size: 16)),
                    const SizedBox(width: 10),
                    const Text('Team Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
                  ]),
                ),
                Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Team Name *',
                      prefixIcon: const Icon(Icons.label_rounded, size: 18),
                      prefixIconColor: AppTheme.primary,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _dept,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Department (optional)',
                      prefixIcon: const Icon(Icons.business_rounded, size: 18),
                      prefixIconColor: Colors.grey.shade400,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    hint: Text('All departments', style: TextStyle(color: Colors.grey.shade400)),
                    items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (v) => setState(() => _dept = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl, maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: const Padding(padding: EdgeInsets.only(bottom: 24), child: Icon(Icons.notes_rounded, size: 18)),
                      prefixIconColor: Colors.grey.shade400,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ])),
              ]),
            ),
            const SizedBox(height: 16),

            // Members section
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    border: Border(bottom: BorderSide(color: AppTheme.secondary.withValues(alpha: 0.1)))),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.people_rounded, color: AppTheme.secondary, size: 16)),
                    const SizedBox(width: 10),
                    const Text('Add Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondary)),
                    const Spacer(),
                    if (_selectedIds.isNotEmpty) Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text('${_selectedIds.length} selected',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary))),
                  ]),
                ),
                if (_loadingStaff)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                else if (_allStaff.isEmpty)
                  Padding(padding: const EdgeInsets.all(24), child: Center(
                    child: Text('No staff found. Add staff first.', style: TextStyle(color: Colors.grey.shade500))))
                else
                  ..._allStaff.map((s) {
                    final uid  = (s['user']?['id'] ?? 0) as int;
                    final name = (s['full_name'] ?? '') as String;
                    final role = (s['user']?['role'] ?? '') as String;
                    final dept = (s['department'] ?? '') as String;
                    final sel  = _selectedIds.contains(uid);
                    return GestureDetector(
                      onTap: () => setState(() => sel ? _selectedIds.remove(uid) : _selectedIds.add(uid)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sel ? AppTheme.primary.withValues(alpha: 0.06) : AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: sel ? AppTheme.primary : Colors.transparent, width: 1.5),
                        ),
                        child: Row(children: [
                          Container(width: 40, height: 40,
                            decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('${role[0].toUpperCase()}${role.substring(1)}${dept.isNotEmpty ? " · $dept" : ""}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ])),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: sel ? AppTheme.primary : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade300, width: 2),
                            ),
                            child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                          ),
                        ]),
                      ),
                    );
                  }),
                const SizedBox(height: 12),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.25))),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 54, child: Material(
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _saving ? null : _submit,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF0E6FA3)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  alignment: Alignment.center,
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            _selectedIds.isEmpty ? 'Create Team' : 'Create Team with ${_selectedIds.length} member${_selectedIds.length > 1 ? 's' : ''}',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ]),
                ),
              ),
            )),
            const SizedBox(height: 30),
          ]),
        )),
      ]),
    );
  }
}
