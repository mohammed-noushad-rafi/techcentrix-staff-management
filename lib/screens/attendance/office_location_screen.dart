import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

class OfficeLocationScreen extends StatefulWidget {
  const OfficeLocationScreen({super.key});
  @override
  State<OfficeLocationScreen> createState() => _OfficeLocationScreenState();
}

class _OfficeLocationScreenState extends State<OfficeLocationScreen> {
  List<dynamic> _locations = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final raw = await context.read<AppState>().api.getOfficeLocations();
      setState(() { _locations = raw; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  void _showForm([Map<String, dynamic>? existing]) {
    final nameCtrl   = TextEditingController(text: existing?['name']      ?? 'techCentrix');
    final latCtrl    = TextEditingController(text: existing?['latitude']?.toString()   ?? '');
    final lngCtrl    = TextEditingController(text: existing?['longitude']?.toString()  ?? '');
    final radiusCtrl = TextEditingController(text: existing?['radius_meters']?.toString() ?? '100');
    final graceCtrl  = TextEditingController(text: existing?['grace_minutes']?.toString()  ?? '15');
    final deptCtrl   = TextEditingController(text: existing?['department'] ?? '');
    TimeOfDay shiftStart = _parseTime(existing?['shift_start'] ?? '09:00');
    TimeOfDay shiftEnd   = _parseTime(existing?['shift_end']   ?? '18:00');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, set) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),

            // Header
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 22)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(existing == null ? 'Add Office Location' : 'Edit Location',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                const Text('Configure geofence settings', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ]),
            const SizedBox(height: 20),

            // Location Name
            _sheetField('Office Name', nameCtrl, Icons.business_rounded),
            const SizedBox(height: 16),

            // Coordinates
            _sectionLabel('GPS Coordinates'),
            Row(children: [
              Expanded(child: _sheetField('Latitude', latCtrl, Icons.south_rounded,
                  keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
              const SizedBox(width: 12),
              Expanded(child: _sheetField('Longitude', lngCtrl, Icons.east_rounded,
                  keyboard: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            ]),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.info.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.info),
                const SizedBox(width: 8),
                const Expanded(child: Text('Open Google Maps, long-press your office location and copy the coordinates.',
                    style: TextStyle(fontSize: 11, color: AppTheme.info))),
              ]),
            ),
            const SizedBox(height: 16),

            // Geofence settings
            _sectionLabel('Geofence Settings'),
            Row(children: [
              Expanded(child: _sheetField('Radius (meters)', radiusCtrl, Icons.radar_rounded,
                  keyboard: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _sheetField('Grace Period (min)', graceCtrl, Icons.timer_outlined,
                  keyboard: TextInputType.number)),
            ]),
            const SizedBox(height: 16),

            // Shift times
            _sectionLabel('Shift Hours'),
            Row(children: [
              Expanded(child: _timePicker(ctx, 'Shift Start', shiftStart,
                  (t) => set(() => shiftStart = t), Icons.play_circle_outline_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _timePicker(ctx, 'Shift End', shiftEnd,
                  (t) => set(() => shiftEnd = t), Icons.stop_circle_outlined)),
            ]),
            const SizedBox(height: 16),

            // Department
            _sectionLabel('Department (optional)'),
            _sheetField('Leave blank to apply to all departments', deptCtrl, Icons.people_outline_rounded),
            const SizedBox(height: 24),

            // Save button
            SizedBox(width: double.infinity, height: 52, child: FilledButton(
              onPressed: () async {
                if (latCtrl.text.isEmpty || lngCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Please enter latitude and longitude'),
                    backgroundColor: AppTheme.error));
                  return;
                }
                final data = {
                  'name':          nameCtrl.text.trim(),
                  'latitude':      double.tryParse(latCtrl.text)   ?? 0,
                  'longitude':     double.tryParse(lngCtrl.text)   ?? 0,
                  'radius_meters': int.tryParse(radiusCtrl.text)   ?? 100,
                  'grace_minutes': int.tryParse(graceCtrl.text)    ?? 15,
                  'department':    deptCtrl.text.trim(),
                  'shift_start':   '${shiftStart.hour.toString().padLeft(2,'0')}:${shiftStart.minute.toString().padLeft(2,'0')}',
                  'shift_end':     '${shiftEnd.hour.toString().padLeft(2,'0')}:${shiftEnd.minute.toString().padLeft(2,'0')}',
                };
                if (existing != null) {
                  await context.read<AppState>().api.updateOfficeLocation(existing['id'], data);
                } else {
                  await context.read<AppState>().api.createOfficeLocation(data);
                }
                if (mounted) Navigator.pop(ctx);
                _load();
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(existing == null ? 'Add Location' : 'Save Changes',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      )),
    );
  }

