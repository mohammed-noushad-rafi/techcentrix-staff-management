import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import 'apply_leave_screen.dart';
import 'attendance_report_screen.dart';

class MyAttendanceScreen extends StatefulWidget {
  const MyAttendanceScreen({super.key});
  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int _month = DateTime.now().month;
  int _year  = DateTime.now().year;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await context.read<AppState>().api.getMyAttendance(month: _month, year: _year);
      setState(() { _data = d; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _prevMonth() { setState(() { _month--; if (_month < 1) { _month = 12; _year--; } }); _load(); }
  void _nextMonth() {
    final now = DateTime.now();
    if (_year > now.year || (_year == now.year && _month >= now.month)) return;
    setState(() { _month++; if (_month > 12) { _month = 1; _year++; } });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_rounded),
            tooltip: 'View Report',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceReportScreen())),
          ),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplyLeaveScreen())).then((_) => _load()),
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: const Text('Apply Leave'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(children: [
                  _buildSummaryHeader(cs),
                  _buildCalendar(cs),
                  _buildRecentList(cs),
                ]),
              ),
            ),
    );
  }

  Widget _buildSummaryHeader(ColorScheme cs) {
    final summary = _data?['summary'] as Map? ?? {};
    final streak  = summary['streak'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      color: cs.primary,
      child: Column(children: [
        if (streak > 0) ...[
          Text('🔥 $streak day streak!',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Keep it up!', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 14),
        ],
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _statBubble('Present',  '${summary['present'] ?? 0}',  Colors.green.shade300),
          _statBubble('Late',     '${summary['late'] ?? 0}',     Colors.orange.shade300),
          _statBubble('Absent',   '${summary['absent'] ?? 0}',   Colors.red.shade300),
          _statBubble('Leave',    '${summary['leave'] ?? 0}',    Colors.blue.shade300),
          if (summary['avg_hours'] != null)
            _statBubble('Avg Hrs', '${summary['avg_hours']}', Colors.purple.shade200),
        ]),
      ]),
    );
  }

  Widget _statBubble(String label, String val, Color color) => Column(children: [
    Container(
      width: 52, height: 52,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.25), shape: BoxShape.circle, border: Border.all(color: color)),
      alignment: Alignment.center,
      child: Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ),
    const SizedBox(height: 4),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
  ]);

  Widget _buildCalendar(ColorScheme cs) {
    final records = (_data?['records'] as List? ?? []);
    final recMap  = <String, Map<String, dynamic>>{};
    for (final r in records) {
      recMap[r['date'].toString()] = r as Map<String, dynamic>;
    }

    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final firstWeekday = DateTime(_year, _month, 1).weekday;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Month navigation
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
          Text('${months[_month - 1]} $_year',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
        ]),
        const SizedBox(height: 8),

        // Day headers
        Row(children: ['M','T','W','T','F','S','S'].map((d) => Expanded(child: Center(
          child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
        ))).toList()),
        const SizedBox(height: 4),

        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
          itemCount: daysInMonth + firstWeekday - 1,
          itemBuilder: (_, i) {
            if (i < firstWeekday - 1) return const SizedBox.shrink();
            final day  = i - firstWeekday + 2;
            final dateStr = '$_year-${_month.toString().padLeft(2,'0')}-${day.toString().padLeft(2,'0')}';
            final rec  = recMap[dateStr];
            final today = DateTime.now();
            final isToday = day == today.day && _month == today.month && _year == today.year;
            final isFuture = DateTime(_year, _month, day).isAfter(today);
            return _DayCell(day: day, record: rec, isToday: isToday, isFuture: isFuture);
          },
        ),

        // Legend
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 6, children: [
          _legend('Present',  Colors.green),
          _legend('Late',     Colors.orange),
          _legend('Absent',   Colors.red),
          _legend('Leave',    Colors.blue),
          _legend('WFH',      Colors.teal),
          _legend('Holiday',  Colors.purple),
        ]),
      ]),
    );
  }

  Widget _legend(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);

  Widget _buildRecentList(ColorScheme cs) {
    final records = (_data?['records'] as List? ?? []).reversed.take(10).toList();
    if (records.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text('Recent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
      ...records.map((r) {
        final rec   = r as Map<String, dynamic>;
        final color = _statusColor(rec['status'] ?? '');
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(_statusIcon(rec['status'] ?? ''), color: color, size: 18),
          ),
          title: Text(rec['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(rec['status_display'] ?? '', style: TextStyle(color: color, fontSize: 12)),
          trailing: rec['check_in_time'] != null ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('In  ${rec['check_in_time']?.toString().substring(0,5)  ?? '–'}', style: const TextStyle(fontSize: 11)),
            Text('Out ${rec['check_out_time']?.toString().substring(0,5) ?? '–'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]) : null,
        );
      }),
      const SizedBox(height: 20),
    ]);
  }
}

class _DayCell extends StatelessWidget {
  final int day;
  final Map<String, dynamic>? record;
  final bool isToday, isFuture;
  const _DayCell({required this.day, this.record, required this.isToday, required this.isFuture});

  Color _color(String? s) {
    switch (s) {
      case 'present':  return Colors.green;
      case 'late':     return Colors.orange;
      case 'absent':   return Colors.red;
      case 'leave':    return Colors.blue;
      case 'wfh':      return Colors.teal;
      case 'half_day': return Colors.amber;
      case 'holiday':  return Colors.purple;
      default:         return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = record?['status'] as String?;
    final color  = _color(status);
    final lateMin = record?['late_minutes'] ?? 0;
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: status != null && !isFuture ? color.withValues(alpha: 0.15) : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday ? Theme.of(context).colorScheme.primary : (status != null && !isFuture ? color : Colors.transparent),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Stack(alignment: Alignment.center, children: [
        Text('$day', style: TextStyle(
          fontSize: 11,
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          color: isFuture ? Colors.grey.shade400 : (status != null ? color : null),
        )),
        if (lateMin > 0)
          Positioned(top: 2, right: 2, child: Container(width: 5, height: 5,
            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle))),
      ]),
    );
  }
}

Color _statusColor(String s) {
  switch (s) {
    case 'present':  return Colors.green;
    case 'late':     return Colors.orange;
    case 'absent':   return Colors.red;
    case 'leave':    return Colors.blue;
    case 'wfh':      return Colors.teal;
    default:         return Colors.grey;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'present':  return Icons.check_circle_outline;
    case 'late':     return Icons.watch_later_outlined;
    case 'absent':   return Icons.cancel_outlined;
    case 'leave':    return Icons.event_busy_outlined;
    case 'wfh':      return Icons.home_work_outlined;
    default:         return Icons.help_outline;
  }
}
