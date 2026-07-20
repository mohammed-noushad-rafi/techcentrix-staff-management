from rest_framework import serializers
from .models import User, StaffProfile, Team


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'date_joined']
        read_only_fields = ['id', 'date_joined']


class StaffProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    role = serializers.CharField(source='user.role', read_only=True)
    skills_list = serializers.ReadOnlyField()
    task_count = serializers.SerializerMethodField()
    completed_task_count = serializers.SerializerMethodField()
    pending_verification_count = serializers.SerializerMethodField()

    class Meta:
        model = StaffProfile
        fields = [
            'id', 'user', 'username', 'email', 'role',
            'full_name', 'phone', 'id_number', 'photo',
            'college', 'degree',
            'job_role', 'experience_type', 'years_of_experience',
            'department', 'skills', 'skills_list',
            'mentor', 'start_date', 'end_date',
            'status', 'notes',
            'task_count', 'completed_task_count', 'pending_verification_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']

    def get_task_count(self, obj):
        return obj.user.assigned_tasks.count()

    def get_completed_task_count(self, obj):
        return obj.user.assigned_tasks.filter(is_completed=True).count()

    def get_pending_verification_count(self, obj):
        return obj.user.assigned_tasks.filter(submitted_for_review=True, is_completed=False).count()


class CreateStaffSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)
    role = serializers.ChoiceField(choices=['intern', 'employee'])
    full_name = serializers.CharField(max_length=150)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    id_number = serializers.CharField(max_length=50, required=False, allow_blank=True)
    department = serializers.CharField(max_length=100, required=False, allow_blank=True)
    skills = serializers.CharField(required=False, allow_blank=True)
    mentor = serializers.CharField(max_length=150, required=False, allow_blank=True)
    start_date = serializers.DateField(required=False, allow_null=True)
    end_date = serializers.DateField(required=False, allow_null=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    college = serializers.CharField(max_length=150, required=False, allow_blank=True)
    degree = serializers.CharField(max_length=100, required=False, allow_blank=True)
    job_role = serializers.CharField(max_length=100, required=False, allow_blank=True)
    experience_type = serializers.ChoiceField(choices=['fresher', 'experienced'], required=False, allow_blank=True)
    years_of_experience = serializers.IntegerField(required=False, allow_null=True, min_value=0)

    def validate_username(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError('Username already exists.')
        return value

    def validate_email(self, value):
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError('Email already exists.')
        return value

    def create(self, validated_data):
        profile_fields = ['full_name', 'phone', 'id_number', 'department', 'skills',
                          'mentor', 'start_date', 'end_date', 'notes',
                          'college', 'degree', 'job_role', 'experience_type', 'years_of_experience']
        profile_data = {k: validated_data.pop(k, None) for k in profile_fields}
        profile_data = {k: v for k, v in profile_data.items() if v is not None}
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            role=validated_data['role'],
        )
        StaffProfile.objects.create(user=user, **profile_data)
        return user


class MeSerializer(serializers.ModelSerializer):
    staff_profile = StaffProfileSerializer(read_only=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'staff_profile', 'date_joined']


class TeamSerializer(serializers.ModelSerializer):
    members = UserSerializer(many=True, read_only=True)
    member_ids = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(), many=True, write_only=True, source='members', required=False
    )
    member_count = serializers.SerializerMethodField()
    created_by = UserSerializer(read_only=True)

    class Meta:
        model = Team
        fields = ['id', 'name', 'description', 'department', 'created_by',
                  'members', 'member_ids', 'member_count', 'created_at']
        read_only_fields = ['id', 'created_by', 'created_at']

    def get_member_count(self, obj):
        return obj.members.count()

    def create(self, validated_data):
        members = validated_data.pop('members', [])
        team = Team.objects.create(**validated_data)
        team.members.set(members)
        return team

    def update(self, instance, validated_data):
        members = validated_data.pop('members', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        if members is not None:
            instance.members.set(members)
        return instance
