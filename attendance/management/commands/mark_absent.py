from datetime import date, datetime, timedelta
from django.core.management.base import BaseCommand
from attendance.models import OfficeLocation, AttendanceRecord
from accounts.models import StaffProfile


class Command(BaseCommand):
    help = 'Mark absent for staff who did not check in after grace period'

    def add_arguments(self, parser):
        parser.add_argument('--date', type=str, default=None)

    def handle(self, *args, **options):
        target_date = date.today()
        if options.get('date'):
            target_date = date.fromisoformat(options['date'])

        now = datetime.now().time()
        marked = 0

        for profile in StaffProfile.objects.filter(status='active').select_related('user'):
            user = profile.user
            if user.role == 'admin':
                continue

            location = (
                OfficeLocation.objects.filter(is_active=True, department=profile.department).first()
                or OfficeLocation.objects.filter(is_active=True, department='').first()
            )
            if not location:
                continue

            from datetime import datetime as dt
            grace_deadline = (
                dt.combine(target_date, location.shift_start)
                + timedelta(minutes=location.grace_minutes)
            ).time()

            if target_date == date.today() and now < grace_deadline:
                continue

            existing = AttendanceRecord.objects.filter(user=user, date=target_date).first()
            if existing:
                if existing.check_in_time is not None:
                    continue
                if existing.status in ('leave', 'holiday', 'wfh', 'half_day', 'absent'):
                    continue
                existing.status = 'absent'
                existing.notes = 'Auto-marked absent: no check-in recorded'
                existing.save()
            else:
                AttendanceRecord.objects.create(
                    user=user, date=target_date, status='absent',
                    office_location=location,
                    notes='Auto-marked absent: no check-in recorded',
                )
            marked += 1

        self.stdout.write(self.style.SUCCESS(f'Done: {marked} marked absent.'))
