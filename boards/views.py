from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from workspaces.models import Workspace
from .models import Board, Column, DEFAULT_COLUMNS
from .serializers import BoardSerializer, ColumnSerializer, ColumnReorderSerializer


class BoardViewSet(viewsets.ModelViewSet):
    """
    /api/boards/                GET (mine), POST (create — auto-creates default columns)
    /api/boards/{id}/            GET, PATCH, DELETE
    /api/boards/{id}/archive/    POST toggle archive
    /api/boards/{id}/columns/    GET list columns, POST create custom column
    """
    serializer_class = BoardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Board.objects.all()
        return Board.objects.filter(workspace__memberships__user=user).distinct()

    def perform_create(self, serializer):
        board = serializer.save(created_by=self.request.user)
        for i, name in enumerate(DEFAULT_COLUMNS):
            Column.objects.create(board=board, name=name, order=i)

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        board = self.get_object()
        board.is_archived = not board.is_archived
        board.save()
        return Response(BoardSerializer(board).data)

    @action(detail=True, methods=['get', 'post'])
    def columns(self, request, pk=None):
        board = self.get_object()
        if request.method == 'GET':
            return Response(ColumnSerializer(board.columns.all(), many=True).data)
        serializer = ColumnSerializer(data={**request.data, 'board': board.id})
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class ColumnViewSet(viewsets.ModelViewSet):
    """
    /api/columns/{id}/    GET, PATCH (rename, reorder, wip_limit), DELETE
    """
    serializer_class = ColumnSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Column.objects.filter(board__workspace__memberships__user=self.request.user).distinct()
