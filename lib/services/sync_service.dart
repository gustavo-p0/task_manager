import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/sync_queue.dart';
import 'database_service.dart';
import 'api_service.dart';
import 'connectivity_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _db = DatabaseService.instance;
  final ApiService _api = ApiService();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isSyncing = false;

  // Adicionar task à fila de sincronização
  Future<void> queueTaskOperation({
    required Task task,
    required String operation,
  }) async {
    final queueItem = SyncQueueItem(
      taskId: task.id,
      operation: operation,
      data: jsonEncode(task.toMap()),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _db.addToSyncQueue(queueItem);

    // Tentar sincronizar imediatamente se online
    if (_connectivity.currentStatus == ConnectivityStatus.online) {
      _syncQueue();
    }
  }

  // Sincronizar fila completa
  Future<void> syncQueue() async {
    if (_isSyncing) return;
    if (_connectivity.currentStatus != ConnectivityStatus.online) return;

    await _syncQueue();
  }

  Future<void> _syncQueue() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final queue = await _db.getSyncQueue();

      for (final queueItem in queue) {
        try {
          final taskData = jsonDecode(queueItem.data) as Map<String, dynamic>;
          final task = Task.fromMap(taskData);

          bool success = false;

          switch (queueItem.operation) {
            case 'CREATE':
              success = await _syncCreate(task);
              break;
            case 'UPDATE':
              success = await _syncUpdate(task);
              break;
            case 'DELETE':
              success = await _syncDelete(task);
              break;
          }

          if (success) {
            // Remover da fila
            if (queueItem.id != null) {
              await _db.removeFromSyncQueue(queueItem.id!);
            }
          } else {
            // Incrementar contador de tentativas
            if (queueItem.id != null) {
              await _db.incrementRetryCount(queueItem.id!);
            }
          }
        } catch (e) {
          print('Erro ao sincronizar task: $e');
          if (queueItem.id != null) {
            await _db.incrementRetryCount(queueItem.id!);
          }
        }
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _syncCreate(Task task) async {
    try {
      final result = await _api.createTask(task);

      if (result['success'] == true) {
        final serverTask = result['data'] as Map<String, dynamic>;
        final serverId = serverTask['id'] as String;
        final serverUpdatedAt = DateTime.parse(serverTask['updatedAt'] as String)
            .millisecondsSinceEpoch;

        // Atualizar task local com server_id
        final updatedTask = task.copyWith(
          serverId: serverId,
          synced: true,
          updatedAt: serverUpdatedAt,
        );
        await _db.update(updatedTask);
        return true;
      }

      return false;
    } catch (e) {
      print('Erro ao sincronizar CREATE: $e');
      return false;
    }
  }

  Future<bool> _syncUpdate(Task task) async {
    try {
      if (task.serverId == null) {
        // Se não tem server_id, tratar como CREATE
        return await _syncCreate(task);
      }

      // Buscar task do servidor para comparar timestamps (LWW)
      final serverResult = await _api.getTask(task.serverId!);
      if (serverResult['success'] != true) return false;

      final serverTask = serverResult['data'] as Map<String, dynamic>;
      final serverUpdatedAt = DateTime.parse(serverTask['updatedAt'] as String)
          .millisecondsSinceEpoch;
      final localUpdatedAt = task.updatedAt;

      // Comparar timestamps para LWW
      if (localUpdatedAt > serverUpdatedAt) {
        // Local é mais recente, atualizar servidor
        final result = await _api.updateTask(task);

        if (result['success'] == true) {
          final updatedTask = task.copyWith(
            synced: true,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          );
          await _db.update(updatedTask);
          return true;
        }

        return false;
      } else {
        // Servidor é mais recente ou igual, atualizar local
        final taskMap = {
          ...task.toMap(),
          'id': task.id, // Manter ID local
          'server_id': task.serverId,
          'title': serverTask['title'] as String,
          'description': serverTask['description'] as String? ?? '',
          'completed': (serverTask['completed'] as bool? ?? false) ? 1 : 0,
          'priority': serverTask['priority'] as String? ?? 'medium',
          'dueDate': serverTask['dueDate'] as String?,
          'categoryId': serverTask['categoryId'] as String?,
          'photoPath': serverTask['photoPath'] as String?,
          'completedAt': serverTask['completedAt'] as String?,
          'completedBy': serverTask['completedBy'] as String?,
          'latitude': serverTask['latitude'] as double?,
          'longitude': serverTask['longitude'] as double?,
          'locationName': serverTask['locationName'] as String?,
          'updated_at': serverUpdatedAt,
          'synced': 1,
        };
        final updatedTask = Task.fromMap(taskMap);

        await _db.update(updatedTask);
        return true;
      }
    } catch (e) {
      print('Erro ao sincronizar UPDATE: $e');
      return false;
    }
  }

  Future<bool> _syncDelete(Task task) async {
    try {
      if (task.serverId == null) {
        // Task nunca foi sincronizado, apenas remover local
        return true;
      }

      final result = await _api.deleteTask(task.serverId!);
      return result['success'] == true;
    } catch (e) {
      print('Erro ao sincronizar DELETE: $e');
      return false;
    }
  }

  // Sincronizar dados do servidor para local (pull)
  Future<void> syncFromServer() async {
    if (_connectivity.currentStatus != ConnectivityStatus.online) return;

    try {
      final tasksResult = await _api.getTasks();
      if (tasksResult['success'] != true) return;

      final serverTasks = tasksResult['data'] as List? ?? [];
      final localTasks = await _db.readAll();

      // Processar tasks do servidor
      for (final serverTaskData in serverTasks) {
        final serverId = serverTaskData['id'] as String;
        final serverUpdatedAt = DateTime.parse(serverTaskData['updatedAt'] as String)
            .millisecondsSinceEpoch;

        // Buscar task local correspondente pelo serverId
        Task? localTask;
        try {
          localTask = localTasks.firstWhere(
            (lt) => lt.serverId == serverId,
          );
        } catch (e) {
          // Task não existe localmente, criar novo
          localTask = null;
        }

        if (localTask == null) {
          // Task novo do servidor, criar localmente
          // Converter dados do servidor para formato local
          final taskMap = {
            'id': const Uuid().v4(), // Gerar ID único local
            'title': serverTaskData['title'] as String,
            'description': serverTaskData['description'] as String? ?? '',
            'completed': (serverTaskData['completed'] as bool? ?? false) ? 1 : 0,
            'priority': serverTaskData['priority'] as String? ?? 'medium',
            'createdAt': serverTaskData['createdAt'] as String? ?? DateTime.now().toIso8601String(),
            'dueDate': serverTaskData['dueDate'] as String?,
            'categoryId': serverTaskData['categoryId'] as String?,
            'photoPath': serverTaskData['photoPath'] as String?,
            'completedAt': serverTaskData['completedAt'] as String?,
            'completedBy': serverTaskData['completedBy'] as String?,
            'latitude': serverTaskData['latitude'] as double?,
            'longitude': serverTaskData['longitude'] as double?,
            'locationName': serverTaskData['locationName'] as String?,
            'server_id': serverId,
            'updated_at': serverUpdatedAt,
            'synced': 1,
          };
          final newTask = Task.fromMap(taskMap);
          await _db.create(newTask);
        } else {
          // Task existe localmente, aplicar LWW
          if (serverUpdatedAt >= localTask.updatedAt) {
            // Servidor é mais recente ou igual, atualizar local
            final taskMap = {
              ...localTask.toMap(),
              'id': localTask.id, // Manter ID local
              'title': serverTaskData['title'] as String,
              'description': serverTaskData['description'] as String? ?? '',
              'completed': (serverTaskData['completed'] as bool? ?? false) ? 1 : 0,
              'priority': serverTaskData['priority'] as String? ?? 'medium',
              'dueDate': serverTaskData['dueDate'] as String?,
              'categoryId': serverTaskData['categoryId'] as String?,
              'photoPath': serverTaskData['photoPath'] as String?,
              'completedAt': serverTaskData['completedAt'] as String?,
              'completedBy': serverTaskData['completedBy'] as String?,
              'latitude': serverTaskData['latitude'] as double?,
              'longitude': serverTaskData['longitude'] as double?,
              'locationName': serverTaskData['locationName'] as String?,
              'server_id': serverId,
              'updated_at': serverUpdatedAt,
              'synced': 1,
            };
            final updatedTask = Task.fromMap(taskMap);
            await _db.update(updatedTask);
          }
          // Se local é mais recente, manter local (será sincronizado na próxima vez)
        }
      }
    } catch (e) {
      print('Erro ao sincronizar do servidor: $e');
    }
  }

  // Inicializar listener de conectividade
  void initialize() {
    _connectivity.statusStream.listen((status) {
      if (status == ConnectivityStatus.online) {
        // Quando voltar online, sincronizar
        syncQueue();
        syncFromServer();
      }
    });
  }
}

