from rest_framework import serializers
from .models import Board, Column


class ColumnSerializer(serializers.ModelSerializer):
    class Meta:
        model = Column
        fields = ['id', 'name', 'order']


class BoardSerializer(serializers.ModelSerializer):
    columns = ColumnSerializer(many=True, read_only=True)

    class Meta:
        model = Board
        fields = ['id', 'name', 'description', 'workspace', 'columns', 'created_at']
        read_only_fields = ['id', 'created_at']

class ColumnReorderSerializer(serializers.Serializer):
    column_ids = serializers.ListField(child=serializers.IntegerField())
