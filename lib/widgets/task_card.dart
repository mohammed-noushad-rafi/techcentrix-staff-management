import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onTap});

  Color _priorityColor(BuildContext context) {
    switch (task.priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
      default:
        return Colors.green;
    }
  }

  Color _parseLabelColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.priority.toUpperCase(),
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (task.isOverdue)
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                ],
              ),
              const SizedBox(height: 6),
              Text(task.title, style: const TextStyle(fontWeight: FontWeight.w500), maxLines: 3, overflow: TextOverflow.ellipsis),
              if (task.labels.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: task.labels.take(3).map((l) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _parseLabelColor(l.color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(l.name, style: const TextStyle(fontSize: 9, color: Colors.white)),
                    );
                  }).toList(),
                ),
              ],
              if (task.dueDate != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(task.dueDate!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
              if (task.assignee != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      child: Text(task.assignee!.username.isNotEmpty
                          ? task.assignee!.username[0].toUpperCase()
                          : '?', style: const TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(width: 6),
                    Text(task.assignee!.username, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
