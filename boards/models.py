from django.db import models
from django.conf import settings
from workspaces.models import Workspace


class Board(models.Model):
    workspace = models.ForeignKey(Workspace, related_name='boards', on_delete=models.CASCADE)
    name = models.CharField(max_length=120)
    description = models.CharField(max_length=255, blank=True)
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, related_name='created_boards', on_delete=models.CASCADE)
    is_archived = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class Column(models.Model):
    """A workflow stage on a board, e.g. Backlog, To Do, In Progress, Review, Testing, Done."""
    board = models.ForeignKey(Board, related_name='columns', on_delete=models.CASCADE)
    name = models.CharField(max_length=60)
    order = models.PositiveIntegerField(default=0)
    wip_limit = models.PositiveIntegerField(null=True, blank=True, help_text="Optional work-in-progress limit")

    class Meta:
        ordering = ['order']

    def __str__(self):
        return f"{self.board.name} / {self.name}"


DEFAULT_COLUMNS = ['Backlog', 'To Do', 'In Progress', 'Review', 'Testing', 'Done']
