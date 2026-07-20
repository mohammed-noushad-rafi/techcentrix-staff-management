from django.contrib import admin
from .models import Task, Label, ChecklistItem, Attachment, Comment, ActivityLog, Notification

admin.site.register(Task)
admin.site.register(Label)
admin.site.register(ChecklistItem)
admin.site.register(Attachment)
admin.site.register(Comment)
admin.site.register(ActivityLog)
admin.site.register(Notification)
