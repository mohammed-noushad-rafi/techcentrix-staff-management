from django.db import models
from django.conf import settings
from boards.models import Board, Column


class Task(models.Model):
    PRIORITY_CHOICES = [
        ('low', 'Low'),
        ('medium', 'Medium'),
        ('high', 'High'),
        ('urgent', 'Urgent'),
    ]
    STATUS_CHOICES = [
        ('todo', 'To Do'),
        ('in_progress', 'In Progress'),
        ('review', 'Review'),
        ('done_pending', 'Done - Pending Verification'),
        ('completed', 'Completed'),
        ('reassigned', 'Reassigned'),
    ]

    board = models.ForeignKey(Board, related_name='tasks', on_delete=models.CASCADE)
    column = models.ForeignKey(Column, related_name='tasks', on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    priority = models.CharField(max_length=10, choices=PRIORITY_CHOICES, default='medium')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='todo')
    due_date = models.DateField(null=True, blank=True)

    # Assignment
    assignee = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='assigned_tasks',
                                  null=True, blank=True, on_delete=models.SET_NULL)
    team = models.ForeignKey('accounts.Team', null=True, blank=True,
                              related_name='tasks', on_delete=models.SET_NULL)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='created_tasks',
                                    on_delete=models.CASCADE)

    # Verification
    submitted_for_review = models.BooleanField(default=False)
    verified_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                                     related_name='verified_tasks', on_delete=models.SET_NULL)
    verified_at = models.DateTimeField(null=True, blank=True)

    order = models.PositiveIntegerField(default=0)
    is_completed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['order']

    def __str__(self):
        return self.title

    @property
    def is_overdue(self):
        from django.utils import timezone
        return bool(self.due_date and not self.is_completed and self.due_date < timezone.now().date())


class SubTask(models.Model):
    """Subtasks created by the assignee under their task."""
    task = models.ForeignKey(Task, related_name='subtasks', on_delete=models.CASCADE)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    title = models.CharField(max_length=200)
    is_done = models.BooleanField(default=False)
    order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['order']


class Label(models.Model):
    board = models.ForeignKey(Board, related_name='labels', on_delete=models.CASCADE)
    name = models.CharField(max_length=40)
    color = models.CharField(max_length=7, default='#999999')

    def __str__(self):
        return self.name


class TaskLabel(models.Model):
    task = models.ForeignKey(Task, related_name='task_labels', on_delete=models.CASCADE)
    label = models.ForeignKey(Label, related_name='task_labels', on_delete=models.CASCADE)

    class Meta:
        unique_together = ('task', 'label')


class ChecklistItem(models.Model):
    task = models.ForeignKey(Task, related_name='checklist_items', on_delete=models.CASCADE)
    text = models.CharField(max_length=255)
    is_done = models.BooleanField(default=False)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['order']


class Attachment(models.Model):
    task = models.ForeignKey(Task, related_name='attachments', on_delete=models.CASCADE)
    file = models.FileField(upload_to='attachments/%Y/%m/')
    uploaded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    uploaded_at = models.DateTimeField(auto_now_add=True)


class Comment(models.Model):
    task = models.ForeignKey(Task, related_name='comments', on_delete=models.CASCADE)
    author = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='comments', on_delete=models.CASCADE)
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']


class ActivityLog(models.Model):
    task = models.ForeignKey(Task, related_name='activity_log', on_delete=models.CASCADE)
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    message = models.CharField(max_length=255)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class Notification(models.Model):
    TYPE_CHOICES = [
        ('task_assigned', 'Task Assigned'),
        ('task_reassigned', 'Task Reassigned'),
        ('task_submitted', 'Task Submitted for Review'),
        ('task_verified', 'Task Verified / Completed'),
        ('task_overdue', 'Task Overdue'),
        ('new_comment', 'New Comment'),
        ('team_added', 'Added to Team'),
    ]
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='notifications', on_delete=models.CASCADE)
    notif_type = models.CharField(max_length=30, choices=TYPE_CHOICES)
    message = models.CharField(max_length=255)
    task = models.ForeignKey(Task, null=True, blank=True, on_delete=models.CASCADE)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
