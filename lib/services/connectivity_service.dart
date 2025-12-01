import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _statusController = StreamController<ConnectivityStatus>.broadcast();
  ConnectivityStatus _currentStatus = ConnectivityStatus.offline;

  Stream<ConnectivityStatus> get statusStream => _statusController.stream;
  ConnectivityStatus get currentStatus => _currentStatus;

  Future<void> initialize() async {
    // Verificar status inicial
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    // Escutar mudanças
    _connectivity.onConnectivityChanged.listen((result) {
      _updateStatus(result);
    });
  }

  void _updateStatus(ConnectivityResult result) {
    final isOnline = result != ConnectivityResult.none;
    
    final newStatus = isOnline 
      ? ConnectivityStatus.online 
      : ConnectivityStatus.offline;

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void dispose() {
    _statusController.close();
  }
}

