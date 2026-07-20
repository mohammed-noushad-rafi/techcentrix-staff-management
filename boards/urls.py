from rest_framework.routers import DefaultRouter
from .views import BoardViewSet, ColumnViewSet

router = DefaultRouter()
router.register('columns', ColumnViewSet, basename='column')
router.register('', BoardViewSet, basename='board')
urlpatterns = router.urls
