from rest_framework import serializers
from accounts.serializers import UserSerializer
from accounts.models import User
from .models import (Task, SubTask, Label, TaskLabel, ChecklistItem,
                      Attachment, Comment, ActivityLog, Notification)


class LabelSerializer(serializers.ModelSerializer):
    class Meta:
        model = Label
        fields = ['id', 'board', 'name', 'color']


class SubTaskSerializer(serializers.ModelSerializer):
    created_by = UserSerializer(read_only=True)

    class Meta:
        model = SubTask
        fields = ['id', 'task', 'created_by', 'title', 'is_done', 'order', 'created_at']
        read_only_fields = ['id', 'created_by', 'created_at']


class ChecklistItemSerializer(serializers.ModelSerializer):
    class Meta:
        model = ChecklistItem
        fields = ['id', 'task', 'text', 'is_done', 'order']
        read_only_fields = ['id']


class AttachmentSerializer(serializers.ModelSerializer):
    uploaded_by = UserSerializer(read_only=True)

    class Meta:
        model = Attachment
        fields = ['id', 'task', 'file', 'uploaded_by', 'uploaded_at']
        read_only_fields = ['id', 'uploaded_by', 'uploaded_at']


class CommentSerializer(serializers.ModelSerializer):
    author = UserSerializer(read_only=True)

    class Meta:
        model = Comment
        fields = ['id', 'task', 'author', 'body', 'created_at']
        read_only_fields = ['id', 'author', 'created_at']


class ActivityLogSerializer(serializers.ModelSerializer):
    actor = UserSerializer(read_only=True)

    class Meta:
        model = ActivityLog
        fields = ['id', 'task', 'actor', 'message', 'created_at']


class TaskSerializer(serializers.ModelSerializer):
    assignee = UserSerializer(read_only=True)
    team_id = serializers.PrimaryKeyRelatedField(
        queryset=__import__('accounts.models', fromlist=['Team']).Team.objects.all(),
        source='team', write_only=True, required=False, allow_null=True
    )
    assignee_id = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), source='assignee',
        write_only=True, required=False, allow_null=True
    )
    created_by = UserSerializer(read_only=True)
    verified_by = UserSerializer(read_only=True)
    subtasks = SubTaskSerializer(many=True, read_only=True)
    checklist_items = ChecklistItemSerializer(many=True, read_only=True)
    comments = CommentSerializer(many=True, read_only=True)
    labels = serializers.SerializerMethodField()
    is_overdue = serializers.ReadOnlyField()
    column_name = serializers.SerializerMethodField()
    subtask_count = serializers.SerializerMethodField()
    subtask_done_count = serializers.SerializerMethodField()

    class Meta:
        model = Task
        fields = [
            'id', 'board', 'column', 'column_name', 'team',
            'title', 'description', 'priority', 'status',
            'due_date', 'assignee', 'assignee_id', 'team', 'team_id',
            'created_by', 'order',
            'submitted_for_review', 'verified_by', 'verified_at',
            'is_completed', 'is_overdue',
            'subtasks', 'subtask_count', 'subtask_done_count',
            'checklist_items', 'comments', 'labels',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_by', 'verified_by', 'verified_at', 'created_at', 'updated_at']

    def get_column_name(self, obj):
        return obj.column.name if obj.column_id else ''

    def get_labels(self, obj):
        return LabelSerializer([tl.label for tl in obj.task_labels.select_related('label')], many=True).data

    def get_subtask_count(self, obj):
        return obj.subtasks.count()

    def get_subtask_done_count(self, obj):
        return obj.subtasks.filter(is_done=True).count()


class NotificationSerializer(serializers.ModelSerializer):
    task_title = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = ['id', 'notif_type', 'message', 'task', 'task_title', 'is_read', 'created_at']

    def get_task_title(self, obj):
        return obj.task.title if obj.task else None
