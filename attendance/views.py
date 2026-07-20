from datetime import date, datetime, timedelta
from django.utils import timezone
from rest_framework import permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import OfficeLocation, AttendanceRecord, LeaveRequest
from .serializers import (
    OfficeLocationSerializer, AttendanceRecordSerializer, LeaveRequestSerializer
)


class IsAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == 'admin'


# ─────────────────────────────────────────────────────────
# OFFICE LOCATION  (admin only)
# ─────────────────────────────────────────────────────────

class OfficeLocationViewSet(viewsets.ModelViewSet):
    serializer_class   = OfficeLocationSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        return OfficeLocation.objects.all()

    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)


# ─────────────────────────────────────────────────────────
# STAFF — CHECK IN / OUT
# ─────────────────────────────────────────────────────────

class CheckInView(APIView):
    """
    POST /api/attendance/check-in/
    Body: { lat, lng }
    Validates geofence, creates or updates today's record.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.role == 'admin':
            return Response({'detail': 'Admin cannot check in.'}, status=400)

        lat = request.data.get('lat')
        lng = request.data.get('lng')
        if lat is None or lng is None:
            return Response({'detail': 'lat and lng are required.'}, status=400)
        lat, lng = float(lat), float(lng)

        # Find the applicable office location
        dept = getattr(request.user, 'staff_profile', None)
        dept_name = dept.department if dept else ''
        location = (
            OfficeLocation.objects.filter(is_active=True, department=dept_name).first()
            or OfficeLocation.objects.filter(is_active=True, department='').first()
        )
        if not location:
            return Response({'detail': 'No office location configured. Contact admin.'}, status=400)

        within, distance_m = location.is_within_range(lat, lng)
        if not within:
            return Response({
                'detail': f'You are {distance_m}m away from the office. Must be within {location.radius_meters}m to check in.',
                'distance_m': distance_m,
                'within_range': False,
            }, status=400)

        today = date.today()
        record, created = AttendanceRecord.objects.get_or_create(
            user=request.user, date=today,
            defaults={'office_location': location},
        )

        if record.check_in_time:
            return Response({'detail': 'Already checked in today.', 'record': AttendanceRecordSerializer(record).data}, status=200)

        record.check_in_time = timezone.now().time()
        record.check_in_lat  = lat
        record.check_in_lng  = lng
        record.office_location = location
        record.compute_totals()
        record.save()

        return Response({
            'detail': 'Checked in successfully!',
            'within_range': True,
            'distance_m': distance_m,
            'record': AttendanceRecordSerializer(record).data,
        })


class CheckOutView(APIView):
    """POST /api/attendance/check-out/  Body: { lat, lng }"""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        if request.user.role == 'admin':
            return Response({'detail': 'Admin cannot check out.'}, status=400)

        lat = request.data.get('lat')
        lng = request.data.get('lng')
        if lat is None or lng is None:
            return Response({'detail': 'lat and lng are required.'}, status=400)
        lat, lng = float(lat), float(lng)

        today = date.today()
        try:
            record = AttendanceRecord.objects.get(user=request.user, date=today)
        except AttendanceRecord.DoesNotExist:
            return Response({'detail': "You haven't checked in today."}, status=400)

        if not record.check_in_time:
            return Response({'detail': "You haven't checked in today."}, status=400)
        if record.check_out_time:
            return Response({'detail': 'Already checked out today.', 'record': AttendanceRecordSerializer(record).data})

        record.check_out_time = timezone.now().time()
        record.check_out_lat  = lat
        record.check_out_lng  = lng
        record.compute_totals()
        record.save()

        return Response({
            'detail': f'Checked out. Total hours: {record.total_hours}',
            'record': AttendanceRecordSerializer(record).data,
        })


# ─────────────────────────────────────────────────────────
# STAFF — MY ATTENDANCE
# ─────────────────────────────────────────────────────────

class MyAttendanceView(APIView):
    """
    GET /api/attendance/my/?month=7&year=2026
    Returns full month calendar + summary stats.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        today = date.today()
        month = int(request.query_params.get('month', today.month))
        year  = int(request.query_params.get('year',  today.year))

        records = AttendanceRecord.objects.filter(
            user=request.user,
            date__year=year,
            date__month=month,
        ).order_by('date')

        # summary
        total_present  = records.filter(status__in=['present']).count()
        total_late     = records.filter(status='late').count()
        total_absent   = records.filter(status='absent').count()
        total_leave    = records.filter(status='leave').count()
        total_wfh      = records.filter(status='wfh').count()
        avg_hours      = None
        hrs = [r.total_hours for r in records if r.total_hours]
        if hrs:
            avg_hours = round(sum(hrs) / len(hrs), 1)

        # streak (consecutive present/late days up to today)
        streak = 0
        check = today
        while True:
            rec = records.filter(date=check).first()
            if rec and rec.status in ('present', 'late'):
                streak += 1
                check -= timedelta(days=1)
            else:
                break

        # today's record
        today_record = records.filter(date=today).first()

        # active office location
        dept = getattr(request.user, 'staff_profile', None)
        dept_name = dept.department if dept else ''
        location = (
            OfficeLocation.objects.filter(is_active=True, department=dept_name).first()
            or OfficeLocation.objects.filter(is_active=True, department='').first()
        )

        return Response({
            'month': month, 'year': year,
            'records': AttendanceRecordSerializer(records, many=True).data,
            'summary': {
                'present': total_present,
                'late': total_late,
                'absent': total_absent,
                'leave': total_leave,
                'wfh': total_wfh,
                'avg_hours': avg_hours,
                'streak': streak,
            },
            'today': AttendanceRecordSerializer(today_record).data if today_record else None,
            'office_location': OfficeLocationSerializer(location).data if location else None,
        })


