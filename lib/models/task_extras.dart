import 'user.dart';

class Label {
  final int id;
  final int board;
  final String name;
  final String color; // hex string e.g. #4F46E5

  Label({required this.id, required this.board, required this.name, required this.color});

  factory Label.fromJson(Map<String, dynamic> json) {
    return Label(
      id: json['id'],
      board: json['board'],
      name: json['name'] ?? '',
      color: json['color'] ?? '#999999',
    );
  }
}

class ChecklistItemModel {
  final int id;
  final int task;
  final String text;
  final bool isDone;
  final int order;

  ChecklistItemModel({
    required this.id,
    required this.task,
    required this.text,
    required this.isDone,
    this.order = 0,
  });

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'],
      task: json['task'],
      text: json['text'] ?? '',
      isDone: json['is_done'] ?? false,
      order: json['order'] ?? 0,
    );
  }
}

class CommentModel {
  final int id;
  final int task;
  final AppUser author;
  final String body;
  final String createdAt;

  CommentModel({
    required this.id,
    required this.task,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'],
      task: json['task'],
      author: AppUser.fromJson(json['author']),
      body: json['body'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class AttachmentModel {
  final int id;
  final int task;
  final String fileUrl;
  final AppUser uploadedBy;
  final String uploadedAt;

  AttachmentModel({
    required this.id,
    required this.task,
    required this.fileUrl,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  String get fileName => fileUrl.split('/').isNotEmpty ? fileUrl.split('/').last : fileUrl;

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'],
      task: json['task'],
      fileUrl: json['file'] ?? '',
      uploadedBy: AppUser.fromJson(json['uploaded_by']),
      uploadedAt: json['uploaded_at'] ?? '',
    );
  }
}

class AppNotification {
  final int id;
  final String notifType;
  final String message;
  final int? task;
  final bool isRead;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.notifType,
    required this.message,
    this.task,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      notifType: json['notif_type'] ?? '',
      message: json['message'] ?? '',
      task: json['task'],
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}
