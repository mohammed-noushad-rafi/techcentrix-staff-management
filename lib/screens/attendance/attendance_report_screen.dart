import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

class AttendanceReportScreen extends StatefulWidget {
  final int? staffId;
  final String? staffName;
  const AttendanceReportScreen({super.key, this.staffId, this.staffName});
  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate   = DateTime.now();
  String _preset     = 'this_month';
  Map<String, dynamic>? _data;
  bool _loading      = false;
  bool _downloading  = false;
  String? _error;

  @override
  void initState() { super.initState(); _generate(); }

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  String _display(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  void _applyPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'this_month':
          _fromDate = DateTime(now.year, now.month, 1);
          _toDate   = now;
          break;
        case 'last_month':
          final lm = DateTime(now.year, now.month - 1, 1);
          _fromDate = lm;
          _toDate   = DateTime(now.year, now.month, 0);
          break;
        case 'this_week':
          _fromDate = now.subtract(Duration(days: now.weekday - 1));
          _toDate   = now;
          break;
        case 'last_7':
          _fromDate = now.subtract(const Duration(days: 6));
          _toDate   = now;
          break;
        case 'last_30':
          _fromDate = now.subtract(const Duration(days: 29));
          _toDate   = now;
          break;
      }
    });
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<AppState>().api;
      final result = await api.getAttendanceReport(
        staffId:  widget.staffId,
        fromDate: _fmt(_fromDate),
        toDate:   _fmt(_toDate),
      );
      setState(() { _data = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _downloadPDF() async {
    setState(() => _downloading = true);
    try {
      final api = context.read<AppState>().api;
      await api.downloadAttendanceReportPDF(
        staffId:  widget.staffId,
        fromDate: _fmt(_fromDate),
        toDate:   _fmt(_toDate),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('PDF downloaded!'),
        ]),
        backgroundColor: AppTheme.success, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [

        // ── Header ──────────────────────────────────
        SliverToBoxAdapter(child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context)),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Attendance Report', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(widget.staffName ?? 'My Report',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                if (!_loading && _data != null)
                  TextButton.icon(
                    onPressed: _downloading ? null : _downloadPDF,
                    icon: _downloading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 18),
                    label: const Text('PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
              ]),
              const SizedBox(height: 16),

              // Period chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _presetChip('this_month', 'This Month'),
                  _presetChip('last_month', 'Last Month'),
                  _presetChip('this_week',  'This Week'),
                  _presetChip('last_7',     'Last 7 Days'),
                  _presetChip('last_30',    'Last 30 Days'),
                  _customDateChip(),
                ]),
              ),
              const SizedBox(height: 8),
              Text('${_display(_fromDate)}  →  ${_display(_toDate)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          )),
        )),

        if (_loading)
          const SliverToBoxAdapter(child: SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))))
        else if (_error != null)
          SliverToBoxAdapter(child: _errorWidget())
        else if (_data != null) ...[

          // ── Summary stats ──────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _summarySection(),
          )),

          // ── Attendance ring ────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _attendanceRing(),
          )),

          // ── Daily table ────────────────────────────
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _dailyTable(),
          )),
        ],
      ]),
    );
  }

  Widget _presetChip(String value, String label) {
    final sel = _preset == value;
    return GestureDetector(
      onTap: () => _applyPreset(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? Colors.white : Colors.white.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: sel ? AppTheme.primary : Colors.white)),
      ),
    );
  }

  Widget _customDateChip() => GestureDetector(
    onTap: () async {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: AppTheme.primary)),
          child: child!),
      );
      if (range != null) {
        setState(() { _preset = 'custom'; _fromDate = range.start; _toDate = range.end; });
        _generate();
      }
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _preset == 'custom' ? Colors.white : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _preset == 'custom' ? Colors.white : Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.date_range_rounded, size: 14,
            color: _preset == 'custom' ? AppTheme.primary : Colors.white),
        const SizedBox(width: 6),
        Text('Custom', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: _preset == 'custom' ? AppTheme.primary : Colors.white)),
      ]),
    ),
  );

  Widget _summarySection() {
    final s = _data!['summary'] as Map;
    final p = _data!['period']  as Map;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        const Text('Summary', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const Spacer(),
        Text('${p['working_days']} working days', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9,
        children: [
          _statCard('Present',   '${s['present']}',       AppTheme.success,  Icons.check_circle_rounded),
          _statCard('Late',      '${s['late']}',          AppTheme.warning,  Icons.watch_later_rounded),
          _statCard('Absent',    '${s['absent']}',        AppTheme.error,    Icons.cancel_rounded),
          _statCard('Leave',     '${s['leave']}',         AppTheme.info,     Icons.event_busy_rounded),
          _statCard('WFH',       '${s['wfh']}',           const Color(0xFF0D9488), Icons.home_work_rounded),
          _statCard('Holiday',   '${s['holiday']}',       const Color(0xFF8B5CF6), Icons.celebration_rounded),
          _statCard('Tot. Hrs',  '${s['total_hours']}h',  const Color(0xFF0369A1), Icons.timer_rounded),
          _statCard('Avg Hrs',   '${s['avg_hours']}h',    const Color(0xFF7C3AED), Icons.schedule_rounded),
        ],
      ),
    ]);
  }

  Widget _statCard(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Container(padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 14)),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, height: 1)),
      Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _attendanceRing() {
    final s   = _data!['summary'] as Map;
    final pct = (s['attendance_pct'] as num).toDouble();
    final color = pct >= 90 ? AppTheme.success : pct >= 75 ? AppTheme.warning : AppTheme.error;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Row(children: [
        // Ring
        SizedBox(width: 100, height: 100, child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 100, height: 100, child: CircularProgressIndicator(
            value: pct / 100, strokeWidth: 10,
            color: color, backgroundColor: color.withValues(alpha: 0.1))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$pct%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const Text('Present', style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
          ]),
        ])),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            pct >= 90 ? '🌟 Excellent Attendance!' : pct >= 75 ? '👍 Good Attendance' : '⚠ Needs Improvement',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          const SizedBox(height: 8),
          _barRow('Present + Late', (s['present'] as int) + (s['late'] as int), _data!['period']['working_days'] as int, AppTheme.success),
          const SizedBox(height: 6),
          _barRow('Late Arrivals', s['late'] as int, _data!['period']['working_days'] as int, AppTheme.warning),
          const SizedBox(height: 6),
          _barRow('Absent', s['absent'] as int, _data!['period']['working_days'] as int, AppTheme.error),
          if ((s['total_late_min'] as int) > 0) ...[
            const SizedBox(height: 8),
            Text('Total late time: ${s['total_late_min']} minutes',
                style: const TextStyle(fontSize: 11, color: AppTheme.warning, fontWeight: FontWeight.w600)),
          ],
        ])),
      ]),
    );
  }

  Widget _barRow(String label, int value, int total, Color color) {
    final pct = total == 0 ? 0.0 : value / total;
    return Row(children: [
      SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)))),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: pct, minHeight: 6,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation(color)))),
      const SizedBox(width: 8),
      Text('$value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _dailyTable() {
    final daily = (_data!['daily'] as List).cast<Map<String, dynamic>>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(color: AppTheme.secondary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        const Text('Daily Record', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
        const Spacer(),
        Text('${daily.length} days', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      ]),
      const SizedBox(height: 12),

      // Table header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF0E6FA3)]),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Row(children: const [
          Expanded(flex:3, child: Text('Date', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex:3, child: Text('Status', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
          Expanded(flex:2, child: Text('In', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex:2, child: Text('Out', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          Expanded(flex:2, child: Text('Hrs', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        ]),
      ),

      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))]),
        child: Column(children: daily.asMap().entries.map((entry) {
          final i   = entry.key;
          final row = entry.value;
          final color = _statusColor(row['status'] as String);
          final isWeekend = row['is_weekend'] as bool;
          final isFuture  = row['status'] == 'future';

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isWeekend ? const Color(0xFFF8FAFC)
                  : isFuture  ? Colors.white
                  : color.withValues(alpha: 0.04),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFF3F4F6),
                    width: i == daily.length - 1 ? 0 : 1),
                left: BorderSide(color: isWeekend || isFuture ? Colors.transparent : color, width: 3),
              ),
              borderRadius: i == daily.length - 1
                  ? const BorderRadius.vertical(bottom: Radius.circular(12))
                  : BorderRadius.zero,
            ),
            child: Row(children: [
              Expanded(flex:3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(row['date'] as String, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: isWeekend ? Colors.grey.shade400 : const Color(0xFF1A1A2E))),
                Text(row['day'] as String, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ])),
              Expanded(flex:3, child: Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: isFuture || isWeekend ? Colors.grey.shade300 : color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(child: Text(
                  isWeekend ? 'Weekend' : row['status_display'] as String,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: isWeekend ? Colors.grey.shade400 : isFuture ? Colors.grey.shade400 : color),
                  overflow: TextOverflow.ellipsis)),
                if ((row['late_minutes'] as int) > 0) ...[
                  const SizedBox(width: 4),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text('+${row['late_minutes']}m', style: const TextStyle(fontSize: 9, color: AppTheme.warning, fontWeight: FontWeight.bold))),
                ],
              ])),
              Expanded(flex:2, child: Text(row['check_in'] as String,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.center)),
              Expanded(flex:2, child: Text(row['check_out'] as String,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600), textAlign: TextAlign.center)),
              Expanded(flex:2, child: Text(
                  row['total_hours'] != null ? '${row['total_hours']}h' : '—',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                      color: row['total_hours'] != null ? AppTheme.success : Colors.grey.shade300),
                  textAlign: TextAlign.center)),
            ]),
          );
        }).toList()),
      ),
    ]);
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'present':  return AppTheme.success;
      case 'late':     return AppTheme.warning;
      case 'absent':   return AppTheme.error;
      case 'leave':    return AppTheme.info;
      case 'wfh':      return const Color(0xFF0D9488);
      case 'holiday':  return const Color(0xFF8B5CF6);
      default:         return const Color(0xFF9CA3AF);
    }
  }

  Widget _errorWidget() => Padding(
    padding: const EdgeInsets.all(40),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
      const SizedBox(height: 12),
      Text(_error!, style: const TextStyle(color: AppTheme.error), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ])),
  );
}