# ─────────────────────────────────────────────────────────
# LEAVE REQUESTS
# ─────────────────────────────────────────────────────────

class LeaveRequestViewSet(viewsets.ModelViewSet):
    serializer_class   = LeaveRequestSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == 'admin':
            qs = LeaveRequest.objects.select_related('user').all()
            pending = self.request.query_params.get('pending')
            if pending == '1':
                qs = qs.filter(status='pending')
            return qs
        return LeaveRequest.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=True, methods=['post'], permission_classes=[IsAdmin])
    def approve(self, request, pk=None):
        leave = self.get_object()
        leave.status      = 'approved'
        leave.reviewed_by = request.user
        leave.reviewed_at = timezone.now()
        leave.admin_note  = request.data.get('note', '')
        leave.save()
        # Create attendance records for the leave period
        d = leave.from_date
        while d <= leave.to_date:
            AttendanceRecord.objects.update_or_create(
                user=leave.user, date=d,
                defaults={'status': 'leave', 'marked_by': request.user,
                          'notes': f'Leave: {leave.leave_type}'},
            )
            d += timedelta(days=1)
        return Response(LeaveRequestSerializer(leave).data)

    @action(detail=True, methods=['post'], permission_classes=[IsAdmin])
    def reject(self, request, pk=None):
        leave = self.get_object()
        leave.status      = 'rejected'
        leave.reviewed_by = request.user
        leave.reviewed_at = timezone.now()
        leave.admin_note  = request.data.get('note', '')
        leave.save()
        return Response(LeaveRequestSerializer(leave).data)


# ─────────────────────────────────────────────────────────
# ADMIN — TODAY LIVE VIEW
# ─────────────────────────────────────────────────────────

class AdminTodayView(APIView):
    """GET /api/attendance/admin/today/ — live snapshot of today's attendance."""
    permission_classes = [IsAdmin]

    def get(self, request):
        from accounts.models import StaffProfile
        today   = date.today()
        records = AttendanceRecord.objects.filter(date=today).select_related('user')

        checked_in     = records.filter(check_in_time__isnull=False, check_out_time__isnull=True)
        checked_out    = records.filter(check_out_time__isnull=False)
        late_today     = records.filter(status='late')
        on_leave_today = records.filter(status='leave')

        total_staff = StaffProfile.objects.filter(status='active').count()
        absent_count = total_staff - records.exclude(status__in=['absent']).count()

        absent_today = records.filter(status='absent')

        return Response({
            'date': str(today),
            'total_active_staff': total_staff,
            'checked_in_count':  checked_in.count(),
            'checked_out_count': checked_out.count(),
            'late_count':        late_today.count(),
            'on_leave_count':    on_leave_today.count(),
            'absent_count':      max(0, absent_count),
            'checked_in':  AttendanceRecordSerializer(checked_in,  many=True).data,
            'checked_out': AttendanceRecordSerializer(checked_out, many=True).data,
            'late':        AttendanceRecordSerializer(late_today,  many=True).data,
            'on_leave':    AttendanceRecordSerializer(on_leave_today, many=True).data,
            'absent':      AttendanceRecordSerializer(absent_today, many=True).data,
        })


