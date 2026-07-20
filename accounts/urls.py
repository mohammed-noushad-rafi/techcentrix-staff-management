from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    MyTeamTasksView,
    LoginView, MeView,
    StaffViewSet, TeamViewSet,
    AdminDashboardView, StaffSearchView,
    MyTasksView, MyTeamsView,
    SubmitTaskView, MoveTaskView,
)

router = DefaultRouter()
router.register('staff', StaffViewSet, basename='staff')
router.register('teams', TeamViewSet, basename='team')

urlpatterns = [
    path('auth/login/', LoginView.as_view(), name='login'),
    path('auth/login/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/me/', MeView.as_view(), name='me'),
    path('admin/dashboard/', AdminDashboardView.as_view(), name='admin_dashboard'),
    path('staff-search/', StaffSearchView.as_view(), name='staff_search'),
    path('my-tasks/', MyTasksView.as_view(), name='my_tasks'),
    path('my-team-tasks/', MyTeamTasksView.as_view(), name='my_team_tasks'),
    path('my-teams/', MyTeamsView.as_view(), name='my_teams'),
    path('tasks/<int:task_id>/submit/', SubmitTaskView.as_view(), name='submit_task'),
    path('tasks/<int:task_id>/move/', MoveTaskView.as_view(), name='move_task'),
] + router.urls
