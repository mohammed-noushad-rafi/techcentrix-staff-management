from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from .models import User, StaffProfile, Team
from .serializers import (
    UserSerializer, StaffProfileSerializer,
    CreateStaffSerializer, MeSerializer, TeamSerializer,
)


class IsAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'admin'


class IsAdminOrSelf(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return request.user.role == 'admin' or obj.user == request.user


# ─────────────────────────────────────────
# AUTH
# ─────────────────────────────────────────

class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        from django.contrib.auth import authenticate
        username = request.data.get('username', '').strip()
        password = request.data.get('password', '')
        user = authenticate(username=username, password=password)
        if user is None:
            return Response({'detail': 'Invalid username or password.'}, status=401)
        if not user.is_active:
            return Response({'detail': 'Account is disabled. Contact your admin.'}, status=403)
        refresh = RefreshToken.for_user(user)
        return Response({
            'access': str(refresh.access_token),
            'refresh': str(refresh),
            'user': MeSerializer(user).data,
        })


class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(MeSerializer(request.user).data)

    def patch(self, request):
        # Staff can update their own basic profile info
        try:
            profile = request.user.staff_profile
        except StaffProfile.DoesNotExist:
            return Response({'detail': 'No profile found.'}, status=404)
        serializer = StaffProfileSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(MeSerializer(request.user).data)


# ─────────────────────────────────────────
# ADMIN — STAFF MANAGEMENT
# ─────────────────────────────────────────

class StaffViewSet(viewsets.ModelViewSet):
    """
    /api/staff/                     GET (filter ?role=intern|employee&department=X&search=Y&status=active)
    /api/staff/{id}/                GET, PATCH, DELETE
    /api/staff/{id}/toggle_status/  POST
    /api/staff/{id}/reset_password/ POST {password}
    /api/staff/{id}/tasks/          GET
    /api/staff/{id}/upload_photo/   POST (multipart)
    """
    serializer_class = StaffProfileSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        qs = StaffProfile.objects.select_related('user').all()
        role = self.request.query_params.get('role')
        department = self.request.query_params.get('department')
        status_filter = self.request.query_params.get('status')
        experience = self.request.query_params.get('experience_type')
        search = self.request.query_params.get('search')
        if role:
            qs = qs.filter(user__role=role)
        if department:
            qs = qs.filter(department__icontains=department)
        if status_filter:
            qs = qs.filter(status=status_filter)
        if experience:
            qs = qs.filter(experience_type=experience)
        if search:
            qs = qs.filter(full_name__icontains=search) | qs.filter(job_role__icontains=search) | qs.filter(college__icontains=search)
        return qs.order_by('-created_at')

    def create(self, request, *args, **kwargs):
        serializer = CreateStaffSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(StaffProfileSerializer(user.staff_profile).data, status=201)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        serializer = StaffProfileSerializer(instance, data=request.data, partial=partial)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def toggle_status(self, request, pk=None):
        profile = self.get_object()
        profile.status = 'inactive' if profile.status == 'active' else 'active'
        profile.user.is_active = profile.status == 'active'
        profile.save()
        profile.user.save()
        return Response(StaffProfileSerializer(profile).data)

    @action(detail=True, methods=['post'])
    def reset_password(self, request, pk=None):
        profile = self.get_object()
        password = request.data.get('password', '').strip()
        if len(password) < 6:
            return Response({'detail': 'Password must be at least 6 characters.'}, status=400)
        profile.user.set_password(password)
        profile.user.save()
        return Response({'detail': 'Password updated.'})

    @action(detail=True, methods=['get'])
    def tasks(self, request, pk=None):
        from tasks.serializers import TaskSerializer
        profile = self.get_object()
        tasks = profile.user.assigned_tasks.select_related('column', 'board').order_by('-created_at')
        return Response(TaskSerializer(tasks, many=True).data)

    @action(detail=True, methods=['post'], url_path='upload_photo')
    def upload_photo(self, request, pk=None):
        profile = self.get_object()
        photo = request.FILES.get('photo')
        if not photo:
            return Response({'detail': 'No photo provided.'}, status=400)
        profile.photo = photo
        profile.save()
        return Response(StaffProfileSerializer(profile).data)


# ─────────────────────────────────────────
# ADMIN — TEAM MANAGEMENT
# ─────────────────────────────────────────

class TeamViewSet(viewsets.ModelViewSet):
    """
    /api/teams/                  GET, POST
    /api/teams/{id}/              GET, PATCH, DELETE
    /api/teams/{id}/add_member/   POST {user_id}
    /api/teams/{id}/remove_member/ POST {user_id}
    /api/teams/{id}/tasks/        GET team tasks
    """
    serializer_class = TeamSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Team.objects.all().prefetch_related('members')
        return user.teams.all().prefetch_related('members')

    def perform_create(self, serializer):
        team = serializer.save(created_by=self.request.user)
        # Notify members
        from tasks.models import Notification
        for member in team.members.all():
            Notification.objects.create(
                recipient=member,
                notif_type='team_added',
                message=f'You have been added to team "{team.name}"',
            )

    @action(detail=True, methods=['post'])
    def add_member(self, request, pk=None):
        team = self.get_object()
        user_id = request.data.get('user_id')
        try:
            user = User.objects.get(id=user_id)
            team.members.add(user)
            from tasks.models import Notification
            Notification.objects.create(
                recipient=user, notif_type='team_added',
                message=f'You have been added to team "{team.name}"',
            )
            return Response(TeamSerializer(team).data)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)

    @action(detail=True, methods=['post'])
    def remove_member(self, request, pk=None):
        team = self.get_object()
        user_id = request.data.get('user_id')
        try:
            user = User.objects.get(id=user_id)
            team.members.remove(user)
            return Response(TeamSerializer(team).data)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)

    @action(detail=True, methods=['get'])
    def tasks(self, request, pk=None):
        from tasks.serializers import TaskSerializer
        from tasks.models import Task
        team = self.get_object()
        tasks = Task.objects.filter(team=team).select_related('column', 'board', 'assignee')
        return Response(TaskSerializer(tasks, many=True).data)


