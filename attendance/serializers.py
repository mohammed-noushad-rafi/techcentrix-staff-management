from rest_framework import serializers
from accounts.serializers import UserSerializer
from .models import OfficeLocation, AttendanceRecord, LeaveRequest


class OfficeLocationSerializer(serializers.ModelSerializer):
    class Meta:
        model  = OfficeLocation
        fields = ['id', 'name', 'latitude', 'longitude', 'radius_meters',
                  'shift_start', 'shift_end', 'grace_minutes',
                  'department', 'is_active', 'created_at']
        read_only_fields = ['id', 'created_at']


class AttendanceRecordSerializer(serializers.ModelSerializer):
    user        = UserSerializer(read_only=True)
    full_name   = serializers.SerializerMethodField()
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model  = AttendanceRecord
        fields = [
            'id', 'user', 'full_name', 'date', 'status', 'status_display',
            'check_in_time',  'check_in_lat',  'check_in_lng',
            'check_out_time', 'check_out_lat', 'check_out_lng',
            'late_minutes', 'total_hours',
            'notes', 'marked_by', 'office_location',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'user', 'late_minutes', 'total_hours',
                            'created_at', 'updated_at']

    def get_full_name(self, obj):
        try:
            return obj.user.staff_profile.full_name
        except Exception:
            return obj.user.username


class LeaveRequestSerializer(serializers.ModelSerializer):
    user        = UserSerializer(read_only=True)
    full_name   = serializers.SerializerMethodField()
    days_requested = serializers.ReadOnlyField()
    leave_type_display = serializers.CharField(source='get_leave_type_display', read_only=True)
    status_display     = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model  = LeaveRequest
        fields = [
            'id', 'user', 'full_name',
            'leave_type', 'leave_type_display',
            'from_date', 'to_date', 'days_requested',
            'reason', 'status', 'status_display',
            'reviewed_by', 'reviewed_at', 'admin_note',
            'created_at',
        ]
        read_only_fields = ['id', 'user', 'status', 'reviewed_by',
                            'reviewed_at', 'created_at']

    def get_full_name(self, obj):
        try:
            return obj.user.staff_profile.full_name
        except Exception:
            return obj.user.username
