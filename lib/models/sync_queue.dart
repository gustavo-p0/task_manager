class SyncQueueItem {
  final int? id;
  final String taskId;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final String data; // JSON do task
  final int createdAt;
  final int retryCount;

  SyncQueueItem({
    this.id,
    required this.taskId,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'operation': operation,
      'data': data,
      'created_at': createdAt,
      'retry_count': retryCount,
    };
  }

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] as int?,
      taskId: json['task_id'] as String,
      operation: json['operation'] as String,
      data: json['data'] as String,
      createdAt: json['created_at'] as int,
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }

  SyncQueueItem copyWith({
    int? id,
    String? taskId,
    String? operation,
    String? data,
    int? createdAt,
    int? retryCount,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      operation: operation ?? this.operation,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
