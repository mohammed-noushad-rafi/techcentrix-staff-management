import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme.dart';
import 'staff_list_screen.dart';
import 'create_staff_screen.dart';
import 'team_list_screen.dart';
import 'assign_task_screen.dart';
import 'pending_verification_screen.dart';
import '../attendance/admin_attendance_screen.dart';
import '../shared/notifications_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  int _currentIndex = 0;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await context.read<AppState>().api.getAdminDashboard();
      setState(() { _stats = data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: [
        _homeTab(),
        const StaffListScreen(),
        const TeamListScreen(),
        const AdminAttendanceScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'Staff'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Teams'),
          NavigationDestination(icon: Icon(Icons.fingerprint_outlined), selectedIcon: Icon(Icons.fingerprint), label: 'Attendance'),
        ],
      ),
    );
  }

  Widget _homeTab() {
    final unread = _stats?['unread_notifications'] ?? 0;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHero(unread)),
            if (_loading)
              const SliverToBoxAdapter(child: SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))))
            else ...[
              if ((_stats?['pending_verification'] ?? 0) > 0)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,16,16,0), child: _pendingBanner())),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,20,16,0), child: _buildStats())),
              if ((_stats?['staff_by_department'] as Map?)?.isNotEmpty ?? false)
                SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,20,16,0), child: _buildDept())),
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,20,16,24), child: _buildActions())),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero(int unread) {
    final name = context.read<AppState>().displayName.split(' ').first;
    final totalStaff = _stats?['total_staff'] ?? 0;
    final pending    = _stats?['pending_verification'] ?? 0;
    final teams      = _stats?['total_teams'] ?? 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(20,12,20,24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain)),
            const SizedBox(width: 10),
            const Text('techCentrix', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Stack(children: [
              IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _load())),
              if (unread > 0) Positioned(right: 8, top: 8, child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(color: Color(0xFFF7941D), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
            ]),
            IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: () => context.read<AppState>().logout()),
          ]),
          const SizedBox(height: 18),
          Text('Good ${_greeting()}, $name 👋', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(children: [
            _heroPill('$totalStaff', 'Total Staff', Icons.people_rounded),
            const SizedBox(width: 10),
            _heroPill('$teams', 'Teams', Icons.groups_rounded),
            const SizedBox(width: 10),
            _heroPill('$pending', 'Pending', Icons.pending_actions_rounded,
                color: pending > 0 ? const Color(0xFFF7941D) : Colors.white),
          ]),
        ]),
      )),
    );
  }

  Widget _heroPill(String value, String label, IconData icon, {Color color = Colors.white}) =>
    Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, height: 1)),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.75), fontSize: 10)),
        ]),
      ]),
    ));

  Widget _pendingBanner() => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingVerificationScreen())).then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA))),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFF7941D).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.pending_actions_rounded, color: Color(0xFFF7941D), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_stats!['pending_verification']} task(s) awaiting verification',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF92400E))),
            const Text('Tap to review and approve', style: TextStyle(fontSize: 11, color: Color(0xFFB45309))),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFF7941D)),
        ]),
      ),
    ),
  );

  Widget _buildStats() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      const Text('Overview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      _statCard('Interns',   '${_stats?['total_interns']   ?? 0}', Icons.school_rounded,      const Color(0xFF1B9CD8)),
      const SizedBox(width: 10),
      _statCard('Employees', '${_stats?['total_employees'] ?? 0}', Icons.work_rounded,         const Color(0xFF10B981)),
      const SizedBox(width: 10),
      _statCard('Active',    '${_stats?['active_staff']    ?? 0}', Icons.check_circle_rounded, const Color(0xFF8B5CF6)),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      _statCard('Tasks',     '${_stats?['total_tasks']     ?? 0}', Icons.task_alt_rounded,     const Color(0xFFF7941D)),
      const SizedBox(width: 10),
      _statCard('Done',      '${_stats?['completed_tasks'] ?? 0}', Icons.done_all_rounded,     const Color(0xFF10B981)),
      const SizedBox(width: 10),
      _statCard('Overdue',   '${_stats?['overdue_tasks']   ?? 0}', Icons.warning_rounded,      const Color(0xFFEF4444)),
    ]),
  ]);

  Widget _statCard(String label, String value, IconData icon, Color color) =>
    Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color, height: 1)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ]),
    ));

  Widget _buildDept() {
    final depts  = _stats!['staff_by_department'] as Map;
    final total  = (_stats!['total_staff'] as int).clamp(1, 999);
    final colors = [AppTheme.primary, AppTheme.secondary, const Color(0xFF10B981), const Color(0xFF8B5CF6), const Color(0xFFEF4444)];
    int idx = 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 16, decoration: BoxDecoration(color: AppTheme.secondary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('Staff by Department', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        ]),
        const SizedBox(height: 14),
        ...depts.entries.map((e) {
          final color = colors[idx++ % colors.length];
          final pct   = (e.value as int) / total;
          return Padding(padding: const EdgeInsets.only(bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF374151)))),
              Text('${e.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: pct, minHeight: 6,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation(color))),
          ]));
        }),
      ]),
    );
  }

  Widget _buildActions() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      const Text('Quick Actions', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      _actionCard('Add Staff',    Icons.person_add_rounded,      AppTheme.primary,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateStaffScreen())).then((_) => _load())),
      const SizedBox(width: 10),
      _actionCard('Assign Task',  Icons.assignment_rounded,  AppTheme.secondary,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssignTaskScreen())).then((_) => _load())),
    ]),
    const SizedBox(height: 10),
    Row(children: [
      _actionCard('Verify Tasks', Icons.verified_rounded,        const Color(0xFF8B5CF6),
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingVerificationScreen())).then((_) => _load())),
      const SizedBox(width: 10),
      _actionCard('Attendance',   Icons.fingerprint_rounded,     const Color(0xFF10B981),
          () => setState(() => _currentIndex = 3)),
    ]),
  ]);

  Widget _actionCard(String label, IconData icon, Color color, VoidCallback onTap) =>
    Expanded(child: Material(
      color: Colors.white, borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)]),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13))),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: color.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    ));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}