class AdminStaffAttendanceView(APIView):
    """GET /api/attendance/admin/staff/{user_id}/?month=7&year=2026"""
    permission_classes = [IsAdmin]

    def get(self, request, user_id):
        from accounts.models import User
        today = date.today()
        month = int(request.query_params.get('month', today.month))
        year  = int(request.query_params.get('year',  today.year))
        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)

        records = AttendanceRecord.objects.filter(
            user=user, date__year=year, date__month=month).order_by('date')

        total_present = records.filter(status='present').count()
        total_late    = records.filter(status='late').count()
        total_absent  = records.filter(status='absent').count()
        total_leave   = records.filter(status='leave').count()
        hrs = [r.total_hours for r in records if r.total_hours]
        avg_hours = round(sum(hrs)/len(hrs), 1) if hrs else None

        return Response({
            'user': {'id': user.id, 'username': user.username},
            'month': month, 'year': year,
            'records': AttendanceRecordSerializer(records, many=True).data,
            'summary': {
                'present': total_present, 'late': total_late,
                'absent': total_absent,   'leave': total_leave,
                'avg_hours': avg_hours,
            },
        })


class AdminOverrideView(APIView):
    """
    POST /api/attendance/admin/override/
    Body: { user_id, date, status, notes }
    Admin manually marks attendance for any staff member.
    """
    permission_classes = [IsAdmin]

    def post(self, request):
        from accounts.models import User
        user_id = request.data.get('user_id')
        d       = request.data.get('date')
        stat    = request.data.get('status')
        notes   = request.data.get('notes', '')

        if not all([user_id, d, stat]):
            return Response({'detail': 'user_id, date, and status are required.'}, status=400)

        try:
            user = User.objects.get(id=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)

        record, _ = AttendanceRecord.objects.update_or_create(
            user=user, date=d,
            defaults={'status': stat, 'notes': notes, 'marked_by': request.user},
        )
        return Response(AttendanceRecordSerializer(record).data)


class AdminPendingLeavesView(APIView):
    """GET /api/attendance/admin/leaves/pending/"""
    permission_classes = [IsAdmin]

    def get(self, request):
        leaves = LeaveRequest.objects.filter(status='pending').select_related('user')
        return Response(LeaveRequestSerializer(leaves, many=True).data)


