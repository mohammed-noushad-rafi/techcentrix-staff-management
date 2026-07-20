import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import 'attendance_report_screen.dart';
import 'office_location_screen.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});
  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _today;
  List<dynamic> _pendingLeaves = [];
  bool _loadingToday = true, _loadingLeaves = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async { _loadToday(); _loadLeaves(); }

  Future<void> _loadToday() async {
    setState(() => _loadingToday = true);
    try {
      final d = await context.read<AppState>().api.getAdminToday();
      setState(() { _today = d; _loadingToday = false; });
    } catch (_) { setState(() => _loadingToday = false); }
  }

  Future<void> _loadLeaves() async {
    setState(() => _loadingLeaves = true);
    try {
      final raw = await context.read<AppState>().api.getPendingLeaves();
      setState(() { _pendingLeaves = raw; _loadingLeaves = false; });
    } catch (_) { setState(() => _loadingLeaves = false); }
  }


  Future<void> _showReportSelector() async {
    final raw = await context.read<AppState>().api.searchStaff();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Text('Generate Attendance Report',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            itemCount: raw.length,
            itemBuilder: (ctx, i) {
              final s = raw[i] as Map<String, dynamic>;
              final uid  = (s['user']?['id'] ?? 0) as int;
              final name = (s['full_name'] ?? '') as String;
              final dept = (s['department'] ?? '') as String;
              final role = (s['user']?['role'] ?? '') as String;
              return ListTile(
                leading: Container(width: 40, height: 40,
                  decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('${role[0].toUpperCase()}${role.substring(1)}${dept.isNotEmpty ? " · $dept" : ""}',
                    style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.primary),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      AttendanceReportScreen(staffId: uid, staffName: name)));
                },
              );
            }),
        ]),
      ),
    );
  }

  Future<void> _markAbsentNow() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.person_off_rounded, color: AppTheme.error, size: 20)),
        const SizedBox(width: 12),
        const Text('Mark Absent?'),
      ]),
      content: const Text('Staff who haven\'t checked in and whose grace period has passed will be marked Absent.\n\nStaff on approved Leave or Holiday won\'t be affected.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark Absent')),
      ],
    ));
    if (confirm != true) return;
    try {
      await context.read<AppState>().api.markAbsentNow();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.check_rounded, color: Colors.white, size: 16), SizedBox(width: 8), Text('Absent marking complete')]),
          backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
        _loadToday();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error));
    }
  }

  Future<void> _showOverrideDialog() async {
    final raw = await context.read<AppState>().api.searchStaff();
    if (!mounted) return;
    int? selectedUserId;
    String selectedStatus = 'present';
    final noteCtrl = TextEditingController();
    await showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Manual Override'),
      content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(
          decoration: InputDecoration(labelText: 'Staff member', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          hint: const Text('Select staff'),
          items: raw.map<DropdownMenuItem<int>>((s) => DropdownMenuItem(
            value: (s['user']?['id'] ?? 0) as int,
            child: Text(s['full_name'] ?? ''))).toList(),
          onChanged: (v) => set(() => selectedUserId = v),
        ),
        const SizedBox(height: 12),
        const Text('Mark as', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _statusChip(ctx, set, selectedStatus, 'present',  'Present',  AppTheme.success,       (v) => set(() => selectedStatus = v)),
          _statusChip(ctx, set, selectedStatus, 'absent',   'Absent',   AppTheme.error,         (v) => set(() => selectedStatus = v)),
          _statusChip(ctx, set, selectedStatus, 'late',     'Late',     AppTheme.warning,       (v) => set(() => selectedStatus = v)),
          _statusChip(ctx, set, selectedStatus, 'leave',    'Leave',    AppTheme.info,          (v) => set(() => selectedStatus = v)),
          _statusChip(ctx, set, selectedStatus, 'holiday',  'Holiday',  const Color(0xFF8B5CF6),(v) => set(() => selectedStatus = v)),
          _statusChip(ctx, set, selectedStatus, 'wfh',      'WFH',      const Color(0xFF0D9488),(v) => set(() => selectedStatus = v)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: noteCtrl,
          decoration: InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: selectedUserId == null ? null : () async {
            final today = DateTime.now();
            final d = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
            await context.read<AppState>().api.adminOverrideAttendance(selectedUserId!, d, selectedStatus, notes: noteCtrl.text);
            if (ctx.mounted) Navigator.pop(ctx);
            _loadToday();
          },
          child: const Text('Save')),
      ],
    )));
  }

  Widget _statusChip(BuildContext ctx, StateSetter set, String current, String value, String label, Color color, ValueChanged<String> onTap) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.2))),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: sel ? Colors.white : color)),
      ),
    );
  }

  Future<void> _reviewLeave(int id, bool approve) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(approve ? 'Approve Leave' : 'Reject Leave'),
      content: TextField(controller: noteCtrl,
        decoration: InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(style: FilledButton.styleFrom(
          backgroundColor: approve ? AppTheme.success : AppTheme.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(approve ? 'Approve' : 'Reject')),
      ],
    ));
    if (ok == true) {
      if (approve) await context.read<AppState>().api.approveLeave(id, note: noteCtrl.text);
      else         await context.read<AppState>().api.rejectLeave(id, note: noteCtrl.text);
      _loadLeaves();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingLeaves.length;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverToBoxAdapter(child: _buildHero()),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabDelegate(TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: [
                const Tab(text: 'Today'),
                Tab(text: pendingCount > 0 ? 'Leave  ($pendingCount)' : 'Leave'),
              ],
            ), AppTheme.primary),
          ),
        ],
        body: TabBarView(controller: _tabs, children: [
          _todayTab(),
          _leavesTab(),
        ]),
      ),
    );
  }

  Widget _buildHero() {
    final t = _today ?? {};
    final date = t['date'] ?? _todayDate();
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Smart Presence', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text('Attendance Management', style: TextStyle(color: Colors.white60, fontSize: 12)),
            ])),
            IconButton(
            icon: const Icon(Icons.assessment_rounded, color: Colors.white),
            tooltip: 'Generate Report',
            onPressed: () => _showReportSelector(),
          ),
          IconButton(icon: const Icon(Icons.business_outlined, color: Colors.white),
              tooltip: 'Office Settings',
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfficeLocationScreen())).then((_) => _load())),
            IconButton(icon: const Icon(Icons.edit_calendar_outlined, color: Colors.white),
              tooltip: 'Override', onPressed: _showOverrideDialog),
            IconButton(icon: const Icon(Icons.person_off_outlined, color: Colors.white),
              tooltip: 'Mark Absent Now', onPressed: _markAbsentNow),
            IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white), onPressed: _load),
          ]),
          const SizedBox(height: 16),

          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(date, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 14),

          // Stats row
          if (!_loadingToday) Row(children: [
            _heroStat('In Office', '${t['checked_in_count']  ?? 0}', AppTheme.success),
            _heroDivider(),
            _heroStat('Left',      '${t['checked_out_count'] ?? 0}', Colors.blue.shade200),
            _heroDivider(),
            _heroStat('Late',      '${t['late_count']        ?? 0}', AppTheme.warning),
            _heroDivider(),
            _heroStat('Leave',     '${t['on_leave_count']    ?? 0}', Colors.purple.shade200),
            _heroDivider(),
            _heroStat('Absent',    '${t['absent_count']      ?? 0}', Colors.red.shade300),
          ])
          else const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))),
        ]),
      )),
    );
  }

  Widget _heroStat(String label, String val, Color color) => Expanded(child: Column(children: [
    Text(val, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold, height: 1)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]));

  Widget _heroDivider() => Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.15), margin: const EdgeInsets.symmetric(horizontal: 4));

  // ── Today tab ───────────────────────────────────

  Widget _todayTab() {
    if (_loadingToday) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    final t = _today ?? {};
    final checkedIn  = t['checked_in']  as List? ?? [];
    final checkedOut = t['checked_out'] as List? ?? [];
    final late       = t['late']        as List? ?? [];
    final onLeave    = t['on_leave']    as List? ?? [];
    final absent     = t['absent']      as List? ?? [];
    final hasData    = checkedIn.isNotEmpty || checkedOut.isNotEmpty || late.isNotEmpty || onLeave.isNotEmpty || absent.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadToday,
      child: !hasData
          ? ListView(children: [_emptyToday()])
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
              if (checkedIn.isNotEmpty) ...[
                _groupHeader('In Office', checkedIn.length, AppTheme.success, Icons.business_rounded),
                ...checkedIn.map((r) => _attendanceTile(r as Map<String, dynamic>, AppTheme.success)),
                const SizedBox(height: 12),
              ],
              if (late.isNotEmpty) ...[
                _groupHeader('Late Arrivals', late.length, AppTheme.warning, Icons.watch_later_rounded),
                ...late.map((r) => _attendanceTile(r as Map<String, dynamic>, AppTheme.warning)),
                const SizedBox(height: 12),
              ],
              if (checkedOut.isNotEmpty) ...[
                _groupHeader('Checked Out', checkedOut.length, AppTheme.info, Icons.logout_rounded),
                ...checkedOut.map((r) => _attendanceTile(r as Map<String, dynamic>, AppTheme.info)),
                const SizedBox(height: 12),
              ],
              if (onLeave.isNotEmpty) ...[
                _groupHeader('On Leave', onLeave.length, const Color(0xFF8B5CF6), Icons.event_busy_rounded),
                ...onLeave.map((r) => _attendanceTile(r as Map<String, dynamic>, const Color(0xFF8B5CF6))),
                const SizedBox(height: 12),
              ],
              if (absent.isNotEmpty) ...[
                _groupHeader('Absent', absent.length, AppTheme.error, Icons.person_off_rounded),
                ...absent.map((r) => _attendanceTile(r as Map<String, dynamic>, AppTheme.error)),
                const SizedBox(height: 12),
              ],
            ]),
    );
  }

  Widget _groupHeader(String title, int count, Color color, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 14)),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
    ]),
  );

  Widget _attendanceTile(Map<String, dynamic> r, Color color) {
    final name = (r['full_name'] ?? r['user']?['username'] ?? '') as String;
    final checkIn  = r['check_in_time']?.toString().substring(0,5);
    final checkOut = r['check_out_time']?.toString().substring(0,5);
    final lateMin  = r['late_minutes'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          if (lateMin > 0) Text('$lateMin min late', style: const TextStyle(fontSize: 11, color: AppTheme.warning)),
        ])),
        if (checkIn != null) Row(mainAxisSize: MainAxisSize.min, children: [
          _timeChip(Icons.login_rounded, checkIn, color.withValues(alpha: 0.1), color),
          if (checkOut != null) ...[
            const SizedBox(width: 6),
            _timeChip(Icons.logout_rounded, checkOut, Colors.grey.shade100, Colors.grey.shade600),
          ],
        ]),
      ]),
    );
  }

  Widget _timeChip(IconData icon, String time, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: fg),
      const SizedBox(width: 4),
      Text(time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    ]),
  );

  Widget _emptyToday() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 90, height: 90,
        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.people_outline_rounded, size: 44, color: AppTheme.primary)),
      const SizedBox(height: 18),
      const Text('No attendance yet today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Text('Records appear as staff check in.\nTap the 👤✕ button to mark absents.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _markAbsentNow,
        icon: const Icon(Icons.person_off_rounded, size: 16),
        label: const Text('Mark Absent Now'),
        style: FilledButton.styleFrom(backgroundColor: AppTheme.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]),
  );

  // ── Leave tab ───────────────────────────────────

  Widget _leavesTab() {
    if (_loadingLeaves) return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    if (_pendingLeaves.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 90, height: 90,
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.event_available_rounded, size: 44, color: AppTheme.success)),
      const SizedBox(height: 16),
      const Text('All clear!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 6),
      Text('No pending leave requests', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
    ]));

    return RefreshIndicator(
      onRefresh: _loadLeaves,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingLeaves.length,
        itemBuilder: (_, i) {
          final l    = _pendingLeaves[i] as Map<String, dynamic>;
          final name = (l['full_name'] ?? '') as String;
          final type = l['leave_type_display'] ?? '';
          final days = l['days_requested'] ?? 1;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Column(children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 44, height: 44,
                    decoration: BoxDecoration(gradient: AppTheme.avatarGradient(name), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(type, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.warning))),
                      const SizedBox(width: 6),
                      Text('$days day${days > 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ]),
                  ])),
                ]),
              ),

              // Date range
              Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.surface, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.date_range_rounded, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('${l['from_date']}  →  ${l['to_date']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                ]),
              ),

              if ((l['reason'] ?? '').isNotEmpty) Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.notes_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l['reason'], style: TextStyle(fontSize: 12, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                ]),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => _reviewLeave(l['id'], false),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(
                    onPressed: () => _reviewLeave(l['id'], true),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.success,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  )),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }

  String _todayDate() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }
}

class _TabDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color color;
  const _TabDelegate(this.tabBar, this.color);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(_, __, ___) => Container(color: color, child: tabBar);

  @override
  bool shouldRebuild(_TabDelegate old) => old.tabBar != tabBar;
}
