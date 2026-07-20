from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    AttendanceReportView, AttendanceReportAllView, AttendanceReportPDFView,
    AdminMarkAbsentView,
    OfficeLocationViewSet, LeaveRequestViewSet,
    CheckInView, CheckOutView,
    MyAttendanceView, NearbyCheckView,
    AdminTodayView, AdminStaffAttendanceView,
    AdminOverrideView, AdminPendingLeavesView,
)

router = DefaultRouter()
router.register('office-locations', OfficeLocationViewSet, basename='office-location')
router.register('leaves',           LeaveRequestViewSet,   basename='leave')

urlpatterns = [
    # Staff
    path('check-in/',       CheckInView.as_view(),    name='check_in'),
    path('check-out/',      CheckOutView.as_view(),   name='check_out'),
    path('my/',             MyAttendanceView.as_view(), name='my_attendance'),
    path('nearby/',         NearbyCheckView.as_view(), name='nearby_check'),
    # Admin
    path('admin/today/',    AdminTodayView.as_view(),  name='admin_today'),
    path('admin/override/', AdminOverrideView.as_view(), name='admin_override'),
    path('admin/leaves/pending/', AdminPendingLeavesView.as_view(), name='admin_pending_leaves'),
    path('admin/staff/<int:user_id>/', AdminStaffAttendanceView.as_view(), name='admin_staff_attendance'),
    path('admin/mark-absent/', AdminMarkAbsentView.as_view(), name='admin_mark_absent'),
    path('reports/', AttendanceReportView.as_view(), name='attendance_report'),
    path('reports/all/', AttendanceReportAllView.as_view(), name='attendance_report_all'),
    path('reports/pdf/', AttendanceReportPDFView.as_view(), name='attendance_report_pdf'),
] + router.urls
