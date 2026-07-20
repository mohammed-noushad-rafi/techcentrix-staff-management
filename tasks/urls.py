from rest_framework.routers import DefaultRouter
from .views import (
    TaskViewSet, SubTaskViewSet, ChecklistItemViewSet,
    LabelViewSet, NotificationViewSet, ActivityLogViewSet,
)

router = DefaultRouter()
router.register('subtasks', SubTaskViewSet, basename='subtask')
router.register('checklist-items', ChecklistItemViewSet, basename='checklist-item')
router.register('labels', LabelViewSet, basename='label')
router.register('notifications', NotificationViewSet, basename='notification')
router.register('activity', ActivityLogViewSet, basename='activity')
router.register('', TaskViewSet, basename='task')
urlpatterns = router.urls
