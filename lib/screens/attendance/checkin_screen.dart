import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> with SingleTickerProviderStateMixin {
  bool _loadingLocation = true;
  String? _locationError;
  Position? _position;
  bool? _withinRange;
  int? _distanceM, _radiusM;
  Map<String, dynamic>? _office, _todayRecord;
  bool _loadingRecord = true, _actionLoading = false;
  String? _actionMessage;
  bool _actionSuccess = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _init();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _init() async { await _loadTodayRecord(); await _getLocation(); }

  Future<void> _loadTodayRecord() async {
    try {
      final data = await context.read<AppState>().api.getMyAttendance();
      setState(() { _todayRecord = data['today']; _loadingRecord = false; });
    } catch (_) { setState(() => _loadingRecord = false); }
  }

  Future<void> _getLocation() async {
    setState(() { _loadingLocation = true; _locationError = null; });
    try {
      bool svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) { setState(() { _locationError = 'Location services are off. Enable GPS.'; _loadingLocation = false; }); return; }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) { setState(() { _locationError = 'Location permission denied. Enable in Settings.'; _loadingLocation = false; }); return; }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _position = pos);
      await _checkProximity(pos.latitude, pos.longitude);
    } catch (e) { setState(() { _locationError = 'Could not get location.'; _loadingLocation = false; }); }
  }

  Future<void> _checkProximity(double lat, double lng) async {
    setState(() => _loadingLocation = true);
    try {
      final data = await context.read<AppState>().api.checkNearby(lat, lng);
      setState(() {
        _withinRange = data['within_range'];
        _distanceM   = data['distance_m'];
        _radiusM     = data['radius_m'];
        _office      = data['office'];
        _loadingLocation = false;
      });
    } catch (e) { setState(() { _locationError = e.toString(); _loadingLocation = false; }); }
  }

  Future<void> _checkIn() async {
    if (_position == null) return;
    setState(() { _actionLoading = true; _actionMessage = null; });
    try {
      final data = await context.read<AppState>().api.checkIn(_position!.latitude, _position!.longitude);
      setState(() { _todayRecord = data['record']; _actionMessage = data['detail']; _actionSuccess = true; _actionLoading = false; });
    } catch (e) { setState(() { _actionMessage = e.toString(); _actionSuccess = false; _actionLoading = false; }); }
  }

  Future<void> _checkOut() async {
    if (_position == null) return;
    setState(() { _actionLoading = true; _actionMessage = null; });
    try {
      final data = await context.read<AppState>().api.checkOut(_position!.latitude, _position!.longitude);
      setState(() { _todayRecord = data['record']; _actionMessage = data['detail']; _actionSuccess = true; _actionLoading = false; });
    } catch (e) { setState(() { _actionMessage = e.toString(); _actionSuccess = false; _actionLoading = false; }); }
  }

  String _timeNow() {
    final t = TimeOfDay.now();
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  String _dateNow() {
    final d = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final rec         = _todayRecord;
    final checkedIn   = rec?['check_in_time'] != null;
    final checkedOut  = rec?['check_out_time'] != null;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            title: const Text('Smart Presence'),
            actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _init)],
          ),
          SliverToBoxAdapter(child: RefreshIndicator(
            onRefresh: _init,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(children: [

                // Date & time
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3730A3), Color(0xFF7C3AED)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_dateNow(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(_timeNow(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      if (_office != null) Text(
                        'Shift: ${_office!['shift_start']} – ${_office!['shift_end']}',
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ])),
                    if (_office != null) Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        const Icon(Icons.business_rounded, color: Colors.white, size: 20),
                        const SizedBox(height: 4),
                        Text(_office!['name'] ?? 'Office', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // Proximity ring
                if (_loadingLocation)
                  _loadingRing()
                else if (_locationError != null)
                  _errorCard()
                else
                  _proximityRing(),
                const SizedBox(height: 24),

                // Status card
                if (!_loadingRecord)
                  checkedOut ? _doneCard(rec!) : checkedIn ? _checkedInCard(rec!) : _notCheckedInCard(),
                const SizedBox(height: 16),

                // Action message
                if (_actionMessage != null) Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _actionSuccess ? AppTheme.success.withValues(alpha: 0.08) : AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _actionSuccess ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(_actionSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                        color: _actionSuccess ? AppTheme.success : AppTheme.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_actionMessage!,
                        style: TextStyle(color: _actionSuccess ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.w500))),
                  ]),
                ),

                const SizedBox(height: 16),

                // Action button
                if (!_loadingRecord && !checkedOut) _actionButton(checkedIn),
              ]),
            ),
          )),
        ],
      ),
    );
  }

  Widget _loadingRing() => SizedBox(height: 200, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const CircularProgressIndicator(color: AppTheme.primary),
    const SizedBox(height: 14),
    Text('Getting your location…', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
  ])));

  Widget _errorCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.error.withValues(alpha: 0.2))),
    child: Column(children: [
      const Icon(Icons.location_off_rounded, color: AppTheme.error, size: 40),
      const SizedBox(height: 10),
      Text(_locationError!, style: const TextStyle(color: AppTheme.error), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _getLocation, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Try Again'),
        style: FilledButton.styleFrom(backgroundColor: AppTheme.error, visualDensity: VisualDensity.compact)),
    ]),
  );

  Widget _proximityRing() {
    final inside   = _withinRange == true;
    final color    = inside ? AppTheme.success : AppTheme.error;
    final dist     = _distanceM ?? 0;
    final radius   = _radiusM ?? 100;
    final progress = inside ? 1.0 : (radius / (dist == 0 ? 1 : dist)).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(scale: inside ? _pulseAnim.value : 1.0, child: child),
      child: Container(
        width: 200, height: 200,
        alignment: Alignment.center,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: 200, height: 200,
            child: CircularProgressIndicator(value: progress, strokeWidth: 12,
              color: color, backgroundColor: color.withValues(alpha: 0.1))),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(inside ? Icons.location_on_rounded : Icons.location_off_rounded, color: color, size: 36)),
            const SizedBox(height: 8),
            Text(inside ? 'In Range ✓' : dist > 1000 ? '${(dist/1000).toStringAsFixed(1)}km away' : '${dist}m away',
                style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            Text(inside ? 'Ready to check in' : 'Need to be within ${radius}m',
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)), textAlign: TextAlign.center),
          ]),
        ]),
      ),
    );
  }

  Widget _notCheckedInCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.schedule_rounded, color: AppTheme.secondary, size: 24)),
      const SizedBox(width: 14),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Not checked in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text('Tap the button below to check in', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
      ]),
    ]),
  );

  Widget _checkedInCard(Map<String, dynamic> rec) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.success.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
    ),
    child: Column(children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.login_rounded, color: AppTheme.success, size: 22)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Checked In', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
          Text(rec['check_in_time']?.toString().substring(0, 5) ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        const Spacer(),
        if ((rec['late_minutes'] ?? 0) > 0)
          StatusPill(label: '${rec['late_minutes']}m late', color: AppTheme.warning),
      ]),
    ]),
  );

  Widget _doneCard(Map<String, dynamic> rec) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF059669)]),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(children: [
      const Icon(Icons.task_alt_rounded, color: Colors.white, size: 40),
      const SizedBox(height: 8),
      const Text('Day Complete!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _timeChip('Check In',  rec['check_in_time']?.toString().substring(0, 5)  ?? '–', Icons.login_rounded),
        Container(width: 1, height: 40, color: Colors.white24),
        _timeChip('Check Out', rec['check_out_time']?.toString().substring(0, 5) ?? '–', Icons.logout_rounded),
        if (rec['total_hours'] != null) ...[
          Container(width: 1, height: 40, color: Colors.white24),
          _timeChip('Hours', '${rec['total_hours']}h', Icons.timer_rounded),
        ],
      ]),
    ]),
  );

  Widget _timeChip(String label, String val, IconData icon) => Column(children: [
    Icon(icon, color: Colors.white70, size: 16),
    const SizedBox(height: 4),
    Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);

  Widget _actionButton(bool checkedIn) {
    final within = _withinRange == true;
    final color  = checkedIn ? AppTheme.info : (within ? AppTheme.success : Colors.grey);
    final label  = checkedIn ? 'Check Out' : (within ? 'Check In Now' : 'Outside Office Range');
    final icon   = checkedIn ? Icons.logout_rounded : Icons.login_rounded;

    return SizedBox(width: double.infinity, height: 56,
      child: FilledButton.icon(
        onPressed: (_actionLoading || (!within && !checkedIn)) ? null : (checkedIn ? _checkOut : _checkIn),
        icon: _actionLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
