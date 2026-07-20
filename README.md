# TechCentrix Staff Management System

Built this during my MCA final year at St. Philomena's College for TechCentrix Pvt. Ltd., Mysuru. The company was managing everything manually — attendance on paper, tasks over WhatsApp, no proper visibility for anyone. So I built this.

## What it does

The app has three roles — admin, employee, and intern. Each sees a completely different interface tailored to what they actually need.

**Admin** gets a dashboard to manage staff, assign tasks, track who's in the office in real time, approve leaves, and generate attendance reports.

**Staff** get their own task board sorted by priority, a check-in screen that uses their phone's GPS to verify they're actually at the office, and a monthly attendance calendar.

The attendance part was the most interesting to build — instead of trusting the client, the server computes the distance between the staff's GPS coordinates and the office using the Haversine formula. No faking it.

## Stack

- Flutter + Provider (Android)
- Django REST Framework
- PostgreSQL
- JWT authentication
- APScheduler for scheduled jobs
- ReportLab for PDF generation

## A few things I'm proud of

- The geo-fence check-in actually works on a real device pointed at our office in KR Mohalla
- Auto absent marking runs at 10:30 AM and 7 PM daily without any manual trigger
- Team task board — admin can assign tasks to a whole team, every member sees it in a shared board
- Attendance report exports a properly formatted PDF with stats, a progress ring, and a day-by-day breakdown

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

Set the office GPS in the admin app under Attendance → Office Locations before testing check-in.

## Status

Core features are complete and tested on emulator + real device. iOS build and push notifications (FCM) are next.
