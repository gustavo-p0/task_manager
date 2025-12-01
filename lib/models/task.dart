import 'package:uuid/uuid.dart';

///Este arquivo define a estrutura de dados da nossa tarefa. A classe Task representa o nosso "modelo" (Model). Ela contém os campos que uma tarefa terá (id, título, etc.) e métodos úteis para conversão de dados:

///toMap(): Converte o objeto Task em um Map, que é o formato que o sqflite usa para inserir dados no banco.
///fromMap(): Faz o processo inverso, criando um objeto Task a partir de um Map vindo do banco de dados.
///copyWith(): Um método auxiliar para criar uma cópia de uma tarefa, modificando apenas alguns campos, útil para atualizações.

class Task {
  final String id;
  final String title;
  final String description;
  final bool completed;
  final String priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? categoryId;

  // CÂMERA
  final String? photoPath;

  // SENSORES
  final DateTime? completedAt;
  final String? completedBy; // 'manual', 'shake'

  // GPS
  final double? latitude;
  final double? longitude;
  final String? locationName;

  // SYNC
  final String? serverId;
  final int updatedAt;
  final bool synced;

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = 'medium',
    DateTime? createdAt,
    this.dueDate,
    this.categoryId,
    this.photoPath,
    this.completedAt,
    this.completedBy,
    this.latitude,
    this.longitude,
    this.locationName,
    this.serverId,
    int? updatedAt,
    this.synced = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  // Getters auxiliares
  bool get hasPhoto => photoPath != null && photoPath!.isNotEmpty;
  bool get hasLocation => latitude != null && longitude != null;
  bool get wasCompletedByShake => completedBy == 'shake';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'categoryId': categoryId,
      'photoPath': photoPath,
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'server_id': serverId,
      'updated_at': updatedAt,
      'synced': synced ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      completed: map['completed'] == 1,
      priority: map['priority'] ?? 'medium',
      createdAt: DateTime.parse(map['createdAt']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      categoryId: map['categoryId'],
      photoPath: map['photoPath'] as String?,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      completedBy: map['completedBy'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      locationName: map['locationName'] as String?,
      serverId: map['server_id'] as String?,
      updatedAt:
          map['updated_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      synced: (map['synced'] as int? ?? 0) == 1,
    );
  }

  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    String? priority,
    DateTime? dueDate,
    String? categoryId,
    String? photoPath,
    DateTime? completedAt,
    String? completedBy,
    double? latitude,
    double? longitude,
    String? locationName,
    String? serverId,
    int? updatedAt,
    bool? synced,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
      categoryId: categoryId ?? this.categoryId,
      photoPath: photoPath ?? this.photoPath,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      serverId: serverId ?? this.serverId,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  bool get isOverdue {
    if (dueDate == null || completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }
}
