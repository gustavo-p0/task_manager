import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/category.dart';
import '../services/database_service.dart';
import '../services/sensor_service.dart';
import '../services/location_service.dart';
import '../services/camera_service.dart';
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
  String? _categoryFilter = 'all_categories'; // 'all_categories' = todas, 'no_category' = sem categoria, id = categoria específica
  bool _isLoading = false;
  bool _orderByDueDate = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _checkOverdueTasks();
    _setupShakeDetection();
  }

  @override
  void dispose() {
    SensorService.instance.stop();
    super.dispose();
  }

  // SHAKE DETECTION
  void _setupShakeDetection() {
    SensorService.instance.startShakeDetection(() {
      _showShakeDialog();
    });
  }

  void _showShakeDialog() {
    final pendingTasks = _tasks.where((t) => !t.completed).toList();

    if (pendingTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Nenhuma tarefa pendente!'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vibration, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(child: Text('Shake detectado!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selecione uma tarefa para completar:'),
            const SizedBox(height: 16),
            ...pendingTasks.take(3).map((task) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () => _completeTaskByShake(task),
              ),
            )),
            if (pendingTasks.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+ ${pendingTasks.length - 3} outras',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTaskByShake(Task task) async {
    try {
      final updated = task.copyWith(
        completed: true,
        completedAt: DateTime.now(),
        completedBy: 'shake',
      );

      await DatabaseService.instance.update(updated);
      Navigator.pop(context);
      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${task.title}" completa via shake!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      case 'nearby':
        // Filtro de proximidade é aplicado separadamente
        break;
    }

    // Filtro por categoria
    if (_categoryFilter == 'no_category') {
      tasks = tasks.where((t) => t.categoryId == null).toList();
    } else if (_categoryFilter != null && _categoryFilter != 'all_categories') {
      tasks = tasks.where((t) => t.categoryId == _categoryFilter).toList();
    }
    // null ou 'all_categories' = mostra todas as categorias (não filtra)

    return tasks;
  }

  Future<void> _filterByNearby() async {
    final position = await LocationService.instance.getCurrentLocation();

    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Não foi possível obter localização'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final nearbyTasks = await DatabaseService.instance.getTasksNearLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusInMeters: 1000,
    );

    setState(() {
      _tasks = nearbyTasks;
      _filter = 'nearby';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 ${nearbyTasks.length} tarefa(s) próxima(s)'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  Future<void> _toggleTask(Task task) async {
    final updated = task.copyWith(
      completed: !task.completed,
      completedAt: !task.completed ? DateTime.now() : null,
      completedBy: !task.completed ? 'manual' : null,
    );
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
      try {
        if (task.hasPhoto) {
          await CameraService.instance.deletePhoto(task.photoPath!);
        }

        await DatabaseService.instance.delete(task.id);
        await _loadTasks();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Tarefa deletada'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
            onSelected: (value) {
              if (value == 'nearby') {
                _filterByNearby();
              } else {
                setState(() {
                  _filter = value;
                  if (value != 'nearby') _loadTasks();
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.list,
                      color: _filter == 'all' ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Todas',
                      style: TextStyle(
                        fontWeight: _filter == 'all' ? FontWeight.bold : FontWeight.normal,
                        color: _filter == 'all' ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pending',
                child: Row(
                  children: [
                    Icon(
                      Icons.pending_actions,
                      color: _filter == 'pending' ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pendentes',
                      style: TextStyle(
                        fontWeight: _filter == 'pending' ? FontWeight.bold : FontWeight.normal,
                        color: _filter == 'pending' ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'completed',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: _filter == 'completed' ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Concluídas',
                      style: TextStyle(
                        fontWeight: _filter == 'completed' ? FontWeight.bold : FontWeight.normal,
                        color: _filter == 'completed' ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'nearby',
                child: Row(
                  children: [
                    Icon(
                      Icons.near_me,
                      color: _filter == 'nearby' ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Próximas',
                      style: TextStyle(
                        fontWeight: _filter == 'nearby' ? FontWeight.bold : FontWeight.normal,
                        color: _filter == 'nearby' ? Colors.blue : null,
                      ),
                    ),
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
              PopupMenuItem(
                value: 'all_categories',
                child: Row(
                  children: [
                    Icon(
                      Icons.clear_all,
                      color: (_categoryFilter == null || _categoryFilter == 'all_categories') ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Todas as categorias',
                      style: TextStyle(
                        fontWeight: (_categoryFilter == null || _categoryFilter == 'all_categories') ? FontWeight.bold : FontWeight.normal,
                        color: (_categoryFilter == null || _categoryFilter == 'all_categories') ? Colors.blue : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'no_category',
                child: Row(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      color: _categoryFilter == 'no_category' ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Sem categoria',
                      style: TextStyle(
                        fontWeight: _categoryFilter == 'no_category' ? FontWeight.bold : FontWeight.normal,
                        color: _categoryFilter == 'no_category' ? Colors.blue : null,
                      ),
                    ),
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
                            color: _categoryFilter == cat.id ? Colors.blue : cat.color,
                            shape: BoxShape.circle,
                            border: _categoryFilter == cat.id
                                ? Border.all(color: Colors.blue.shade700, width: 2)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          cat.name,
                          style: TextStyle(
                            fontWeight: _categoryFilter == cat.id ? FontWeight.bold : FontWeight.normal,
                            color: _categoryFilter == cat.id ? Colors.blue : null,
                          ),
                        ),
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
    final hasCategoryFilter = _categoryFilter != null && _categoryFilter != 'all_categories';
    bool hasFilters = _filter != 'all' || hasCategoryFilter;

    // Mensagem baseada nos filtros ativos
    if (hasFilters) {
      final List<String> filterParts = [];
      icon = Icons.filter_list; // Ícone padrão quando há filtros
      
      if (_filter == 'completed') {
        filterParts.add('concluídas');
        icon = Icons.check_circle_outline;
      } else if (_filter == 'pending') {
        filterParts.add('pendentes');
        icon = Icons.pending_actions;
      } else if (_filter == 'nearby') {
        filterParts.add('próximas');
        icon = Icons.near_me;
      }
      
      if (_categoryFilter == 'no_category') {
        filterParts.add('sem categoria');
        if (_filter == 'all') icon = Icons.category_outlined;
      } else if (hasCategoryFilter && _categoryFilter != 'all_categories') {
        final category = Category.getById(_categoryFilter);
        if (category != null) {
          filterParts.add('da categoria "${category.name}"');
          if (_filter == 'all') icon = Icons.category;
        }
      }
      
      message = 'Nenhuma tarefa ${filterParts.join(' e ')}';
    } else {
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
            textAlign: TextAlign.center,
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
    final filteredTasks = _filteredTasks;
    // Mostra estatísticas das tarefas filtradas quando há filtros ativos
    final hasCategoryFilter = _categoryFilter != null && _categoryFilter != 'all_categories';
    final showFilteredStats = _filter != 'all' || hasCategoryFilter;
    final tasksToCount = showFilteredStats ? filteredTasks : _tasks;
    
    return {
      'total': tasksToCount.length,
      'completed': tasksToCount.where((t) => t.completed).length,
      'pending': tasksToCount.where((t) => !t.completed).length,
    };
  }
}