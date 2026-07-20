from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Workspace, WorkspaceMembership
from .serializers import WorkspaceSerializer, JoinWorkspaceSerializer, WorkspaceMembershipSerializer


class WorkspaceViewSet(viewsets.ModelViewSet):
    """
    /api/workspaces/                 GET (list mine), POST (create)
    /api/workspaces/{id}/             GET, PATCH, DELETE
    /api/workspaces/join/             POST {invite_code}
    /api/workspaces/{id}/members/     GET list members
    /api/workspaces/{id}/invite/      POST {email or username} (simplified: adds existing user by username)
    """
    serializer_class = WorkspaceSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Workspace.objects.filter(memberships__user=self.request.user).distinct()

    def perform_create(self, serializer):
        workspace = serializer.save(owner=self.request.user)
        WorkspaceMembership.objects.create(workspace=workspace, user=self.request.user, role='admin')

    @action(detail=False, methods=['post'])
    def join(self, request):
        serializer = JoinWorkspaceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            workspace = Workspace.objects.get(invite_code=serializer.validated_data['invite_code'])
        except Workspace.DoesNotExist:
            return Response({'detail': 'Invalid invite code.'}, status=status.HTTP_404_NOT_FOUND)
        membership, created = WorkspaceMembership.objects.get_or_create(
            workspace=workspace, user=request.user, defaults={'role': 'member'}
        )
        return Response(WorkspaceSerializer(workspace).data, status=200 if not created else 201)

    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        workspace = self.get_object()
        memberships = workspace.memberships.select_related('user').all()
        return Response(WorkspaceMembershipSerializer(memberships, many=True).data)

    @action(detail=True, methods=['post'])
    def invite(self, request, pk=None):
        from accounts.models import User
        workspace = self.get_object()
        username = request.data.get('username')
        try:
            user = User.objects.get(username=username)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)
        membership, created = WorkspaceMembership.objects.get_or_create(
            workspace=workspace, user=user, defaults={'role': 'member'}
        )
        return Response(WorkspaceMembershipSerializer(membership).data, status=201 if created else 200)
