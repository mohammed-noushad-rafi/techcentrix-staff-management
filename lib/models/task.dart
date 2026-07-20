class TaskItem {
  final int id;
  final int board;
  final int column;
  final String columnName;
  final int? team;
  final String title;
  final String description;
  final String priority;
  final String status;
  final String? dueDate;
  final Map<String, dynamic>? assignee;
  final int order;
  final bool isCompleted;
  final bool isOverdue;
  final bool submittedForReview;
  final Map<String, dynamic>? verifiedBy;
  final String? verifiedAt;
  final int subtaskCount;
  final int subtaskDoneCount;
  final List<dynamic> subtasks;
  final List<dynamic> comments;
  final List<dynamic> labels;

  TaskItem({
    required this.id,
    required this.board,
    required this.column,
    this.columnName = '',
    this.team,
    required this.title,
    this.description = '',
    this.priority = 'medium',
    this.status = 'todo',
    this.dueDate,
    this.assignee,
    this.order = 0,
    this.isCompleted = false,
    this.isOverdue = false,
    this.submittedForReview = false,
    this.verifiedBy,
    this.verifiedAt,
    this.subtaskCount = 0,
    this.subtaskDoneCount = 0,
    this.subtasks = const [],
    this.comments = const [],
    this.labels = const [],
  });

  String get assigneeName => assignee?['username'] ?? '';
  String get priorityLabel => priority[0].toUpperCase() + priority.substring(1);

  String get statusLabel {
    switch (status) {
      case 'in_progress': return 'In Progress';
      case 'done_pending': return 'Pending Review';
      case 'completed': return 'Completed';
      case 'reassigned': return 'Reassigned';
      default: return status[0].toUpperCase() + status.substring(1);
    }
  }

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: json['id'] ?? 0,
      board: json['board'] ?? 0,
      column: json['column'] ?? 0,
      columnName: json['column_name'] ?? '',
      team: json['team'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'todo',
      dueDate: json['due_date'],
      assignee: json['assignee'] as Map<String, dynamic>?,
      order: json['order'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      isOverdue: json['is_overdue'] ?? false,
      submittedForReview: json['submitted_for_review'] ?? false,
      verifiedBy: json['verified_by'] as Map<String, dynamic>?,
      verifiedAt: json['verified_at'],
      subtaskCount: json['subtask_count'] ?? 0,
      subtaskDoneCount: json['subtask_done_count'] ?? 0,
      subtasks: json['subtasks'] as List? ?? [],
      comments: json['comments'] as List? ?? [],
      labels: json['labels'] as List? ?? [],
    );
  }

  TaskItem copyWith({int? column, int? order, bool? isCompleted, String? status}) {
    return TaskItem(
      id: id, board: board,
      column: column ?? this.column,
      columnName: columnName,
      team: team, title: title, description: description,
      priority: priority,
      status: status ?? this.status,
      dueDate: dueDate, assignee: assignee,
      order: order ?? this.order,
      isCompleted: isCompleted ?? this.isCompleted,
      isOverdue: isOverdue,
      submittedForReview: submittedForReview,
      verifiedBy: verifiedBy, verifiedAt: verifiedAt,
      subtaskCount: subtaskCount, subtaskDoneCount: subtaskDoneCount,
      subtasks: subtasks, comments: comments, labels: labels,
    );
  }
}