# ─────────────────────────────────────────
# ADMIN — DASHBOARD
# ─────────────────────────────────────────

class AdminDashboardView(APIView):
    permission_classes = [IsAdmin]

    def get(self, request):
        from tasks.models import Task, Notification
        total_staff = StaffProfile.objects.count()
        total_interns = StaffProfile.objects.filter(user__role='intern').count()
        total_employees = StaffProfile.objects.filter(user__role='employee').count()
        active_staff = StaffProfile.objects.filter(status='active').count()
        total_tasks = Task.objects.count()
        completed_tasks = Task.objects.filter(is_completed=True).count()
        pending_verification = Task.objects.filter(submitted_for_review=True, is_completed=False).count()
        overdue_tasks = Task.objects.filter(is_completed=False, due_date__lt=timezone.now().date()).count()
        total_teams = Team.objects.count()

        by_department = {}
        for p in StaffProfile.objects.values_list('department', flat=True):
            if p:
                by_department[p] = by_department.get(p, 0) + 1

        unread_admin_notifications = Notification.objects.filter(
            recipient=request.user, is_read=False
        ).count()

        recent_staff = StaffProfileSerializer(
            StaffProfile.objects.order_by('-created_at')[:5], many=True
        ).data

        return Response({
            'total_staff': total_staff,
            'total_interns': total_interns,
            'total_employees': total_employees,
            'active_staff': active_staff,
            'total_tasks': total_tasks,
            'completed_tasks': completed_tasks,
            'pending_verification': pending_verification,
            'overdue_tasks': overdue_tasks,
            'total_teams': total_teams,
            'staff_by_department': by_department,
            'unread_notifications': unread_admin_notifications,
            'recent_staff': recent_staff,
        })


# ─────────────────────────────────────────
# STAFF — SEARCH FOR TASK ASSIGNMENT
# ─────────────────────────────────────────

class StaffSearchView(APIView):
    """GET /api/staff-search/?role=intern&department=IT&skills=python
    Admin uses this when assigning tasks — returns filtered staff list."""
    permission_classes = [IsAdmin]

    def get(self, request):
        qs = StaffProfile.objects.filter(status='active').select_related('user')
        role = request.query_params.get('role')
        department = request.query_params.get('department')
        skills = request.query_params.get('skills')
        experience_type = request.query_params.get('experience_type')
        if role:
            qs = qs.filter(user__role=role)
        if department:
            qs = qs.filter(department__icontains=department)
        if skills:
            qs = qs.filter(skills__icontains=skills)
        if experience_type:
            qs = qs.filter(experience_type=experience_type)
        search = request.query_params.get('search')
        if search:
            from django.db.models import Q
            qs = qs.filter(Q(full_name__icontains=search) | Q(job_role__icontains=search) | Q(college__icontains=search))
        return Response(StaffProfileSerializer(qs, many=True).data)