  TimeOfDay _parseTime(String t) {
    final p = t.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
        color: Color(0xFF6B7280), letterSpacing: 0.3)),
  );

  Widget _sheetField(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? keyboard}) =>
    TextField(
      controller: ctrl, keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade400),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );

  Widget _timePicker(BuildContext ctx, String label, TimeOfDay val,
      ValueChanged<TimeOfDay> onPicked, IconData icon) =>
    GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: ctx, initialTime: val);
        if (t != null) onPicked(t);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            Text(val.format(ctx), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
          ]),
        ]),
      ),
    );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          expandedHeight: 120,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Office Locations', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('Geofence & shift configuration', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
          ),
          title: const Text('Office Locations'),
        ),
        if (_loading)
          const SliverToBoxAdapter(child: SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))))
        else if (_locations.isEmpty)
          SliverToBoxAdapter(child: _emptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _locationCard(_locations[i] as Map<String, dynamic>),
              childCount: _locations.length,
            )),
          ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text('Add Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _locationCard(Map<String, dynamic> loc) {
    final isActive = loc['is_active'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.08), AppTheme.primary.withValues(alpha: 0.02)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, Color(0xFF0E6FA3)]),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loc['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A2E))),
              if ((loc['department'] ?? '').isNotEmpty)
                Text(loc['department'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppTheme.success.withValues(alpha: 0.1) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20)),
              child: Text(isActive ? '● Active' : '○ Inactive',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: isActive ? AppTheme.success : Colors.grey.shade500))),
          ]),
        ),

        // Info grid
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              _infoChip(Icons.radar_rounded, '${loc['radius_meters']}m radius', AppTheme.primary),
              const SizedBox(width: 10),
              _infoChip(Icons.timer_outlined, '${loc['grace_minutes']}min grace', AppTheme.warning),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Column(children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 16, color: AppTheme.success),
                  const SizedBox(height: 4),
                  Text(loc['shift_start'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Text('Start', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                ]),
                Container(width: 40, height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.success, AppTheme.error]),
                    borderRadius: BorderRadius.circular(1))),
                Column(children: [
                  const Icon(Icons.stop_circle_outlined, size: 16, color: AppTheme.error),
                  const SizedBox(height: 4),
                  Text(loc['shift_end'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Text('End', style: TextStyle(fontSize: 10, color: Color(0xFF6B7280))),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete Location?'),
                    content: Text('Remove "${loc['name']}"? Staff won\'t be able to check in without a configured location.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                    ],
                  ));
                  if (ok == true) { await context.read<AppState>().api.deleteOfficeLocation(loc['id']); _load(); }
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton.icon(
                onPressed: () => _showForm(loc),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    ]),
  ));

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.all(40),
    child: Column(children: [
      const SizedBox(height: 40),
      Container(width: 100, height: 100,
        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
        child: const Icon(Icons.add_location_alt_rounded, size: 48, color: AppTheme.primary)),
      const SizedBox(height: 20),
      const Text('No office location set', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A1A2E))),
      const SizedBox(height: 8),
      Text('Add your office coordinates so staff can check in via geofence.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Office Location'),
        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
      ),
    ]),
  );
}
