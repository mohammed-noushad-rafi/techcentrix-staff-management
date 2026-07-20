import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../models/task_extras.dart';
import '../services/app_state.dart';

class TaskDetailScreen extends StatefulWidget {
  final TaskItem task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  String _priority = 'medium';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _titleCtrl = TextEditingController(text: widget.task.title);
    _descCtrl = TextEditingController(text: widget.task.description);
    _priority = widget.task.priority;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppState>().api.updateTask(widget.task.id, {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text,
        'priority': _priority,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<AppState>().api.deleteTask(widget.task.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Checklist'),
            Tab(text: 'Comments'),
            Tab(text: 'Files'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DetailsTab(
            titleCtrl: _titleCtrl,
            descCtrl: _descCtrl,
            priority: _priority,
            onPriorityChanged: (v) => setState(() => _priority = v ?? 'medium'),
            saving: _saving,
            onSave: _save,
            task: widget.task,
          ),
          _ChecklistTab(taskId: widget.task.id),
          _CommentsTab(taskId: widget.task.id),
          _AttachmentsTab(taskId: widget.task.id),
        ],
      ),
    );
  }
}

// ---------------- DETAILS TAB ----------------

class _DetailsTab extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;
  final String priority;
  final ValueChanged<String?> onPriorityChanged;
  final bool saving;
  final VoidCallback onSave;
  final TaskItem task;

  const _DetailsTab({
    required this.titleCtrl,
    required this.descCtrl,
    required this.priority,
    required this.onPriorityChanged,
    required this.saving,
    required this.onSave,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (task.labels.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: task.labels.map((l) {
                final color = _parseColor(l.color);
                return Chip(
                  label: Text(l.name, style: const TextStyle(fontSize: 12, color: Colors.white)),
                  backgroundColor: color,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.label_outline, size: 18),
              label: const Text('Manage labels'),
              onPressed: () => _manageLabels(context),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: descCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Low')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'high', child: Text('High')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
            ],
            onChanged: onPriorityChanged,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    height: 18, width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  Future<void> _manageLabels(BuildContext context) async {
    final api = context.read<AppState>().api;
    final newLabelCtrl = TextEditingController();
    List<Label> boardLabels = [];
    Set<int> assignedIds = task.labels.map((l) => l.id).toSet();
    bool changed = false;

    try {
      final raw = await api.getLabels(task.board);
      boardLabels = raw.map((e) => Label.fromJson(e)).toList();
    } catch (_) {}

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Manage labels'),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (boardLabels.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No labels on this board yet.'),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: boardLabels.map((l) {
                      final selected = assignedIds.contains(l.id);
                      return FilterChip(
                        label: Text(l.name),
                        selected: selected,
                        selectedColor: _parseColor(l.color).withValues(alpha: 0.3),
                        onSelected: (val) async {
                          await api.setTaskLabel(task.id, l.id, add: val);
                          changed = true;
                          setLocal(() {
                            if (val) {
                              assignedIds.add(l.id);
                            } else {
                              assignedIds.remove(l.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: newLabelCtrl,
                        decoration: const InputDecoration(
                          hintText: 'New label name',
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final name = newLabelCtrl.text.trim();
                        if (name.isEmpty) return;
                        const colors = ['#4F46E5', '#DC2626', '#16A34A', '#D97706', '#0891B2', '#9333EA'];
                        final color = colors[boardLabels.length % colors.length];
                        final created = await api.createLabel(task.board, name, color);
                        final newLabel = Label.fromJson(created);
                        newLabelCtrl.clear();
                        changed = true;
                        setLocal(() => boardLabels = [...boardLabels, newLabel]);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      ),
    );

    if (changed && context.mounted) {
      // Pop back to refresh the board's task list with updated labels.
      Navigator.pop(context);
    }
  }
}

// ---------------- CHECKLIST TAB ----------------

class _ChecklistTab extends StatefulWidget {
  final int taskId;
  const _ChecklistTab({required this.taskId});

  @override
  State<_ChecklistTab> createState() => _ChecklistTabState();
}

class _ChecklistTabState extends State<_ChecklistTab> {
  List<ChecklistItemModel> _items = [];
  bool _loading = true;
  final _newItemCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getChecklist(widget.taskId);
    setState(() {
      _items = raw.map((e) => ChecklistItemModel.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _add() async {
    final text = _newItemCtrl.text.trim();
    if (text.isEmpty) return;
    _newItemCtrl.clear();
    await context.read<AppState>().api.addChecklistItem(widget.taskId, text);
    _load();
  }

  Future<void> _toggle(ChecklistItemModel item) async {
    await context.read<AppState>().api.toggleChecklistItem(item.id, !item.isDone);
    _load();
  }

  Future<void> _delete(ChecklistItemModel item) async {
    await context.read<AppState>().api.deleteChecklistItem(item.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final doneCount = _items.where((i) => i.isDone).length;
    return Column(
      children: [
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: LinearProgressIndicator(
              value: _items.isEmpty ? 0 : doneCount / _items.length,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('No checklist items yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return CheckboxListTile(
                          value: item.isDone,
                          onChanged: (_) => _toggle(item),
                          title: Text(
                            item.text,
                            style: item.isDone
                                ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                                : null,
                          ),
                          secondary: IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _delete(item),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItemCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add checklist item',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(icon: const Icon(Icons.add), onPressed: _add),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- COMMENTS TAB ----------------

class _CommentsTab extends StatefulWidget {
  final int taskId;
  const _CommentsTab({required this.taskId});

  @override
  State<_CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<_CommentsTab> {
  List<CommentModel> _comments = [];
  bool _loading = true;
  final _commentCtrl = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getComments(widget.taskId);
    setState(() {
      _comments = raw.map((e) => CommentModel.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _post() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    _commentCtrl.clear();
    try {
      await context.read<AppState>().api.addComment(widget.taskId, text);
      await _load();
    } finally {
      if (mounted) setState(() => _posting = false);
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
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _comments.isEmpty
                  ? const Center(child: Text('No comments yet. Start the discussion below.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _comments.length,
                      itemBuilder: (context, i) {
                        final c = _comments[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      child: Text(
                                        c.author.username.isNotEmpty ? c.author.username[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(c.author.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const Spacer(),
                                    Text(_formatTime(c.createdAt),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(c.body),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                _posting
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton.filled(icon: const Icon(Icons.send), onPressed: _post),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- ATTACHMENTS TAB ----------------

class _AttachmentsTab extends StatefulWidget {
  final int taskId;
  const _AttachmentsTab({required this.taskId});

  @override
  State<_AttachmentsTab> createState() => _AttachmentsTabState();
}

class _AttachmentsTabState extends State<_AttachmentsTab> {
  List<AttachmentModel> _attachments = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final raw = await context.read<AppState>().api.getAttachments(widget.taskId);
    setState(() {
      _attachments = raw.map((e) => AttachmentModel.fromJson(e)).toList();
      _loading = false;
    });
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final name = result.files.single.name;
    setState(() => _uploading = true);
    try {
      await context.read<AppState>().api.uploadAttachment(widget.taskId, path, name);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(AttachmentModel a) async {
    await context.read<AppState>().api.deleteAttachment(a.id);
    _load();
  }

  IconData _iconFor(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) return Icons.image_outlined;
    if (['pdf'].contains(ext)) return Icons.picture_as_pdf_outlined;
    if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart_outlined;
    if (['zip', 'rar'].contains(ext)) return Icons.folder_zip_outlined;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _attachments.isEmpty
                  ? const Center(child: Text('No files attached yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _attachments.length,
                      itemBuilder: (context, i) {
                        final a = _attachments[i];
                        return ListTile(
                          leading: Icon(_iconFor(a.fileName)),
                          title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('Uploaded by ${a.uploadedBy.username}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _delete(a),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _uploading ? null : _pickAndUpload,
            icon: _uploading
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.attach_file),
            label: Text(_uploading ? 'Uploading...' : 'Attach a file'),
          ),
        ),
      ],
    );
  }
}
