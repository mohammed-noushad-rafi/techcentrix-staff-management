# TechCentrix Staff Management System

Built this as my MCA internship project at TechCentrix Pvt. Ltd., Mysuru. The company wanted a proper system to manage their interns and employees — attendance tracking, task assignment, team coordination — all in one place. This is what I came up with.

## What it does

Three roles — admin, employee, and intern — each with a completely different interface built around what they actually need day to day.

**Admin** gets a live dashboard to manage staff, assign tasks to individuals or teams, see who's checked in right now, approve leaves, and pull attendance reports.

**Staff** get a task board sorted by priority, a GPS-based check-in screen, and a monthly attendance calendar with streaks and stats.

The attendance piece was the most interesting to build. Rather than trusting coordinates from the client, the server computes the actual distance between the staff's location and the office using the Haversine formula. If you're not within range, you can't check in.

## Stack

- Flutter + Provider (Android)
- Django REST Framework
- PostgreSQL
- JWT authentication
- APScheduler for scheduled jobs
- ReportLab for PDF generation

## A few things worth mentioning

- Geo-fence check-in tested on a real device at the actual office location in KR Mohalla, Mysuru
- Auto absent marking runs at 10:30 AM and 7 PM IST every day without any manual trigger
- Admin can assign tasks to a whole team — every member sees it on a shared board
- Attendance report exports a clean PDF with summary stats, a progress ring, and full day-by-day breakdown

## Run locally

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python3 manage.py migrate
python3 manage.py runserver 0.0.0.0:8000
```

```bash
cd frontend
flutter pub get
flutter run
```

Set the office GPS coordinates under Attendance → Office Locations before testing check-in.

## Status

Core features complete and tested. iOS build and FCM push notifications are next on the list.
