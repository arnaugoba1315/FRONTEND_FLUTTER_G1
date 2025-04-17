import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/models/chat_room_model.dart';
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/services/socket_service.dart';

class ChatService with ChangeNotifier {
  final SocketService _socketService;
  
  // Estado local
  List<ChatRoom> _chatRooms = [];
  Map<String, List<Message>> _messages = {};
  String? _currentRoomId;
  bool _isLoading = false;

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  List<Message> get currentMessages => _currentRoomId != null 
    ? _messages[_currentRoomId] ?? [] 
    : [];
  String? get currentRoomId => _currentRoomId;
  bool get isLoading => _isLoading;

  // Constructor
  ChatService(this._socketService) {
    // Configurar listeners para Socket.IO
    _setupSocketListeners();
  }

  // Configurar listeners para Socket.IO
  void _setupSocketListeners() {
    _socketService.socket.on('new_message', (data) {
      print('Mensaje recibido: $data');
      _handleNewMessage(data);
    });

    _socketService.socket.on('user_typing', (data) {
      print('Usuario escribiendo: $data');
      // Implementar lógica para mostrar "escribiendo..."
    });

    _socketService.socket.on('previous_messages', (data) {
      print('Mensajes anteriores recibidos: $data');
      _handlePreviousMessages(data);
    });
  }

  // Manejar nuevo mensaje recibido
  void _handleNewMessage(dynamic data) {
    final roomId = data['roomId'];
    if (roomId == null) return;

    final message = Message.fromJson(data);
    
    if (!_messages.containsKey(roomId)) {
      _messages[roomId] = [];
    }
    
    _messages[roomId]!.add(message);
    
    // Actualizar último mensaje en la sala de chat
    final index = _chatRooms.indexWhere((room) => room.id == roomId);
    if (index != -1) {
      final updatedRoom = ChatRoom(
        id: _chatRooms[index].id,
        name: _chatRooms[index].name,
        description: _chatRooms[index].description,
        participants: _chatRooms[index].participants,
        createdAt: _chatRooms[index].createdAt,
        lastMessage: message.content,
        lastMessageTime: message.timestamp,
      );
      
      _chatRooms[index] = updatedRoom;
    }
    
    notifyListeners();
  }

  // Manejar mensajes anteriores
  void _handlePreviousMessages(dynamic data) {
    if (data is! List || _currentRoomId == null) return;
    
    final messages = data.map((m) => Message.fromJson(m)).toList();
    _messages[_currentRoomId!] = messages;
    
    notifyListeners();
  }

  // Cargar salas de chat
  Future<void> loadChatRooms(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final response = await http.get(
        Uri.parse('${ApiConstants.chat}/rooms/user/$userId'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _chatRooms = data.map((room) => ChatRoom.fromJson(room)).toList();
      }
    } catch (e) {
      print('Error al cargar salas de chat: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Crear una sala de chat
  Future<ChatRoom?> createChatRoom(String name, List<String> participants, [String? description]) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final response = await http.post(
        Uri.parse('${ApiConstants.chat}/rooms'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'participants': participants,
          'description': description,
        }),
      );
      
      if (response.statusCode == 201) {
        final room = ChatRoom.fromJson(json.decode(response.body));
        _chatRooms.add(room);
        notifyListeners();
        return room;
      }
      
      return null;
    } catch (e) {
      print('Error al crear sala de chat: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar mensajes para una sala
  Future<void> loadMessages(String roomId, [int limit = 50]) async {
    try {
      _isLoading = true;
      _currentRoomId = roomId;
      notifyListeners();
      
      // Unirse a la sala mediante Socket.IO
      _socketService.joinChatRoom(roomId);
      
      // Si ya tenemos mensajes para esta sala, no necesitamos cargarlos de nuevo
      if (_messages.containsKey(roomId) && _messages[roomId]!.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final response = await http.get(
        Uri.parse('${ApiConstants.chat}/messages/$roomId?limit=$limit'),
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _messages[roomId] = data.map((m) => Message.fromJson(m)).toList();
      }
    } catch (e) {
      print('Error al cargar mensajes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Enviar un mensaje
  void sendMessage(String content) {
    if (_currentRoomId == null) return;
    
    _socketService.sendMessage(_currentRoomId!, content);
  }

  // Enviar estado "escribiendo..."
  void sendTyping() {
    if (_currentRoomId == null) return;
    
    _socketService.sendTyping(_currentRoomId!);
  }

  // Marcar mensajes como leídos
  Future<void> markMessagesAsRead(String userId) async {
    if (_currentRoomId == null) return;
    
    try {
      await http.post(
        Uri.parse('${ApiConstants.chat}/messages/read'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'roomId': _currentRoomId,
          'userId': userId,
        }),
      );
    } catch (e) {
      print('Error al marcar mensajes como leídos: $e');
    }
  }

  // Eliminar una sala de chat
  Future<bool> deleteChatRoom(String roomId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.chat}/rooms/$roomId'),
      );
      
      if (response.statusCode == 200) {
        _chatRooms.removeWhere((room) => room.id == roomId);
        _messages.remove(roomId);
        
        if (_currentRoomId == roomId) {
          _currentRoomId = null;
        }
        
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error al eliminar sala de chat: $e');
      return false;
    }
  }

  // Cambiar sala actual
  void setCurrentRoom(String? roomId) {
    _currentRoomId = roomId;
    notifyListeners();
  }
}