import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/staff.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

class AssignTaskScreen extends StatefulWidget {
  const AssignTaskScreen({super.key});
  @override
  State<AssignTaskScreen> createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  String _mode = 'individual';
  int _step = 0;

  List<StaffProfile> _staff = [];
  bool _loadingStaff = true;
  StaffProfile? _selectedStaff;
  String _roleFilter = 'all';
  final _searchCtrl = TextEditingController();

  List<dynamic> _teams = [];
  bool _loadingTeams = true;
  Map<String, dynamic>? _selectedTeam;

  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _priority = 'medium';
  DateTime? _dueDate;
  List<dynamic> _boards = [];
  Map<String, dynamic>? _selectedBoard;
  int? _selectedColumnId;
  bool _saving = false;
  String? _error;

  @override
  void initState() { super.initState(); _loadAll(); }

  Future<void> _loadAll() async { _loadStaff(); _loadTeams(); _loadBoards(); }

  Future<void> _loadStaff() async {
    setState(() => _loadingStaff = true);
    try {
      final raw = await context.read<AppState>().api.searchStaff(
          role: _roleFilter == 'all' ? null : _roleFilter,
          search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim());
      setState(() {
        _staff = raw.map((e) => StaffProfile.fromJson(e as Map<String, dynamic>)).toList();
        _loadingStaff = false;
      });
    } catch (_) { setState(() => _loadingStaff = false); }
  }

  Future<void> _loadTeams() async {
    setState(() => _loadingTeams = true);
    try {
      final raw = await context.read<AppState>().api.getTeams();
      setState(() { _teams = raw; _loadingTeams = false; });
    } catch (_) { setState(() => _loadingTeams = false); }
  }

  Future<void> _loadBoards() async {
    try {
      final raw = await context.read<AppState>().api.getBoards();
      setState(() {
        _boards = raw;
        if (raw.isNotEmpty) {
          _selectedBoard = raw.first as Map<String, dynamic>;
          final cols = (_selectedBoard!['columns'] as List? ?? []);
          if (cols.isNotEmpty) _selectedColumnId = cols.first['id'];
        }
      });
    } catch (_) {}
  }

