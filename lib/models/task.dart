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

  Task({
    String? id,
    required this.title,
    this.description = '',
    this.completed = false,
    this.priority = 'medium',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'completed': completed ? 1 : 0,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
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
    );
  }

  Task copyWith({
    String? title,
    String? description,
    bool? completed,
    String? priority,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      completed: completed ?? this.completed,
      priority: priority ?? this.priority,
      createdAt: createdAt,
    );
  }
}