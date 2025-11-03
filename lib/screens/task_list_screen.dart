import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../widgets/task_card.dart';
import 'task_form_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  String _filter = 'all'; // all, completed, pending
  String? _categoryFilter; // null = todas, 'no_category' = sem categoria, id = categoria específica
  bool _isLoading = false;
  bool _orderByDueDate = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _checkOverdueTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await DatabaseService.instance.readAll(
      orderByDueDate: _orderByDueDate,
    );
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _checkOverdueTasks() async {
    final tasks = await DatabaseService.instance.readAll();
    final overdueTasks = tasks.where((t) => t.isOverdue).toList();
    
    if (overdueTasks.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Tarefas Vencidas'),
              ],
            ),
            content: Text(
              'Você tem ${overdueTasks.length} tarefa(s) vencida(s):\n\n'
              '${overdueTasks.take(5).map((t) => '• ${t.title}').join('\n')}'
              '${overdueTasks.length > 5 ? '\n... e mais ${overdueTasks.length - 5}' : ''}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  List<Task> get _filteredTasks {
    var tasks = _tasks;

    // Filtro por status
    switch (_filter) {
      case 'completed':
        tasks = tasks.where((t) => t.completed).toList();
        break;
      case 'pending':
        tasks = tasks.where((t) => !t.completed).toList();
        break;
    }

    // Filtro por categoria
    if (_categoryFilter == 'no_category') {
      tasks = tasks.where((t) => t.categoryId == null).toList();
    } else if (_categoryFilter != null) {
      tasks = tasks.where((t) => t.categoryId == _categoryFilter).toList();
    }
    // null = mostra todas as categorias (não filtra)

    return tasks;
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(completed: !task.completed);
    await DatabaseService.instance.update(updated);
    await _loadTasks();
  }

  Future<void> _deleteTask(Task task) async {
    // Confirmar exclusão
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente excluir "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.instance.delete(task.id);
      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarefa excluída'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openTaskForm([Task? task]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskFormScreen(task: task),
      ),
    );

    if (result == true) {
      await _loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTasks = _filteredTasks;
    final stats = _calculateStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Tarefas'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Ordenação
          IconButton(
            icon: Icon(_orderByDueDate ? Icons.sort_by_alpha : Icons.sort),
            tooltip: _orderByDueDate ? 'Ordenar por data de criação' : 'Ordenar por data de vencimento',
            onPressed: () {
              setState(() {
                _orderByDueDate = !_orderByDueDate;
              });
              _loadTasks();
            },
          ),
          // Filtro de Status
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('Todas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(Icons.pending_actions),
                    SizedBox(width: 8),
                    Text('Pendentes'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(Icons.check_circle),
                    SizedBox(width: 8),
                    Text('Concluídas'),
                  ],
                ),
              ),
            ],
          ),
          // Filtro de Categoria
          PopupMenuButton<String?>(
            icon: const Icon(Icons.category),
            onSelected: (value) => setState(() => _categoryFilter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 12),
                    Text('Todas as categorias'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'no_category',
                child: Row(
                  children: [
                    Icon(Icons.category_outlined),
                    SizedBox(width: 12),
                    Text('Sem categoria'),
                  ],
                ),
              ),
              ...Category.defaultCategories.map((cat) => PopupMenuItem(
                    value: cat.id,
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: cat.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(cat.name),
                      ],
                    ),
                  )),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          // Card de Estatísticas
          if (_tasks.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.blue, Colors.blueAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    Icons.list,
                    'Total',
                    stats['total'].toString(),
                  ),
                  _buildStatItem(
                    Icons.pending_actions,
                    'Pendentes',
                    stats['pending'].toString(),
                  ),
                  _buildStatItem(
                    Icons.check_circle,
                    'Concluídas',
                    stats['completed'].toString(),
                  ),
                ],
              ),
            ),

          // Lista de Tarefas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: filteredTasks.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.of(context).size.height * 0.5,
                                child: _buildEmptyState(),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              return TaskCard(
                                task: task,
                                onTap: () => _openTaskForm(task),
                                onToggle: () => _toggleTask(task),
                                onDelete: () => _deleteTask(task),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTaskForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nova Tarefa'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filter) {
      case 'completed':
        message = 'Nenhuma tarefa concluída ainda';
        icon = Icons.check_circle_outline;
        break;
      case 'pending':
        message = 'Nenhuma tarefa pendente';
        icon = Icons.pending_actions;
        break;
      default:
        message = 'Nenhuma tarefa cadastrada';
        icon = Icons.task_alt;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openTaskForm(),
            icon: const Icon(Icons.add),
            label: const Text('Criar primeira tarefa'),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    return {
      'total': _tasks.length,
      'completed': _tasks.where((t) => t.completed).length,
      'pending': _tasks.where((t) => !t.completed).length,
    };
  }
}