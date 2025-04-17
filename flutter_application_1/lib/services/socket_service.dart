import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/config/api_constants.dart';

enum SocketStatus { connecting, connected, disconnected }

class SocketService with ChangeNotifier {
  late IO.Socket _socket;
  SocketStatus _socketStatus = SocketStatus.disconnected;
  List<String> _onlineUsers = [];
  List<Map<String, dynamic>> _notifications = [];
  int _unreadNotifications = 0;

  // Getters
  SocketStatus get socketStatus => _socketStatus;
  List<String> get onlineUsers => _onlineUsers;
  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadNotifications => _unreadNotifications;
  IO.Socket get socket => _socket;

  // Constructor
  SocketService() {
    _initSocket();
  }

  // Inicializar Socket.IO
  void _initSocket() {
    _socketStatus = SocketStatus.disconnected;
    notifyListeners();

    // Crear instancia de Socket.IO
    _socket = IO.io(
      ApiConstants.baseUrl, // URL base del servidor (asegúrate de que sea el correcto)
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect() // No conectar automáticamente
          .enableForceNew()
          .build(),
    );

    // Configurar listeners
    _setupSocketListeners();
  }

  // Configurar listeners de Socket.IO
  void _setupSocketListeners() {
    _socket.on('connect', (_) {
      print('Conectado a Socket.IO');
      _socketStatus = SocketStatus.connected;
      notifyListeners();
    });

    _socket.on('disconnect', (_) {
      print('Desconectado de Socket.IO');
      _socketStatus = SocketStatus.disconnected;
      notifyListeners();
    });

    _socket.on('user_status', (data) {
      print('Estado de usuario actualizado: $data');
      if (data['onlineUsers'] != null) {
        _onlineUsers = List<String>.from(data['onlineUsers']);
        notifyListeners();
      }
    });

    _socket.on('notification', (data) {
      print('Nueva notificación recibida: $data');
      _notifications.insert(0, data);
      _unreadNotifications++;
      notifyListeners();
    });

    _socket.on('error', (data) {
      print('Error de Socket.IO: $data');
    });
  }

  // Conectar al servidor con autenticación
  void connect(User? user) {
    if (user == null || user.id.isEmpty) {
      print('No se puede conectar sin ID de usuario');
      return;
    }

    // Configurar datos de autenticación
    _socket.auth = {
      'userId': user.id,
    };

    // Conectar al servidor
    _socket.connect();
    print('Conectando con ID de usuario: ${user.id}');
  }

  // Desconectar del servidor
  void disconnect() {
    if (_socketStatus != SocketStatus.disconnected) {
      _socket.disconnect();
      _socketStatus = SocketStatus.disconnected;
      notifyListeners();
    }
  }

  // Unirse a una sala de chat
  void joinChatRoom(String roomId) {
    if (_socketStatus != SocketStatus.connected) {
      print('No se puede unir a la sala: no conectado');
      return;
    }

    _socket.emit('join_room', roomId);
    print('Unido a la sala de chat: $roomId');
  }

  // Enviar mensaje
  void sendMessage(String roomId, String content) {
    if (_socketStatus != SocketStatus.connected) {
      print('No se puede enviar mensaje: no conectado');
      return;
    }

    final message = {
      'roomId': roomId,
      'content': content,
    };

    _socket.emit('send_message', message);
    print('Mensaje enviado a la sala $roomId: $content');
  }

  // Enviar estado "escribiendo..."
  void sendTyping(String roomId) {
    if (_socketStatus != SocketStatus.connected) return;
    _socket.emit('typing', roomId);
  }

  // Marcar notificaciones como leídas
  void markNotificationsAsRead() {
    _unreadNotifications = 0;
    notifyListeners();
  }

  // Limpiar notificaciones
  void clearNotifications() {
    _notifications.clear();
    _unreadNotifications = 0;
    notifyListeners();
  }

  // Verificar si está conectado
  bool isConnected() {
    return _socketStatus == SocketStatus.connected;
  }

  // Limpiar todo al cerrar sesión
  @override
  void dispose() {
    _socket.dispose();
    super.dispose();
  }
}