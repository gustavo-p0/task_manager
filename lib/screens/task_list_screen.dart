import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/database_service.dart';

/// Este widget é a interface do usuário (UI) da nossa aplicação. Ele é um StatefulWidget porque seu conteúdo (a lista de tarefas) precisa mudar dinamicamente.

/// _loadTasks(): Carrega as tarefas do banco de dados usando nosso DatabaseService e atualiza o estado da tela com setState.
/// _addTask(): Pega o texto do TextField, cria um novo objeto Task e o salva no banco.
/// _toggleTask() e _deleteTask(): Lidam com as ações de marcar uma tarefa como concluída e de excluí-la, respectivamente.
/// build(): Constrói a árvore de widgets, que inclui um AppBar, um TextField para adicionar novas tarefas e um ListView.builder para exibir a lista de tarefas de forma eficiente.


class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  List<Task> _filteredTasks = [];
  final _titleController = TextEditingController();
  String _selectedPriority = 'medium';
  String _selectedFilter = 'todas';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final tasks = await DatabaseService.instance.readAll();
    setState(() {
      _tasks = tasks;
      _applyFilter();
    });
  }

  void _applyFilter() {
    setState(() {
      switch (_selectedFilter) {
        case 'completas':
          _filteredTasks = _tasks.where((task) => task.completed).toList();
          break;
        case 'pendentes':
          _filteredTasks = _tasks.where((task) => !task.completed).toList();
          break;
        default:
          _filteredTasks = _tasks;
      }
    });
  }

  Future<void> _addTask() async {
    if (_titleController.text.trim().isEmpty) return;

    final task = Task(
      title: _titleController.text.trim(),
      priority: _selectedPriority,
    );
    await DatabaseService.instance.create(task);
    _titleController.clear();
    _loadTasks();
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    _loadTasks();
  }

  Future<void> _deleteTask(String id) async {
    await DatabaseService.instance.delete(id);
    _loadTasks();
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return 'Alta';
      case 'medium':
        return 'Média';
      case 'low':
        return 'Baixa';
      default:
        return 'Média';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _tasks.where((task) => task.completed).length;
    final pendingCount = _tasks.where((task) => !task.completed).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total: ${_tasks.length} | Completas: $completedCount | Pendentes: $pendingCount',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filtros
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Filtrar: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedFilter,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedFilter = newValue!;
                      _applyFilter();
                    });
                  },
                  items: const [
                    DropdownMenuItem(value: 'todas', child: Text('Todas')),
                    DropdownMenuItem(value: 'pendentes', child: Text('Pendentes')),
                    DropdownMenuItem(value: 'completas', child: Text('Completas')),
                  ],
                ),
              ],
            ),
          ),
          // Formulário de nova tarefa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          hintText: 'Nova tarefa...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedPriority = newValue!;
                          });
                        },
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Baixa')),
                          DropdownMenuItem(value: 'medium', child: Text('Média')),
                          DropdownMenuItem(value: 'high', child: Text('Alta')),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _addTask,
                      child: const Text('Adicionar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Lista de tarefas
          Expanded(
            child: ListView.builder(
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) {
                final task = _filteredTasks[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: task.completed,
                      onChanged: (_) => _toggleTask(task),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(task.priority).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getPriorityColor(task.priority),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getPriorityText(task.priority),
                            style: TextStyle(
                              color: _getPriorityColor(task.priority),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteTask(task.id),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}