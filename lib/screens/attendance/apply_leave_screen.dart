import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});
  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  String _leaveType = 'casual';
  DateTime? _from, _to;
  final _reasonCtrl = TextEditingController();
  bool _loading = false, _submitted = false;
  String? _error;
  List<dynamic> _myLeaves = [];
  bool _loadingLeaves = true;

  @override
  void initState() { super.initState(); _loadLeaves(); }

  Future<void> _loadLeaves() async {
    setState(() => _loadingLeaves = true);
    try {
      final raw = await context.read<AppState>().api.getMyLeaves();
      setState(() { _myLeaves = raw; _loadingLeaves = false; });
    } catch (_) { setState(() => _loadingLeaves = false); }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  String _display(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday-1]}, ${m[d.month-1]} ${d.day}';
  }

  int get _days => (_from != null && _to != null && !_to!.isBefore(_from!))
      ? _to!.difference(_from!).inDays + 1 : 0;

  Future<void> _submit() async {
    if (_from == null || _to == null) {
      setState(() => _error = 'Please select start and end dates.'); return;
    }
    if (_to!.isBefore(_from!)) {
      setState(() => _error = 'End date must be after start date.'); return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please provide a reason.'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppState>().api.applyLeave({
        'leave_type': _leaveType,
        'from_date':  _fmt(_from!),
        'to_date':    _fmt(_to!),
        'reason':     _reasonCtrl.text.trim(),
      });
      setState(() { _submitted = true; _loading = false; });
      _loadLeaves();
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        // Header
        SliverToBoxAdapter(child: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 4),
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Leave Requests', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Apply for time off', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ]),
          )),
        )),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Apply form ────────────────────────────
            _submitted ? _successCard() : _applyForm(),

            const SizedBox(height: 24),

            // ── My leave history ──────────────────────
            if (_myLeaves.isNotEmpty) ...[
              Row(children: [
                Container(width: 3, height: 16,
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                const Text('My Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                const Spacer(),
                Text('${_myLeaves.length} total', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ]),
              const SizedBox(height: 12),
              if (_loadingLeaves)
                const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              else
                ..._myLeaves.map((l) => _leaveCard(l as Map<String, dynamic>)),
            ],
          ]),
        )),
      ]),
    );
  }

  Widget _successCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(children: [
      Container(width: 70, height: 70,
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 40)),
      const SizedBox(height: 14),
      const Text('Request Submitted!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 6),
      Text('Your admin will review and respond soon.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        onPressed: () => setState(() {
          _submitted = false; _from = null; _to = null;
          _reasonCtrl.clear(); _leaveType = 'casual';
        }),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Apply Another'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary, side: const BorderSide(color: AppTheme.primary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12)),
      )),
    ]),
  );

  Widget _applyForm() => Container(
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Form header
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(bottom: BorderSide(color: AppTheme.primary.withValues(alpha: 0.1))),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.event_available_rounded, color: AppTheme.primary, size: 16)),
          const SizedBox(width: 10),
          const Text('New Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
        ]),
      ),

      Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Leave type chips
        const Text('Leave Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _typeChip('sick',    'Sick Leave',    Icons.local_hospital_rounded,  const Color(0xFFEF4444)),
          _typeChip('casual',  'Casual Leave',  Icons.beach_access_rounded,    AppTheme.primary),
          _typeChip('earned',  'Earned Leave',  Icons.star_rounded,            const Color(0xFF8B5CF6)),
          _typeChip('wfh',     'Work From Home',Icons.home_work_rounded,       const Color(0xFF0D9488)),
          _typeChip('other',   'Other',         Icons.more_horiz_rounded,      Colors.grey),
        ]),
        const SizedBox(height: 18),

        // Date range
        const Text('Duration', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _datePicker('From', _from, (d) => setState(() { _from = d; if (_to != null && _to!.isBefore(d)) _to = null; }))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.grey.shade400)),
          Expanded(child: _datePicker('To', _to, (d) => setState(() => _to = d))),
        ]),

        // Days count
        if (_days > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.calendar_month_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text('$_days day${_days > 1 ? 's' : ''} requested',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
              const Spacer(),
              Text('${_display(_from!)} – ${_display(_to!)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ]),
          ),
        ],

        const SizedBox(height: 16),
        // Reason
        const Text('Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
        const SizedBox(height: 8),
        TextField(
          controller: _reasonCtrl, maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Briefly explain the reason for your leave…',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.25))),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
            ]),
          ),
        ],

        const SizedBox(height: 18),
        SizedBox(width: double.infinity, height: 50, child: Material(
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _loading ? null : _submit,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF0E6FA3)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.send_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('Submit Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
            ),
          ),
        )),
      ])),
    ]),
  );

  Widget _typeChip(String value, String label, IconData icon, Color color) {
    final sel = _leaveType == value;
    return GestureDetector(
      onTap: () => setState(() => _leaveType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color : color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? color : color.withValues(alpha: 0.2)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: sel ? Colors.white : color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
              color: sel ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _datePicker(String label, DateTime? value, ValueChanged<DateTime> onPicked) =>
    GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime(2030));
        if (d != null) onPicked(d);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value != null ? AppTheme.primary.withValues(alpha: 0.05) : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null ? AppTheme.primary.withValues(alpha: 0.3) : Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
              color: value != null ? AppTheme.primary : Colors.grey.shade400)),
          const SizedBox(height: 4),
          value != null
              ? Text(_display(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)))
              : Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text('Select date', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ]),
        ]),
      ),
    );

  Widget _leaveCard(Map<String, dynamic> l) {
    final status  = l['status'] ?? 'pending';
    final type    = l['leave_type'] ?? 'casual';
    final color   = status == 'approved' ? AppTheme.success
        : status == 'rejected' ? AppTheme.error : AppTheme.warning;
    final icon    = _leaveIcon(type);
    final typeColor = _typeColor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: typeColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l['leave_type_display'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 3),
            Text('${l['from_date']} → ${l['to_date']}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text('${l['days_requested']} day${(l['days_requested'] ?? 1) > 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Text(l['status_display'] ?? '',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
        ]),
      ),
    );
  }

  IconData _leaveIcon(String t) {
    switch (t) {
      case 'sick':   return Icons.local_hospital_rounded;
      case 'wfh':    return Icons.home_work_rounded;
      case 'earned': return Icons.star_rounded;
      case 'casual': return Icons.beach_access_rounded;
      default:       return Icons.event_busy_rounded;
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'sick':   return const Color(0xFFEF4444);
      case 'wfh':    return const Color(0xFF0D9488);
      case 'earned': return const Color(0xFF8B5CF6);
      default:       return AppTheme.primary;
    }
  }
}
