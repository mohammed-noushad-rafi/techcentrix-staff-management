import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme.dart';

const _departments = [
  'Engineering','Design','Product','Marketing','Sales',
  'Human Resources','Finance','Operations','Data Science',
  'QA & Testing','DevOps','Customer Support','Other',
];

const _jobRoles = [
  'Software Engineer','Senior Software Engineer','Lead Engineer',
  'Frontend Developer','Backend Developer','Full Stack Developer',
  'Mobile Developer','DevOps Engineer','Data Scientist','Data Analyst',
  'UI/UX Designer','Product Manager','Project Manager',
  'QA Engineer','Business Analyst','HR Executive',
  'Marketing Executive','Sales Executive','Finance Executive','Other',
];

class CreateStaffScreen extends StatefulWidget {
  const CreateStaffScreen({super.key});
  @override
  State<CreateStaffScreen> createState() => _CreateStaffScreenState();
}

class _CreateStaffScreenState extends State<CreateStaffScreen>
    with SingleTickerProviderStateMixin {
  final _formKey    = GlobalKey<FormState>();
  bool _loading     = false;
  String? _error;
  String _role      = 'intern';
  String _expType   = 'fresher';
  bool _obscure     = true;
  String? _dept, _jobRole;
  DateTime? _startDate, _endDate;
  late AnimationController _roleAnim;

  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _collegeCtrl  = TextEditingController();
  final _degreeCtrl   = TextEditingController();
  final _yearsCtrl    = TextEditingController();

  @override
  void initState() {
    super.initState();
    _roleAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() { _roleAnim.dispose(); super.dispose(); }

  Color get _roleColor => _role == 'intern' ? AppTheme.primary : const Color(0xFF10B981);
  String _fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  String _displayDate(DateTime d) {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[d.month-1]} ${d.day}, ${d.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = <String, dynamic>{
        'username': _usernameCtrl.text.trim(), 'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text, 'role': _role,
        'full_name': _fullNameCtrl.text.trim(), 'phone': _phoneCtrl.text.trim(),
        'department': _dept ?? '',
      };
      if (_role == 'intern') {
        data['college'] = _collegeCtrl.text.trim();
        data['degree']  = _degreeCtrl.text.trim();
        if (_startDate != null) data['start_date'] = _fmt(_startDate!);
        if (_endDate   != null) data['end_date']   = _fmt(_endDate!);
      } else {
        data['job_role'] = _jobRole ?? '';
        data['experience_type'] = _expType;
        if (_expType == 'experienced' && _yearsCtrl.text.isNotEmpty)
          data['years_of_experience'] = int.tryParse(_yearsCtrl.text);
      }
      await context.read<AppState>().api.createStaff(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_fullNameCtrl.text} added!'), backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Form(
        key: _formKey,
        child: CustomScrollView(slivers: [

          // ── Dynamic header ─────────────────────────
          SliverToBoxAdapter(child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: _role == 'intern'
                    ? [const Color(0xFF0E6FA3), AppTheme.primary]
                    : [const Color(0xFF047857), const Color(0xFF10B981)],
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _role == 'intern' ? Icons.school_rounded : Icons.work_rounded,
                      key: ValueKey(_role), color: Colors.white, size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Add Staff Member', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _role == 'intern' ? 'Creating an intern account' : 'Creating an employee account',
                        key: ValueKey(_role),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ]),
                ]),
                const SizedBox(height: 20),

                // Role toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(children: [
                    _roleTab('intern',    'Intern',   Icons.school_rounded),
                    _roleTab('employee',  'Employee', Icons.work_rounded),
                  ]),
                ),
              ]),
            )),
          )),

          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [

              // ── Account card ────────────────────────
              _card(icon: Icons.manage_accounts_rounded, title: 'Login Account', color: AppTheme.primary,
                children: [
                  _iconField('Username', Icons.person_outline_rounded, _usernameCtrl, required: true),
                  _iconField('Email address', Icons.email_outlined, _emailCtrl,
                      required: true, keyboard: TextInputType.emailAddress),
                  _passField(),
                ]),
              const SizedBox(height: 14),

              // ── Personal info card ──────────────────
              _card(icon: Icons.badge_outlined, title: 'Personal Info', color: const Color(0xFF8B5CF6),
                children: [
                  _iconField('Full Name', Icons.person_rounded, _fullNameCtrl, required: true),
                  _iconField('Phone Number', Icons.phone_outlined, _phoneCtrl,
                      keyboard: TextInputType.phone),
                  _iconDropdown('Department', Icons.business_outlined, _dept, _departments,
                      (v) => setState(() => _dept = v)),
                ]),
              const SizedBox(height: 14),

              // ── Role-specific card ──────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _role == 'intern'
                    ? _card(key: const ValueKey('intern'),
                        icon: Icons.school_rounded, title: 'Academic Details', color: AppTheme.primary,
                        children: [
                          _iconField('College / University', Icons.account_balance_outlined, _collegeCtrl),
                          _iconField('Degree / Program', Icons.menu_book_outlined, _degreeCtrl),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(child: _datePick('Start', _startDate,
                                (d) => setState(() => _startDate = d), isStart: true)),
                            const SizedBox(width: 10),
                            Expanded(child: _datePick('End', _endDate,
                                (d) => setState(() => _endDate = d), isStart: false)),
                          ]),
                        ])
                    : _card(key: const ValueKey('employee'),
                        icon: Icons.work_rounded, title: 'Professional Details', color: const Color(0xFF10B981),
                        children: [
                          _iconDropdown('Job Role / Designation', Icons.work_outline_rounded,
                              _jobRole, _jobRoles, (v) => setState(() => _jobRole = v)),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _expCard('fresher',    'Fresher',    Icons.person_outline_rounded)),
                            const SizedBox(width: 10),
                            Expanded(child: _expCard('experienced','Experienced',Icons.workspace_premium_outlined)),
                          ]),
                          if (_expType == 'experienced') ...[
                            const SizedBox(height: 10),
                            _iconField('Years of Experience', Icons.timeline_outlined, _yearsCtrl,
                                keyboard: TextInputType.number),
                          ],
                        ]),
              ),

              // ── Error ───────────────────────────────
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                  ]),
                ),
              ],

              // ── Submit ──────────────────────────────
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 54,
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _loading ? null : _submit,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _role == 'intern'
                              ? [const Color(0xFF0E6FA3), AppTheme.primary]
                              : [const Color(0xFF047857), const Color(0xFF10B981)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: _roleColor.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
                      ),
                      alignment: Alignment.center,
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_role == 'intern' ? Icons.school_rounded : Icons.work_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Text('Create ${_role == 'intern' ? 'Intern' : 'Employee'} Account',
                                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _roleTab(String value, String label, IconData icon) {
    final sel = _role == value;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: sel ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16,
              color: sel ? _roleColor : Colors.white60),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14,
            color: sel ? _roleColor : Colors.white70)),
        ]),
      ),
    ));
  }

  Widget _card({Key? key, required IconData icon, required String title,
      required Color color, required List<Widget> children}) =>
    Container(
      key: key,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.12))),
          ),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16)),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ]),
    );

  Widget _iconField(String label, IconData icon, TextEditingController ctrl,
      {bool required = false, int maxLines = 1, TextInputType? keyboard}) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
      controller: ctrl, maxLines: maxLines, keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Required' : null : null,
    ));

  Widget _passField() => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
    controller: _passwordCtrl, obscureText: _obscure,
    decoration: InputDecoration(
      labelText: 'Password',
      prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey.shade500),
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18, color: Colors.grey.shade500),
        onPressed: () => setState(() => _obscure = !_obscure)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
  ));

  Widget _iconDropdown(String label, IconData icon, String? value,
      List<String> items, ValueChanged<String?> onChanged) =>
    Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(
      value: value, isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade500),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      hint: Text('Select $label', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
      items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
    ));

  Widget _expCard(String value, String label, IconData icon) {
    final sel   = _expType == value;
    final color = const Color(0xFF10B981);
    return GestureDetector(
      onTap: () => setState(() => _expType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? color : Colors.grey.shade200, width: sel ? 2 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: sel ? color : Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
              color: sel ? color : Colors.grey.shade600)),
          if (sel) ...[const Spacer(), Icon(Icons.check_circle_rounded, color: color, size: 16)],
        ]),
      ),
    );
  }

  Widget _datePick(String label, DateTime? value, ValueChanged<DateTime> onPicked, {required bool isStart}) =>
    GestureDetector(
      onTap: () async {
        final d = await showDatePicker(context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2020), lastDate: DateTime(2030));
        if (d != null) onPicked(d);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value != null ? AppTheme.primary.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null ? AppTheme.primary.withValues(alpha: 0.3) : Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isStart ? Icons.play_circle_outline_rounded : Icons.stop_circle_outlined,
                size: 14, color: value != null ? AppTheme.primary : Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: value != null ? AppTheme.primary : Colors.grey.shade500)),
            const Spacer(),
            if (value != null) GestureDetector(
              onTap: () => setState(() => isStart ? _startDate = null : _endDate = null),
              child: Icon(Icons.close_rounded, size: 14, color: Colors.grey.shade400)),
          ]),
          const SizedBox(height: 4),
          Text(
            value != null ? _displayDate(value) : 'Optional',
            style: TextStyle(fontSize: 13, fontWeight: value != null ? FontWeight.bold : FontWeight.normal,
                color: value != null ? const Color(0xFF1A1A2E) : Colors.grey.shade400),
          ),
        ]),
      ),
    );
}
