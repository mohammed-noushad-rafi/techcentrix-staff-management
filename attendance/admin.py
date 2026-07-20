from django.contrib import admin
from .models import OfficeLocation, AttendanceRecord, LeaveRequest

@admin.register(OfficeLocation)
class OfficeLocationAdmin(admin.ModelAdmin):
    list_display = ['name', 'latitude', 'longitude', 'radius_meters', 'shift_start', 'shift_end', 'is_active']

@admin.register(AttendanceRecord)
class AttendanceRecordAdmin(admin.ModelAdmin):
    list_display  = ['user', 'date', 'status', 'check_in_time', 'check_out_time', 'total_hours', 'late_minutes']
    list_filter   = ['status', 'date']
    search_fields = ['user__username']
    date_hierarchy = 'date'

@admin.register(LeaveRequest)
class LeaveRequestAdmin(admin.ModelAdmin):
    list_display = ['user', 'leave_type', 'from_date', 'to_date', 'status', 'created_at']
    list_filter  = ['status', 'leave_type']
