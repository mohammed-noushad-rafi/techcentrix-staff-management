import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getNotifications();
    setState(() { _notifications = raw; _loading = false; });
  }

  Future<void> _markAllRead() async {
    await context.read<AppState>().api.markAllNotificationsRead();
    _load();
  }

  IconData _icon(String type) {
    switch (type) {
      case 'task_assigned': return Icons.assignment_ind_outlined;
      case 'task_reassigned': return Icons.assignment_return_outlined;
      case 'task_submitted': return Icons.pending_actions_outlined;
      case 'task_verified': return Icons.verified_outlined;
      case 'task_overdue': return Icons.alarm_outlined;
      case 'new_comment': return Icons.chat_bubble_outline;
      case 'team_added': return Icons.group_add_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String type) {
    switch (type) {
      case 'task_assigned': return Colors.blue;
      case 'task_reassigned': return Colors.orange;
      case 'task_submitted': return Colors.purple;
      case 'task_verified': return Colors.green;
      case 'task_overdue': return Colors.red;
      case 'new_comment': return Colors.teal;
      case 'team_added': return Colors.indigo;
      default: return Colors.grey;
    }
  }

  String _formatTime(String iso) {
    try { return DateFormat('MMM d, h:mm a').format(DateTime.parse(iso).toLocal()); } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _notifications.any((n) => !(n['is_read'] ?? false)) ? _markAllRead : null, child: const Text('Mark all read')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading ? const Center(child: CircularProgressIndicator()) : _notifications.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No notifications yet.'))])
            : ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  final isRead = n['is_read'] ?? false;
                  final type = n['notif_type'] ?? '';
                  return ListTile(
                    tileColor: isRead ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                    leading: CircleAvatar(backgroundColor: _iconColor(type).withValues(alpha: 0.15),
                      child: Icon(_icon(type), size: 18, color: _iconColor(type))),
                    title: Text(n['message'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
                    subtitle: Text(_formatTime(n['created_at'] ?? ''), style: const TextStyle(fontSize: 11)),
                    trailing: !isRead ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)) : null,
                    onTap: () async {
                      if (!isRead) { await context.read<AppState>().api.markNotificationRead(n['id']); _load(); }
                    },
                  );
                },
              ),
      ),
    );
  }
}
