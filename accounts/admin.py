from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, StaffProfile, Team

class StaffProfileInline(admin.StackedInline):
    model = StaffProfile
    can_delete = False

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    inlines = [StaffProfileInline]
    list_display = ['username', 'email', 'role', 'is_active']
    list_filter = ['role', 'is_active']
    fieldsets = BaseUserAdmin.fieldsets + (('Role', {'fields': ('role',)}),)

@admin.register(StaffProfile)
class StaffProfileAdmin(admin.ModelAdmin):
    list_display = ['full_name', 'department', 'status']

@admin.register(Team)
class TeamAdmin(admin.ModelAdmin):
    list_display = ['name', 'department', 'created_by']
    filter_horizontal = ['members']
