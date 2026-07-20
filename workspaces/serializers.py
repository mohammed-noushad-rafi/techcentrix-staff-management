from rest_framework import serializers
from accounts.serializers import UserSerializer
from .models import Workspace, WorkspaceMembership


class WorkspaceMembershipSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = WorkspaceMembership
        fields = ['id', 'user', 'role', 'joined_at']


class WorkspaceSerializer(serializers.ModelSerializer):
    owner = UserSerializer(read_only=True)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Workspace
        fields = ['id', 'name', 'description', 'owner', 'invite_code', 'member_count', 'created_at']
        read_only_fields = ['id', 'owner', 'invite_code', 'created_at']

    def get_member_count(self, obj):
        return obj.memberships.count()


class JoinWorkspaceSerializer(serializers.Serializer):
    invite_code = serializers.UUIDField()