class NearbyCheckView(APIView):
    """
    GET /api/attendance/nearby/?lat=X&lng=Y
    Returns distance to office + whether within geofence.
    Staff call this on the check-in screen to show live distance.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        if not lat or not lng:
            return Response({'detail': 'lat and lng required.'}, status=400)
        lat, lng = float(lat), float(lng)

        dept = getattr(request.user, 'staff_profile', None)
        dept_name = dept.department if dept else ''
        location = (
            OfficeLocation.objects.filter(is_active=True, department=dept_name).first()
            or OfficeLocation.objects.filter(is_active=True, department='').first()
        )
        if not location:
            return Response({'detail': 'No office location configured.'}, status=400)

        within, distance_m = location.is_within_range(lat, lng)
        return Response({
            'within_range': within,
            'distance_m':   distance_m,
            'radius_m':     location.radius_meters,
            'office':       OfficeLocationSerializer(location).data,
        })


class AdminMarkAbsentView(APIView):
    """
    POST /api/attendance/admin/mark-absent/
    Body (optional): { "date": "2026-07-15" }
    Admin manually triggers the absent-marking job for a given date.
    """
    permission_classes = [IsAdmin]

    def post(self, request):
        from django.core.management import call_command
        from io import StringIO
        target_date = request.data.get('date', None)
        out = StringIO()
        try:
            if target_date:
                call_command('mark_absent', date=target_date, stdout=out)
            else:
                call_command('mark_absent', stdout=out)
            return Response({
                'detail': 'Absent marking complete.',
                'log': out.getvalue(),
            })
        except Exception as e:
            return Response({'detail': str(e)}, status=400)


class AttendanceReportView(APIView):
    """
    GET /api/attendance/reports/?staff_id=X&from_date=YYYY-MM-DD&to_date=YYYY-MM-DD
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        from accounts.models import User
        from datetime import date, timedelta

        staff_id  = request.query_params.get('staff_id')
        from_str  = request.query_params.get('from_date')
        to_str    = request.query_params.get('to_date')

        if request.user.role == 'admin':
            if not staff_id:
                return Response({'detail': 'staff_id required.'}, status=400)
            try:
                user = User.objects.get(id=staff_id)
            except User.DoesNotExist:
                return Response({'detail': 'User not found.'}, status=404)
        else:
            user = request.user

        today = date.today()
        from_date = date.fromisoformat(from_str) if from_str else date(today.year, today.month, 1)
        to_date   = date.fromisoformat(to_str)   if to_str   else today

        records = AttendanceRecord.objects.filter(
            user=user, date__gte=from_date, date__lte=to_date).order_by('date')

        daily = []
        d = from_date
        while d <= to_date:
            rec = records.filter(date=d).first()
            daily.append({
                'date':         str(d),
                'day':          d.strftime('%a'),
                'status':       rec.status if rec else ('future' if d > today else 'absent'),
                'status_display': rec.get_status_display() if rec else ('—' if d > today else 'Absent'),
                'check_in':     rec.check_in_time.strftime('%I:%M %p') if rec and rec.check_in_time else '—',
                'check_out':    rec.check_out_time.strftime('%I:%M %p') if rec and rec.check_out_time else '—',
                'late_minutes': rec.late_minutes if rec else 0,
                'total_hours':  rec.total_hours if rec else None,
                'is_weekend':   d.weekday() >= 5,
                'notes':        rec.notes if rec else '',
            })
            d += timedelta(days=1)

        working_days   = sum(1 for r in daily if not r['is_weekend'] and r['date'] <= str(today))
        present_days   = records.filter(status='present').count()
        late_days      = records.filter(status='late').count()
        absent_days    = records.filter(status='absent').count()
        leave_days     = records.filter(status='leave').count()
        wfh_days       = records.filter(status='wfh').count()
        holiday_days   = records.filter(status='holiday').count()
        total_late_min = sum(r.late_minutes for r in records if r.late_minutes)
        hours_list     = [r.total_hours for r in records if r.total_hours]
        total_hours    = round(sum(hours_list), 2) if hours_list else 0
        avg_hours      = round(total_hours / len(hours_list), 2) if hours_list else 0
        attendance_pct = round((present_days + late_days) / working_days * 100, 1) if working_days else 0

        try:
            p = user.staff_profile
            profile_data = {'full_name': p.full_name, 'department': p.department,
                            'job_role': p.job_role, 'college': p.college, 'role': user.role}
        except Exception:
            profile_data = {'full_name': user.username, 'department': '', 'job_role': '', 'college': '', 'role': user.role}

        return Response({
            'staff':   profile_data,
            'period':  {'from_date': str(from_date), 'to_date': str(to_date),
                        'total_days': (to_date-from_date).days+1, 'working_days': working_days},
            'summary': {'present': present_days, 'late': late_days, 'absent': absent_days,
                        'leave': leave_days, 'wfh': wfh_days, 'holiday': holiday_days,
                        'total_hours': total_hours, 'avg_hours': avg_hours,
                        'total_late_min': total_late_min, 'attendance_pct': attendance_pct},
            'daily':   daily,
        })


class AttendanceReportAllView(APIView):
    """GET /api/attendance/reports/all/?from_date=X&to_date=Y  Admin only."""
    permission_classes = [IsAdmin]

    def get(self, request):
        from accounts.models import StaffProfile
        from datetime import date, timedelta
        today     = date.today()
        from_date = date.fromisoformat(request.query_params.get('from_date', str(date(today.year, today.month, 1))))
        to_date   = date.fromisoformat(request.query_params.get('to_date', str(today)))
        working_days = sum(1 for i in range((to_date-from_date).days+1)
                           if (from_date+timedelta(days=i)).weekday() < 5)
        result = []
        for profile in StaffProfile.objects.filter(status='active').select_related('user'):
            user = profile.user
            if user.role == 'admin': continue
            records = AttendanceRecord.objects.filter(user=user, date__gte=from_date, date__lte=to_date)
            present = records.filter(status__in=['present','late']).count()
            late    = records.filter(status='late').count()
            absent  = records.filter(status='absent').count()
            hours_list  = [r.total_hours for r in records if r.total_hours]
            total_hours = round(sum(hours_list), 2) if hours_list else 0
            pct = round(present / working_days * 100, 1) if working_days else 0
            result.append({
                'user_id': user.id, 'full_name': profile.full_name,
                'role': user.role, 'department': profile.department,
                'present': present, 'absent': absent, 'late': late,
                'total_hours': total_hours, 'attendance_pct': pct,
            })
        result.sort(key=lambda x: x['attendance_pct'], reverse=True)
        return Response({'period': {'from_date': str(from_date), 'to_date': str(to_date),
                                    'working_days': working_days},
                         'staff_count': len(result), 'staff': result})


