from django.utils import timezone
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import viewsets, permissions, filters, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import (Task, SubTask, Label, TaskLabel, ChecklistItem,
                      Attachment, Comment, ActivityLog, Notification)
from .serializers import (
    TaskSerializer, SubTaskSerializer, LabelSerializer,
    ChecklistItemSerializer, AttachmentSerializer,
    CommentSerializer, ActivityLogSerializer, NotificationSerializer,
)


class IsAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'admin'


class TaskViewSet(viewsets.ModelViewSet):
    """
    Admin: full CRUD + assign + verify + reassign
    Staff: read their own tasks only (via /api/my-tasks/)
    """
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    filterset_fields = ['board', 'column', 'priority', 'assignee', 'is_completed',
                        'submitted_for_review', 'status', 'team']
    search_fields = ['title', 'description']
    ordering_fields = ['due_date', 'priority', 'created_at', 'order']

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Task.objects.all().select_related('column', 'board', 'assignee')
        return Task.objects.filter(assignee=user).select_related('column', 'board')

    def perform_create(self, serializer):
        task = serializer.save(created_by=self.request.user)
        ActivityLog.objects.create(task=task, actor=self.request.user, message='created the task')
        if task.assignee:
            Notification.objects.create(
                recipient=task.assignee, notif_type='task_assigned',
                message=f'You were assigned "{task.title}"', task=task,
            )

    def perform_update(self, serializer):
        old = self.get_object()
        old_assignee_id = old.assignee_id
        task = serializer.save()
        if task.assignee_id and task.assignee_id != old_assignee_id:
            Notification.objects.create(
                recipient=task.assignee, notif_type='task_assigned',
                message=f'You were assigned "{task.title}"', task=task,
            )
            ActivityLog.objects.create(task=task, actor=self.request.user,
                                        message=f'assigned task to {task.assignee.username}')

    @action(detail=True, methods=['post'], permission_classes=[IsAdmin])
    def verify(self, request, pk=None):
        """Admin verifies a submitted task → marks as completed."""
        task = self.get_object()
        if not task.submitted_for_review:
            return Response({'detail': 'Task has not been submitted for review.'}, status=400)
        task.is_completed = True
        task.status = 'completed'
        task.submitted_for_review = False
        task.verified_by = request.user
        task.verified_at = timezone.now()

        # Move to Done column
        done_col = task.board.columns.filter(name__iexact='done').first()
        if done_col:
            task.column = done_col
        task.save()

        ActivityLog.objects.create(task=task, actor=request.user, message='verified and completed the task')

        if task.assignee:
            Notification.objects.create(
                recipient=task.assignee, notif_type='task_verified',
                message=f'Your task "{task.title}" has been verified and completed!', task=task,
            )
        return Response(TaskSerializer(task).data)

    @action(detail=True, methods=['post'], permission_classes=[IsAdmin])
    def reassign(self, request, pk=None):
        """Admin reassigns a task to same or different person."""
        task = self.get_object()
        from accounts.models import User
        new_assignee_id = request.data.get('assignee_id')
        try:
            new_assignee = User.objects.get(id=new_assignee_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)

        old_assignee = task.assignee
        task.assignee = new_assignee
        task.submitted_for_review = False
        task.status = 'todo'
        task.is_completed = False
        # Reset to first column
        first_col = task.board.columns.order_by('order').first()
        if first_col:
            task.column = first_col
        task.save()

        ActivityLog.objects.create(
            task=task, actor=request.user,
            message=f'reassigned task to {new_assignee.username}'
        )
        Notification.objects.create(
            recipient=new_assignee, notif_type='task_reassigned',
            message=f'You have been assigned "{task.title}"', task=task,
        )
        if old_assignee and old_assignee != new_assignee:
            Notification.objects.create(
                recipient=old_assignee, notif_type='task_reassigned',
                message=f'"{task.title}" has been reassigned to someone else', task=task,
            )
        return Response(TaskSerializer(task).data)

    @action(detail=True, methods=['get', 'post'])
    def comments(self, request, pk=None):
        task = self.get_object()
        if request.method == 'GET':
            return Response(CommentSerializer(task.comments.select_related('author'), many=True).data)
        serializer = CommentSerializer(data={**request.data, 'task': task.id})
        serializer.is_valid(raise_exception=True)
        comment = serializer.save(author=request.user)
        ActivityLog.objects.create(task=task, actor=request.user, message='added a comment')
        if task.assignee and task.assignee != request.user:
            Notification.objects.create(
                recipient=task.assignee, notif_type='new_comment',
                message=f'New comment on "{task.title}"', task=task,
            )
        return Response(CommentSerializer(comment).data, status=201)

    @action(detail=True, methods=['get', 'post'])
    def subtasks(self, request, pk=None):
        task = self.get_object()
        if request.method == 'GET':
            return Response(SubTaskSerializer(task.subtasks.all(), many=True).data)
        serializer = SubTaskSerializer(data={**request.data, 'task': task.id})
        serializer.is_valid(raise_exception=True)
        serializer.save(created_by=request.user)
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['get', 'post'])
    def checklist(self, request, pk=None):
        task = self.get_object()
        if request.method == 'GET':
            return Response(ChecklistItemSerializer(task.checklist_items.all(), many=True).data)
        serializer = ChecklistItemSerializer(data={**request.data, 'task': task.id})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['get'])
    def activity(self, request, pk=None):
        task = self.get_object()
        return Response(ActivityLogSerializer(task.activity_log.all(), many=True).data)


class SubTaskViewSet(viewsets.ModelViewSet):
    serializer_class = SubTaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return SubTask.objects.filter(task__assignee=self.request.user)

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


class ChecklistItemViewSet(viewsets.ModelViewSet):
    serializer_class = ChecklistItemSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return ChecklistItem.objects.all()
        return ChecklistItem.objects.filter(task__assignee=user)


class LabelViewSet(viewsets.ModelViewSet):
    serializer_class = LabelSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['board']

    def get_queryset(self):
        return Label.objects.all()


class NotificationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user)

    @action(detail=True, methods=['post'])
    def read(self, request, pk=None):
        notif = self.get_object()
        notif.is_read = True
        notif.save()
        return Response(NotificationSerializer(notif).data)

    @action(detail=False, methods=['post'])
    def read_all(self, request):
        self.get_queryset().update(is_read=True)
        return Response({'detail': 'All notifications marked as read.'})


class ActivityLogViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = ActivityLogSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['task']

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return ActivityLog.objects.all()
        return ActivityLog.objects.filter(task__assignee=user)
