import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task_extras.dart';
import '../services/app_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getNotifications();
    setState(() {
      _notifications = raw.map((e) => AppNotification.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _markAllRead() async {
    await context.read<AppState>().api.markAllNotificationsRead();
    _load();
  }

  Future<void> _onTap(AppNotification n) async {
    if (!n.isRead) {
      await context.read<AppState>().api.markNotificationRead(n.id);
      _load();
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'task_assigned':
        return Icons.assignment_ind_outlined;
      case 'due_date_reminder':
        return Icons.alarm_outlined;
      case 'status_updated':
        return Icons.sync_alt;
      case 'new_comment':
        return Icons.chat_bubble_outline;
      case 'board_invitation':
        return Icons.group_add_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _notifications.any((n) => !n.isRead) ? _markAllRead : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No notifications yet.')),
                    ],
                  )
                : ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, i) {
                      final n = _notifications[i];
                      return ListTile(
                        tileColor: n.isRead ? null : Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
                        leading: CircleAvatar(
                          backgroundColor: n.isRead
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : Theme.of(context).colorScheme.primary,
                          child: Icon(
                            _iconFor(n.notifType),
                            size: 18,
                            color: n.isRead ? null : Colors.white,
                          ),
                        ),
                        title: Text(n.message, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                        subtitle: Text(_formatTime(n.createdAt)),
                        onTap: () => _onTap(n),
                      );
                    },
                  ),
      ),
    );
  }
}
