class BoardColumn {
  final int id;
  final int board;
  final String name;
  final int order;
  final int? wipLimit;
  final int taskCount;

  BoardColumn({
    required this.id,
    required this.board,
    required this.name,
    required this.order,
    this.wipLimit,
    this.taskCount = 0,
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'],
      board: json['board'],
      name: json['name'] ?? '',
      order: json['order'] ?? 0,
      wipLimit: json['wip_limit'],
      taskCount: json['task_count'] ?? 0,
    );
  }
}

class Board {
  final int id;
  final int workspace;
  final String name;
  final String description;
  final bool isArchived;
  final List<BoardColumn> columns;

  Board({
    required this.id,
    required this.workspace,
    required this.name,
    required this.description,
    required this.isArchived,
    required this.columns,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'],
      workspace: json['workspace'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      isArchived: json['is_archived'] ?? false,
      columns: (json['columns'] as List? ?? [])
          .map((c) => BoardColumn.fromJson(c))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order)),
    );
  }
}
