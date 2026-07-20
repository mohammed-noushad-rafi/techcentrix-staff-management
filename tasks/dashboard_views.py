from django.utils import timezone
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from boards.models import Board
from .models import Task, ActivityLog
from .serializers import ActivityLogSerializer


class DashboardView(APIView):
    """GET /api/dashboard/ — summary counts + recent activity for the logged-in user."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        boards = Board.objects.filter(workspace__memberships__user=user).distinct()
        tasks = Task.objects.filter(board__in=boards)
        today = timezone.now().date()

        recent_activity = ActivityLog.objects.filter(task__board__in=boards).select_related(
            'actor', 'task'
        ).order_by('-created_at')[:10]

        return Response({
            'total_boards': boards.count(),
            'active_tasks': tasks.filter(is_completed=False).count(),
            'completed_tasks': tasks.filter(is_completed=True).count(),
            'overdue_tasks': tasks.filter(is_completed=False, due_date__lt=today).count(),
            'my_tasks': tasks.filter(assignee=user, is_completed=False).count(),
            'recent_activities': ActivityLogSerializer(recent_activity, many=True).data,
        })


class AnalyticsView(APIView):
    """GET /api/analytics/?board=<id> — task distribution & productivity stats."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        boards = Board.objects.filter(workspace__memberships__user=request.user).distinct()
        board_id = request.query_params.get('board')
        tasks = Task.objects.filter(board__in=boards)
        if board_id:
            tasks = tasks.filter(board_id=board_id)

        by_column = {}
        for t in tasks.select_related('column'):
            by_column[t.column.name] = by_column.get(t.column.name, 0) + 1

        by_priority = {}
        for choice, _ in Task.PRIORITY_CHOICES:
            by_priority[choice] = tasks.filter(priority=choice).count()

        today = timezone.now().date()
        return Response({
            'task_distribution_by_column': by_column,
            'task_distribution_by_priority': by_priority,
            'completed': tasks.filter(is_completed=True).count(),
            'pending': tasks.filter(is_completed=False).count(),
            'overdue': tasks.filter(is_completed=False, due_date__lt=today).count(),
        })
