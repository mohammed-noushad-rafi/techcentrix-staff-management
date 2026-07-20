from django.db import models
from django.conf import settings
import math


def haversine_distance(lat1, lng1, lat2, lng2):
    """Returns distance in meters between two GPS coordinates."""
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


class OfficeLocation(models.Model):
    """Admin-configured office geofence. One per department or a global one."""
    name           = models.CharField(max_length=100, default='Main Office')
    latitude       = models.FloatField()
    longitude      = models.FloatField()
    radius_meters  = models.PositiveIntegerField(default=100)
    shift_start    = models.TimeField(default='09:00')
    shift_end      = models.TimeField(default='18:00')
    grace_minutes  = models.PositiveIntegerField(default=15,
                        help_text='Minutes after shift start before marking Late')
    department     = models.CharField(max_length=100, blank=True,
                        help_text='Leave blank to apply to all departments')
    is_active      = models.BooleanField(default=True)
    created_by     = models.ForeignKey(settings.AUTH_USER_MODEL,
                        on_delete=models.SET_NULL, null=True)
    created_at     = models.DateTimeField(auto_now_add=True)
    updated_at     = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.name} ({self.radius_meters}m)"

    def is_within_range(self, lat, lng):
        dist = haversine_distance(self.latitude, self.longitude, lat, lng)
        return dist <= self.radius_meters, round(dist)


class AttendanceRecord(models.Model):
    STATUS_CHOICES = [
        ('present',  'Present'),
        ('late',     'Late'),
        ('absent',   'Absent'),
        ('leave',    'On Leave'),
        ('half_day', 'Half Day'),
        ('holiday',  'Holiday'),
        ('wfh',      'Work From Home'),
    ]

    user           = models.ForeignKey(settings.AUTH_USER_MODEL,
                        related_name='attendance_records', on_delete=models.CASCADE)
    date           = models.DateField()
    status         = models.CharField(max_length=10, choices=STATUS_CHOICES, default='absent')

    # Check-in
    check_in_time  = models.TimeField(null=True, blank=True)
    check_in_lat   = models.FloatField(null=True, blank=True)
    check_in_lng   = models.FloatField(null=True, blank=True)

    # Check-out
    check_out_time = models.TimeField(null=True, blank=True)
    check_out_lat  = models.FloatField(null=True, blank=True)
    check_out_lng  = models.FloatField(null=True, blank=True)

    # Computed
    late_minutes   = models.PositiveIntegerField(default=0)
    total_hours    = models.FloatField(null=True, blank=True)

    # Override
    notes          = models.TextField(blank=True)
    marked_by      = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                        related_name='marked_attendances', on_delete=models.SET_NULL)
    office_location = models.ForeignKey(OfficeLocation, null=True, blank=True,
                        on_delete=models.SET_NULL)
    created_at     = models.DateTimeField(auto_now_add=True)
    updated_at     = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'date')
        ordering = ['-date']

    def __str__(self):
        return f"{self.user.username} – {self.date} – {self.status}"

    def compute_totals(self):
        """Recalculate late_minutes and total_hours after check-in/out."""
        if self.check_in_time and self.office_location:
            from datetime import datetime, timedelta
            shift = self.office_location.shift_start
            grace = self.office_location.grace_minutes
            deadline = (datetime.combine(self.date, shift)
                        + timedelta(minutes=grace)).time()
            if self.check_in_time > deadline:
                delta = (datetime.combine(self.date, self.check_in_time)
                         - datetime.combine(self.date, shift))
                self.late_minutes = max(0, int(delta.total_seconds() / 60) - grace)
                self.status = 'late'
            elif self.status not in ('leave', 'holiday', 'wfh', 'half_day'):
                self.status = 'present'
                self.late_minutes = 0

        if self.check_in_time and self.check_out_time:
            from datetime import datetime
            ci = datetime.combine(self.date, self.check_in_time)
            co = datetime.combine(self.date, self.check_out_time)
            diff = (co - ci).total_seconds()
            self.total_hours = round(diff / 3600, 2) if diff > 0 else None


class LeaveRequest(models.Model):
    LEAVE_TYPE_CHOICES = [
        ('sick',    'Sick Leave'),
        ('casual',  'Casual Leave'),
        ('earned',  'Earned Leave'),
        ('wfh',     'Work From Home'),
        ('other',   'Other'),
    ]
    STATUS_CHOICES = [
        ('pending',  'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    ]

    user        = models.ForeignKey(settings.AUTH_USER_MODEL,
                    related_name='leave_requests', on_delete=models.CASCADE)
    leave_type  = models.CharField(max_length=10, choices=LEAVE_TYPE_CHOICES)
    from_date   = models.DateField()
    to_date     = models.DateField()
    reason      = models.TextField()
    status      = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    reviewed_by = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True,
                    related_name='reviewed_leaves', on_delete=models.SET_NULL)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    admin_note  = models.TextField(blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} – {self.leave_type} ({self.from_date} to {self.to_date})"

    @property
    def days_requested(self):
        return (self.to_date - self.from_date).days + 1