class AttendanceReportPDFView(APIView):
    """GET /api/attendance/reports/pdf/?staff_id=X&from_date=X&to_date=Y"""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        try:
            from reportlab.lib.pagesizes import A4
            from reportlab.lib import colors
            from reportlab.lib.styles import getSampleStyleSheet
            from reportlab.lib.units import cm
            from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, HRFlowable
            import io
            from django.http import HttpResponse
        except ImportError:
            return Response({'detail': 'reportlab not installed. Run: pip install reportlab'}, status=500)

        report_view = AttendanceReportView()
        data_response = AttendanceReportView().get(request)
        if data_response.status_code != 200:
            return data_response
        data = data_response.data

        from datetime import date
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4,
            topMargin=1.5*cm, bottomMargin=1.5*cm, leftMargin=2*cm, rightMargin=2*cm)
        styles = getSampleStyleSheet()
        BLUE  = colors.HexColor('#1B9CD8')
        GRAY  = colors.HexColor('#6B7280')
        LIGHT = colors.HexColor('#F0F8FF')
        story = []

        # Header
        hdr = Table([[
            Paragraph('<font color="#1B9CD8" size="20"><b>techCentrix</b></font><br/><font color="#6B7280" size="9">Smart Staff Management System</font>', styles['Normal']),
            Paragraph(f'<font color="#6B7280" size="9"><b>ATTENDANCE REPORT</b><br/>Generated: {date.today().strftime("%d %B %Y")}</font>', styles['Normal']),
        ]], colWidths=[10*cm, 7*cm])
        hdr.setStyle(TableStyle([('ALIGN',(1,0),(1,0),'RIGHT'),('LINEBELOW',(0,0),(-1,0),2,BLUE),('BOTTOMPADDING',(0,0),(-1,0),10)]))
        story += [hdr, Spacer(1, 0.4*cm)]

        staff   = data['staff']
        period  = data['period']
        summary = data['summary']
        name    = staff.get('full_name','Staff')
        role_detail = staff.get('job_role') or staff.get('college') or ''

        info = Table([
            ['Name',       name,          'Period',       f"{period['from_date']}  →  {period['to_date']}"],
            ['Department', staff.get('department','—'), 'Working Days', str(period['working_days'])],
            ['Role',       f"{role_detail} ({staff.get('role','').capitalize()})", 'Attendance %', f"{summary['attendance_pct']}%"],
        ], colWidths=[3*cm, 6.5*cm, 3*cm, 4.5*cm])
        info.setStyle(TableStyle([
            ('BACKGROUND',(0,0),(0,-1),LIGHT),('BACKGROUND',(2,0),(2,-1),LIGHT),
            ('TEXTCOLOR',(0,0),(0,-1),BLUE),('TEXTCOLOR',(2,0),(2,-1),BLUE),
            ('FONTNAME',(0,0),(0,-1),'Helvetica-Bold'),('FONTNAME',(2,0),(2,-1),'Helvetica-Bold'),
            ('FONTSIZE',(0,0),(-1,-1),9),('GRID',(0,0),(-1,-1),0.5,colors.HexColor('#E5E7EB')),
            ('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6),('LEFTPADDING',(0,0),(-1,-1),8),
        ]))
        story += [info, Spacer(1, 0.5*cm)]

        # Stats
        stats_data = [[
            Paragraph(f'<font color="{c}" size="16"><b>{summary[k]}</b></font><br/><font color="#6B7280" size="8">{l}</font>', styles['Normal'])
            for k,l,c in [
                ('present','Present','#10B981'),('late','Late','#F7941D'),
                ('absent','Absent','#EF4444'),('leave','Leave','#1B9CD8'),
                ('wfh','WFH','#0D9488'),('total_hours','Total Hrs','#8B5CF6'),
                ('avg_hours','Avg Hrs/Day','#0369A1'),('total_late_min','Late Mins','#D97706'),
            ]
        ]]
        stats_tbl = Table(stats_data, colWidths=[2.125*cm]*8)
        stats_tbl.setStyle(TableStyle([
            ('ALIGN',(0,0),(-1,-1),'CENTER'),('BACKGROUND',(0,0),(-1,-1),LIGHT),
            ('BOX',(0,0),(-1,-1),1,BLUE),('INNERGRID',(0,0),(-1,-1),0.5,colors.HexColor('#DBEAFE')),
            ('TOPPADDING',(0,0),(-1,-1),10),('BOTTOMPADDING',(0,0),(-1,-1),10),
        ]))
        story += [stats_tbl, Spacer(1, 0.5*cm)]

        story.append(Paragraph('<b><font color="#1A1A2E" size="10">Daily Attendance Record</font></b>', styles['Normal']))
        story.append(Spacer(1, 0.2*cm))

        SC = {'present':'#10B981','late':'#F7941D','absent':'#EF4444',
              'leave':'#1B9CD8','wfh':'#0D9488','holiday':'#8B5CF6','future':'#9CA3AF'}
        BG = {'present':colors.HexColor('#F0FDF4'),'late':colors.HexColor('#FFF7ED'),
              'absent':colors.HexColor('#FEF2F2'),'leave':colors.HexColor('#EFF6FF'),
              'wfh':colors.HexColor('#F0FDFA'),'holiday':colors.HexColor('#FAF5FF'),
              'future':colors.HexColor('#F9FAFB')}

        rows    = [['Date','Day','Status','Check In','Check Out','Hours','Late(min)','Notes']]
        bg_list = [BLUE]
        for row in data['daily']:
            sc = SC.get(row['status'],'#6B7280')
            rows.append([
                row['date'], row['day'],
                Paragraph(f'<font color="{sc}"><b>{row["status_display"]}</b></font>', styles['Normal']),
                row['check_in'], row['check_out'],
                f"{row['total_hours']}h" if row['total_hours'] else '—',
                str(row['late_minutes']) if row['late_minutes'] else '—',
                (row['notes'][:28]+'…' if len(row['notes'])>28 else row['notes']) if row['notes'] else '—',
            ])
            bg_list.append(colors.HexColor('#F1F5F9') if row['is_weekend'] else BG.get(row['status'], colors.white))

        dtbl = Table(rows, colWidths=[2.4*cm,1*cm,2.5*cm,2*cm,2*cm,1.5*cm,1.6*cm,4*cm])
        cmds = [
            ('BACKGROUND',(0,0),(-1,0),BLUE),('TEXTCOLOR',(0,0),(-1,0),colors.white),
            ('FONTNAME',(0,0),(-1,0),'Helvetica-Bold'),('FONTSIZE',(0,0),(-1,-1),8),
            ('GRID',(0,0),(-1,-1),0.3,colors.HexColor('#E5E7EB')),
            ('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),
            ('LEFTPADDING',(0,0),(-1,-1),5),('ALIGN',(0,0),(-1,-1),'CENTER'),
            ('ALIGN',(0,0),(0,-1),'LEFT'),('ALIGN',(7,0),(7,-1),'LEFT'),
        ]
        for i,bg in enumerate(bg_list[1:],1):
            cmds.append(('BACKGROUND',(0,i),(-1,i),bg))
        dtbl.setStyle(TableStyle(cmds))
        story += [dtbl, Spacer(1, 0.5*cm)]

        story.append(HRFlowable(width='100%', thickness=0.5, color=GRAY))
        story.append(Spacer(1, 0.2*cm))
        story.append(Paragraph(
            '<font color="#9CA3AF" size="7">System-generated report • TechCentrix Smart Staff Management System • Confidential</font>',
            styles['Normal']))

        doc.build(story)
        buffer.seek(0)
        from django.http import HttpResponse
        response = HttpResponse(buffer.read(), content_type='application/pdf')
        safe = name.replace(' ','_')
        response['Content-Disposition'] = f'attachment; filename="TechCentrix_{safe}_{period["from_date"]}.pdf"'
        return response