  Future<void> _assign() async {
    if (_titleCtrl.text.trim().isEmpty) { setState(() => _error = 'Please enter a task title.'); return; }
    if (_selectedBoard == null || _selectedColumnId == null) { setState(() => _error = 'No board found.'); return; }
    if (_mode == 'individual' && _selectedStaff == null) { setState(() => _error = 'Please select an assignee.'); return; }
    if (_mode == 'team' && _selectedTeam == null) { setState(() => _error = 'Please select a team.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'board': _selectedBoard!['id'], 'column': _selectedColumnId,
        'title': _titleCtrl.text.trim(), 'description': _descCtrl.text.trim(),
        'priority': _priority,
        if (_dueDate != null) 'due_date': _fmt(_dueDate!),
      };
      if (_mode == 'individual') body['assignee_id'] = _selectedStaff!.userId;
      else body['team_id'] = _selectedTeam!['id'];
      await context.read<AppState>().api.createTask(body);
      if (mounted) {
        final name = _mode == 'individual' ? _selectedStaff!.fullName : 'Team ${_selectedTeam!['name']}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10), Text('Task assigned to $name!'),
            ]),
            backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        Navigator.pop(context);
      }
    } catch (e) { setState(() { _error = e.toString(); _saving = false; }); }
  }

  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  Color get _accentColor => _mode == 'team' ? const Color(0xFF8B5CF6) : AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(children: [
        _buildHeader(),
        _buildStepIndicator(),
        Expanded(child: _step == 0 ? _pickStep() : _taskStep()),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(gradient: AppTheme.heroGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
    child: SafeArea(bottom: false, child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
              icon: Icon(_step == 1 ? Icons.arrow_back_rounded : Icons.close_rounded, color: Colors.white),
              onPressed: () { if (_step == 1) setState(() => _step = 0); else Navigator.pop(context); }),
          const SizedBox(width: 4),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_step == 0 ? 'Assign Task' : 'Task Details',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(_step == 0 ? 'Step 1 of 2 — Choose assignee' : 'Step 2 of 2 — Fill task info',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
        if (_step == 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              _modeTab('individual', 'Individual', Icons.person_rounded),
              _modeTab('team', 'Team Task', Icons.groups_rounded),
            ]),
          ),
        ],
      ]),
    )),
  );

  Widget _modeTab(String val, String label, IconData icon) {
    final sel = _mode == val;
    final color = val == 'team' ? const Color(0xFF8B5CF6) : AppTheme.primary;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() { _mode = val; _step = 0; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(color: sel ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(11)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: sel ? color : Colors.white60),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: sel ? color : Colors.white70)),
        ]),
      ),
    ));
  }

  Widget _buildStepIndicator() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
    child: Row(children: [
      _stepDot(1, true, _mode == 'team' ? 'Team' : 'Assignee'),
      Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: _step >= 1 ? [AppTheme.primary, AppTheme.primary] : [AppTheme.primary, Colors.grey.shade200]),
              borderRadius: BorderRadius.circular(2)))),
      _stepDot(2, _step >= 1, 'Task'),
    ]),
  );

  Widget _stepDot(int n, bool active, String label) => Column(mainAxisSize: MainAxisSize.min, children: [
    AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: active ? _accentColor : Colors.grey.shade200, shape: BoxShape.circle,
            boxShadow: active ? [BoxShadow(color: _accentColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0,3))] : []),
        child: Center(child: active && n == 1 && _step == 1
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
            : Text('$n', style: TextStyle(color: active ? Colors.white : Colors.grey.shade400, fontWeight: FontWeight.bold, fontSize: 13)))),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? _accentColor : Colors.grey.shade400)),
  ]);

  Widget _pickStep() => _mode == 'individual' ? _individualPick() : _teamPick();

  Widget _individualPick() => Column(children: [
    Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(16,0,16,12), child: Column(children: [
      TextField(
        controller: _searchCtrl, onChanged: (_) => _loadStaff(),
        decoration: InputDecoration(
            hintText: 'Search by name…',
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _searchCtrl.clear(); _loadStaff(); }) : null,
            filled: true, fillColor: AppTheme.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12)),
      ),
      const SizedBox(height: 10),
      Row(children: ['all','intern','employee'].map((r) {
        final sel = _roleFilter == r;
        return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
            onTap: () { setState(() => _roleFilter = r); _loadStaff(); },
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: sel ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade300)),
                child: Text(r == 'all' ? 'All' : r[0].toUpperCase() + r.substring(1),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : Colors.grey.shade600)))));
      }).toList()),
    ])),
    Expanded(child: _loadingStaff
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : _staff.isEmpty
        ? _emptyPick('No staff found', 'Try a different search or filter')
        : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16,8,16,100),
        itemCount: _staff.length,
        itemBuilder: (_, i) => _staffCard(_staff[i]))),
    if (_selectedStaff != null) _continueFooter(
        label: 'Continue with ${_selectedStaff!.fullName.split(' ').first}',
        onTap: () => setState(() => _step = 1)),
  ]);

  Widget _staffCard(StaffProfile s) {
    final sel = _selectedStaff?.id == s.id;
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: GestureDetector(
      onTap: () => setState(() => _selectedStaff = sel ? null : s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: sel ? AppTheme.primary.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade100, width: sel ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0,2))]),
        child: Row(children: [
          Container(width: 48, height: 48,
              decoration: BoxDecoration(gradient: AppTheme.avatarGradient(s.fullName), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: sel ? AppTheme.primary : const Color(0xFF1A1A2E))),
            const SizedBox(height: 2),
            Text([s.isIntern ? 'Intern' : 'Employee', if (s.department.isNotEmpty) s.department].join(' · '),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ])),
          AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 26, height: 26,
              decoration: BoxDecoration(color: sel ? AppTheme.primary : Colors.transparent, shape: BoxShape.circle,
                  border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade300, width: 2)),
              child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
        ]),
      ),
    ));
  }

  Widget _teamPick() => Column(children: [
    Expanded(child: _loadingTeams
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : _teams.isEmpty
        ? _emptyPick('No teams yet', 'Create a team first from the Teams tab')
        : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16,12,16,100),
        itemCount: _teams.length,
        itemBuilder: (_, i) => _teamCard(_teams[i] as Map<String, dynamic>))),
    if (_selectedTeam != null) _continueFooter(
        label: 'Assign to Team ${_selectedTeam!['name']}',
        onTap: () => setState(() => _step = 1)),
  ]);

  Widget _teamCard(Map<String, dynamic> team) {
    final sel     = _selectedTeam?['id'] == team['id'];
    final members = (team['members'] as List? ?? []);
    final colors  = [AppTheme.primary, AppTheme.secondary, const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFF0D9488)];
    final color   = colors[(team['name'] as String).codeUnitAt(0) % colors.length];

    return Padding(padding: const EdgeInsets.only(bottom: 12), child: GestureDetector(
      onTap: () => setState(() => _selectedTeam = sel ? null : team),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel ? color : Colors.grey.shade100, width: sel ? 2 : 1),
            boxShadow: [BoxShadow(color: sel ? color.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0,3))]),
        child: Row(children: [
          Container(width: 52, height: 52,
              decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color, color.withValues(alpha: 0.7)]),
                  borderRadius: BorderRadius.circular(14)),
              alignment: Alignment.center,
              child: Text((team['name'] as String)[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(team['name'] as String, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: sel ? color : const Color(0xFF1A1A2E))),
            if ((team['department'] as String? ?? '').isNotEmpty)
              Text(team['department'] as String, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            Row(children: [
              ...members.take(5).map<Widget>((m) {
                final mname = (m['username'] as String? ?? '?');
                return Container(
                    width: 26, height: 26, margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(gradient: AppTheme.avatarGradient(mname), shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)),
                    alignment: Alignment.center,
                    child: Text(mname[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)));
              }),
              if (members.length > 5) Text(' +${members.length-5}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(width: 8),
              Text('${members.length} member${members.length != 1 ? 's' : ''}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('Shared', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
            const SizedBox(height: 8),
            AnimatedContainer(duration: const Duration(milliseconds: 180),
                width: 26, height: 26,
                decoration: BoxDecoration(color: sel ? color : Colors.transparent, shape: BoxShape.circle,
                    border: Border.all(color: sel ? color : Colors.grey.shade300, width: 2)),
                child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null),
          ]),
        ]),
      ),
    ));
  }

  Widget _taskStep() {
    final isTeam = _mode == 'team';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Assignee chip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_accentColor.withValues(alpha: 0.08), _accentColor.withValues(alpha: 0.02)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentColor.withValues(alpha: 0.2))),
          child: Row(children: [
            isTeam
                ? Container(width: 44, height: 44,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [_accentColor, _accentColor.withValues(alpha: 0.7)]),
                    borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text((_selectedTeam!['name'] as String)[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))
                : Container(width: 44, height: 44,
                decoration: BoxDecoration(gradient: AppTheme.avatarGradient(_selectedStaff!.fullName), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(_selectedStaff!.fullName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(isTeam ? '👥 Team Task' : '👤 Individual Task',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _accentColor))),
              const SizedBox(height: 4),
              Text(isTeam ? (_selectedTeam!['name'] as String) : _selectedStaff!.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              if (isTeam)
                Text('${(_selectedTeam!['members'] as List? ?? []).length} members will see this task',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
              else
                Text('${_selectedStaff!.isIntern ? "Intern" : "Employee"}${_selectedStaff!.department.isNotEmpty ? " · ${_selectedStaff!.department}" : ""}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ])),
            TextButton(onPressed: () => setState(() => _step = 0),
                style: TextButton.styleFrom(foregroundColor: _accentColor),
                child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold))),
          ]),
        ),
        const SizedBox(height: 14),

        // Board & Column
        if (_boards.isNotEmpty) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0,3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.dashboard_rounded, color: AppTheme.primary, size: 16)),
              const SizedBox(width: 8),
              const Text('Board & Starting Column', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
            ]),
            const SizedBox(height: 12),
            const Text('Starting column', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8,
                children: ((_selectedBoard?['columns'] as List? ?? [])).map<Widget>((c) {
                  final sel = _selectedColumnId == c['id'];
                  return GestureDetector(
                      onTap: () => setState(() => _selectedColumnId = c['id']),
                      child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: sel ? AppTheme.primary : AppTheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? AppTheme.primary : Colors.grey.shade200)),
                          child: Text(c['name'] ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : Colors.grey.shade600))));
                }).toList()),
          ]),
        ),
        const SizedBox(height: 14),

        // Task info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0,3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppTheme.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.task_alt_rounded, color: AppTheme.secondary, size: 16)),
              const SizedBox(width: 8),
              const Text('Task Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
            ]),
            const SizedBox(height: 14),
            TextFormField(controller: _titleCtrl,
                decoration: InputDecoration(labelText: 'Task Title *',
                    prefixIcon: const Icon(Icons.edit_rounded, size: 18), prefixIconColor: AppTheme.primary,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14))),
            const SizedBox(height: 12),
            TextFormField(controller: _descCtrl, maxLines: 3,
                decoration: InputDecoration(labelText: 'Description (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14))),
            const SizedBox(height: 12),
            const Text('Priority', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(children: [
              _pChip('low',    'Low',    const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _pChip('medium', 'Medium', AppTheme.primary),
              const SizedBox(width: 8),
              _pChip('high',   'High',   AppTheme.secondary),
              const SizedBox(width: 8),
              _pChip('urgent', 'Urgent', const Color(0xFFEF4444)),
            ]),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context,
                    initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(), lastDate: DateTime(2030));
                if (d != null) setState(() => _dueDate = d);
              },
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _dueDate != null ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _dueDate != null ? AppTheme.primary.withValues(alpha: 0.3) : Colors.grey.shade200)),
                  child: Row(children: [
                    Icon(Icons.calendar_today_rounded, size: 18, color: _dueDate != null ? AppTheme.primary : Colors.grey.shade400),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_dueDate != null ? 'Due: ${_fmt(_dueDate!)}' : 'Set due date (optional)',
                        style: TextStyle(fontSize: 13, color: _dueDate != null ? AppTheme.primary : Colors.grey.shade400,
                            fontWeight: _dueDate != null ? FontWeight.bold : FontWeight.normal))),
                    if (_dueDate != null) GestureDetector(onTap: () => setState(() => _dueDate = null),
                        child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade400)),
                  ])),
            ),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.error.withValues(alpha: 0.25))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
              ])),
        ],

        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 54, child: Material(
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _saving ? null : _assign,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isTeam
                      ? [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)]
                      : [AppTheme.secondary, const Color(0xFFE07B0A)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: _accentColor.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0,6))]),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(isTeam ? Icons.groups_rounded : Icons.send_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(isTeam ? 'Assign to Team' : 'Assign Task',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        )),
        const SizedBox(height: 30),
      ]),
    );
  }

  Widget _pChip(String value, String label, Color color) {
    final sel = _priority == value;
    return Expanded(child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: sel ? color : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? color : color.withValues(alpha: 0.2))),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? Colors.white : color)))));
  }

  Widget _continueFooter({required String label, required VoidCallback onTap}) => Container(
    padding: const EdgeInsets.fromLTRB(16,12,16,20),
    decoration: BoxDecoration(color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0,-4))]),
    child: SafeArea(top: false, child: SizedBox(height: 52, child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(backgroundColor: _accentColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_mode == 'team' ? Icons.groups_rounded : Icons.arrow_forward_rounded, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    ))),
  );

  Widget _emptyPick(String title, String sub) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 80, height: 80,
        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.primary)),
    const SizedBox(height: 14),
    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    Text(sub, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
  ]));
}