# ─────────────────────────────────────────
# STAFF — OWN VIEWS
# ─────────────────────────────────────────

class MyTasksView(APIView):
    """GET /api/my-tasks/ — staff sees their own assigned tasks."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from tasks.models import Task
        from tasks.serializers import TaskSerializer
        tasks = Task.objects.filter(
            assignee=request.user
        ).select_related('column', 'board').order_by('column__order', 'order')
        return Response(TaskSerializer(tasks, many=True).data)


class MyTeamsView(APIView):
    """GET /api/my-teams/ — staff sees their teams and team boards."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        teams = request.user.teams.all()
        return Response(TeamSerializer(teams, many=True).data)


class SubmitTaskView(APIView):
    """POST /api/tasks/{id}/submit/ — staff marks task as done, notifies admin."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, task_id):
        from tasks.models import Task, Notification, ActivityLog
        try:
            task = Task.objects.get(id=task_id, assignee=request.user)
        except Task.DoesNotExist:
            return Response({'detail': 'Task not found.'}, status=404)

        task.submitted_for_review = True
        task.status = 'done_pending'

        # Move to Done-Pending column if it exists
        from boards.models import Column
        pending_col = task.board.columns.filter(name__iexact='done').first()
        if pending_col:
            task.column = pending_col
        task.save()

        ActivityLog.objects.create(task=task, actor=request.user, message='submitted task for review')

        # Notify all admins
        for admin in User.objects.filter(role='admin'):
            Notification.objects.create(
                recipient=admin,
                notif_type='task_submitted',
                message=f'{request.user.username} submitted "{task.title}" for review',
                task=task,
            )

        from tasks.serializers import TaskSerializer
        return Response(TaskSerializer(task).data)


class MoveTaskView(APIView):
    """POST /api/tasks/{id}/move/ — staff moves their task between columns."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, task_id):
        from tasks.models import Task, ActivityLog
        from boards.models import Column
        from tasks.serializers import TaskSerializer
        try:
            task = Task.objects.get(id=task_id, assignee=request.user)
        except Task.DoesNotExist:
            return Response({'detail': 'Task not found or not assigned to you.'}, status=404)
        column_id = request.data.get('column')
        order = request.data.get('order', 0)
        try:
            column = Column.objects.get(id=column_id, board=task.board)
        except Column.DoesNotExist:
            return Response({'detail': 'Invalid column.'}, status=400)
        old_col = task.column.name
        task.column = column
        task.order = order

        # Auto-update status based on column
        col_name = column.name.lower()
        if 'backlog' in col_name:
            task.status = 'todo'
        elif 'to do' in col_name or 'todo' in col_name:
            task.status = 'todo'
        elif 'progress' in col_name:
            task.status = 'in_progress'
        elif 'review' in col_name or 'testing' in col_name:
            task.status = 'review'

        task.save()

        if old_col != column.name:
            ActivityLog.objects.create(
                task=task, actor=request.user,
                message=f'moved task from {old_col} to {column.name}'
            )
        return Response(TaskSerializer(task).data)


class MyTeamTasksView(APIView):
    """GET /api/my-team-tasks/  — tasks assigned to teams the user belongs to"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from tasks.models import Task
        from tasks.serializers import TaskSerializer

        user_teams = request.user.teams.all()
        tasks = Task.objects.filter(
            team__in=user_teams
        ).select_related('assignee','team','column','board').order_by('-created_at')

        data = []
        for team in user_teams:
            team_tasks = tasks.filter(team=team)
            if team_tasks.exists():
                data.append({
                    'team_id':   team.id,
                    'team_name': team.name,
                    'department': team.department,
                    'member_count': team.members.count(),
                    'members': [{'id': m.id, 'username': m.username,
                                 'full_name': getattr(m, 'staff_profile', None) and m.staff_profile.full_name or m.username}
                                for m in team.members.all()],
                    'tasks': TaskSerializer(team_tasks, many=True, context={'request': request}).data,
                })
        return Response(data)
