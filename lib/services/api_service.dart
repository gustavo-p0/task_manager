import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../models/auth.dart';
import 'database_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // URL base da API
  // Para emulador Android, usar: 'http://10.0.2.2:3000'
  // Para iOS Simulator ou dispositivo físico na mesma rede: 'http://localhost:3000' ou IP da máquina
  static const String baseUrl = 'http://localhost:3000';
  
  final DatabaseService _db = DatabaseService.instance;

  Future<String?> _getToken() async {
    final auth = await _db.getAuth();
    if (auth == null || auth.isExpired) return null;
    return auth.token;
  }

  Future<Map<String, String>> _getHeaders({String? token}) async {
    final authToken = token ?? await _getToken();
    return {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }

  // ========== AUTH ==========

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final token = data['data']['token'] as String;
          final user = data['data']['user'] as Map<String, dynamic>;
          
          // Salvar token
          await _db.saveAuth(AuthData(
            token: token,
            userId: user['id'] as String,
            expiresAt: DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
          ));

          return {'success': true, 'data': data['data']};
        }
      }

      return {
        'success': false,
        'message': jsonDecode(response.body)['message'] ?? 'Erro ao registrar',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final token = data['data']['token'] as String;
          final user = data['data']['user'] as Map<String, dynamic>;
          
          // Salvar token
          await _db.saveAuth(AuthData(
            token: token,
            userId: user['id'] as String,
            expiresAt: DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch,
          ));

          return {'success': true, 'data': data['data']};
        }
      }

      return {
        'success': false,
        'message': jsonDecode(response.body)['message'] ?? 'Erro ao fazer login',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  // ========== TASKS ==========

  Future<Map<String, dynamic>> getTasks() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data'] ?? []};
      }

      return {
        'success': false,
        'message': jsonDecode(response.body)['message'] ?? 'Erro ao buscar tarefas',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> createTask(Task task) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/tasks'),
        headers: headers,
        body: jsonEncode({
          'title': task.title,
          'description': task.description,
          'completed': task.completed,
          'priority': task.priority,
          'dueDate': task.dueDate?.toIso8601String(),
          'categoryId': task.categoryId,
          'photoPath': task.photoPath,
          'completedAt': task.completedAt?.toIso8601String(),
          'completedBy': task.completedBy,
          'latitude': task.latitude,
          'longitude': task.longitude,
          'locationName': task.locationName,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }

      return {
        'success': false,
        'message': jsonDecode(response.body)['message'] ?? 'Erro ao criar tarefa',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> getTask(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/tasks/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }

      return {
        'success': false,
        'message': jsonDecode(response.body)['message'] ?? 'Erro ao buscar tarefa',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> updateTask(Task task) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/tasks/${task.serverId ?? task.id}'),
        headers: headers,
        body: jsonEncode({
          'title': task.title,
          'description': task.description,
          'completed': task.completed,
          'priority': task.priority,
          'dueDate': task.dueDate?.toIso8601String(),
          'categoryId': task.categoryId,
          'photoPath': task.photoPath,
          'completedAt': task.completedAt?.toIso8601String(),
          'completedBy': task.completedBy,
          'latitude': task.latitude,
          'longitude': task.longitude,
          'locationName': task.locationName,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      }

      return {
        'success': false,
        'message': jsonDecode(response.body)['message'] ?? 'Erro ao atualizar tarefa',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteTask(String serverId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/tasks/$serverId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': jsonDecode(response.body)['message'] ?? 'Erro ao remover tarefa',
      };
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão: $e'};
    }
  }
}

