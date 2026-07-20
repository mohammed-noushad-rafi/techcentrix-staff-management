from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    ROLE_CHOICES = [
        ('admin', 'Admin'),
        ('intern', 'Intern'),
        ('employee', 'Employee'),
    ]
    email = models.EmailField(unique=True)
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='intern')

    @property
    def is_admin(self):
        return self.role == 'admin'

    def __str__(self):
        return f"{self.username} ({self.role})"


class StaffProfile(models.Model):
    EXPERIENCE_CHOICES = [
        ('fresher', 'Fresher'),
        ('experienced', 'Experienced'),
    ]
    STATUS_CHOICES = [
        ('active', 'Active'),
        ('inactive', 'Inactive'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='staff_profile')
    full_name = models.CharField(max_length=150)
    phone = models.CharField(max_length=20, blank=True)
    id_number = models.CharField(max_length=50, blank=True)
    photo = models.ImageField(upload_to='staff_photos/', blank=True, null=True)
    college = models.CharField(max_length=150, blank=True)
    degree = models.CharField(max_length=100, blank=True)
    job_role = models.CharField(max_length=100, blank=True)
    experience_type = models.CharField(max_length=15, choices=EXPERIENCE_CHOICES, blank=True)
    years_of_experience = models.PositiveIntegerField(null=True, blank=True)
    department = models.CharField(max_length=100, blank=True)
    skills = models.TextField(blank=True)
    mentor = models.CharField(max_length=150, blank=True)
    start_date = models.DateField(null=True, blank=True)
    end_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='active')
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.full_name} ({self.user.role})"

    @property
    def skills_list(self):
        return [s.strip() for s in self.skills.split(',') if s.strip()]

    @property
    def is_active(self):
        return self.status == 'active'


class Team(models.Model):
    name = models.CharField(max_length=120)
    description = models.CharField(max_length=255, blank=True)
    department = models.CharField(max_length=100, blank=True)
    created_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_teams')
    members = models.ManyToManyField(User, related_name='teams', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name
