import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';
import '../models/sync_queue.dart';
import '../models/auth.dart';

///Esta é a classe central para a lógica de banco de dados. Ela segue o padrão Singleton, garantindo que tenhamos apenas uma instância da conexão com o banco em todo o app.

///_initDB(): Inicializa o banco de dados, define seu nome e caminho.
///_createDB(): É chamado na primeira vez que o banco é criado e executa o comando SQL para criar a tabela tasks com suas respectivas colunas.
///Métodos CRUD: create, read, readAll, update, e delete são os métodos públicos que nossa UI usará para interagir com o banco de dados, abstraindo a complexidade das queries SQL.

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        completed INTEGER NOT NULL,
        priority TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        dueDate TEXT,
        categoryId TEXT,
        photoPath TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        server_id TEXT,
        updated_at INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE auth (
        token TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_tasks_synced ON tasks(synced)');
    await db.execute(
      'CREATE INDEX idx_sync_queue_task_id ON sync_queue(task_id)',
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN dueDate TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN categoryId TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
    if (oldVersion < 5) {
      // Adicionar colunas de sincronização
      await db.execute('ALTER TABLE tasks ADD COLUMN server_id TEXT');
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE tasks ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
      );

      // Atualizar updated_at para tasks existentes usando createdAt
      final tasks = await db.query('tasks');
      for (final task in tasks) {
        final createdAtStr = task['createdAt'] as String;
        final createdAt = DateTime.parse(createdAtStr);
        final updatedAt = createdAt.millisecondsSinceEpoch;
        await db.update(
          'tasks',
          {'updated_at': updatedAt},
          where: 'id = ?',
          whereArgs: [task['id']],
        );
      }

      // Criar tabelas de sincronização
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id TEXT NOT NULL,
          operation TEXT NOT NULL,
          data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          retry_count INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE auth (
          token TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          expires_at INTEGER NOT NULL
        )
      ''');

      await db.execute('CREATE INDEX idx_tasks_synced ON tasks(synced)');
      await db.execute(
        'CREATE INDEX idx_sync_queue_task_id ON sync_queue(task_id)',
      );
    }
    print('✅ Banco migrado de v$oldVersion para v$newVersion');
  }

  Future<Task> create(Task task) async {
    final db = await database;
    await db.insert('tasks', task.toMap());
    return task;
  }

  Future<Task?> read(String id) async {
    final db = await database;
    final maps = await db.query('tasks', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Task>> readAll({bool orderByDueDate = false}) async {
    final db = await database;
    final orderBy = orderByDueDate
        ? 'CASE WHEN dueDate IS NULL THEN 1 ELSE 0 END, dueDate ASC, createdAt DESC'
        : 'createdAt DESC';
    final result = await db.query('tasks', orderBy: orderBy);
    return result.map((map) => Task.fromMap(map)).toList();
  }

  Future<int> update(Task task) async {
    final db = await database;
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Método especial: buscar tarefas por proximidade
  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();

    return allTasks.where((task) {
      if (!task.hasLocation) return false;

      // Cálculo de distância usando fórmula de Haversine (simplificada)
      final latDiff = (task.latitude! - latitude).abs();
      final lonDiff = (task.longitude! - longitude).abs();
      final distance = ((latDiff * 111000) + (lonDiff * 111000)) / 2;

      return distance <= radiusInMeters;
    }).toList();
  }

  // ========== SYNC QUEUE ==========

  Future<int> addToSyncQueue(SyncQueueItem queueItem) async {
    final db = await database;
    return await db.insert('sync_queue', {
      'task_id': queueItem.taskId,
      'operation': queueItem.operation,
      'data': queueItem.data,
      'created_at': queueItem.createdAt,
      'retry_count': queueItem.retryCount,
    });
  }

  Future<List<SyncQueueItem>> getSyncQueue() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_queue',
      orderBy: 'created_at ASC',
    );
    return List.generate(maps.length, (i) => SyncQueueItem.fromJson(maps[i]));
  }

  Future<int> removeFromSyncQueue(int queueId) async {
    final db = await database;
    return await db.delete('sync_queue', where: 'id = ?', whereArgs: [queueId]);
  }

  Future<int> incrementRetryCount(int queueId) async {
    final db = await database;
    final queueItem = await db.query(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [queueId],
      limit: 1,
    );
    if (queueItem.isEmpty) return 0;
    return await db.update(
      'sync_queue',
      {'retry_count': (queueItem.first['retry_count'] as int) + 1},
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  Future<List<Task>> getUnsyncedTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'synced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<int> markTaskAsSynced(String id, String? serverId) async {
    final db = await database;
    return await db.update(
      'tasks',
      {'synced': 1, 'server_id': serverId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== AUTH ==========

  Future<void> saveAuth(AuthData auth) async {
    final db = await database;
    await db.delete('auth');
    await db.insert('auth', auth.toJson());
  }

  Future<AuthData?> getAuth() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('auth', limit: 1);
    if (maps.isEmpty) return null;
    return AuthData.fromJson(maps.first);
  }

  Future<void> clearAuth() async {
    final db = await database;
    await db.delete('auth');
  }
}
