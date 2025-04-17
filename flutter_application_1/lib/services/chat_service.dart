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
    try {
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
    } catch (e) {
      print('Error al procesar nuevo mensaje: $e');
    }
  }

  // Manejar mensajes anteriores
  void _handlePreviousMessages(dynamic data) {
    try {
      if (data is! List || _currentRoomId == null) return;
      
      final messages = data.map((m) => Message.fromJson(m)).toList();
      _messages[_currentRoomId!] = messages;
      
      notifyListeners();
    } catch (e) {
      print('Error al procesar mensajes anteriores: $e');
    }
  }

  // Cargar salas de chat
  Future<void> loadChatRooms(String userId) async {
    if (userId.isEmpty) {
      print('No se puede cargar salas de chat: userId está vacío');
      return;
    }

    // Usar try-finally para asegurar que _isLoading se restablezca
    try {
      _isLoading = true;
      notifyListeners();
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/chat/rooms/user/$userId');
      print('Cargando salas de chat desde: $uri');
      
      try {
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          _chatRooms = data.map((room) => ChatRoom.fromJson(room)).toList();
        } else {
          print('Error cargando salas de chat: ${response.statusCode} - ${response.body}');
          // Utilizar salas vacías para evitar errores en la UI
          _chatRooms = [];
        }
      } catch (e) {
        print('Error al cargar salas de chat: $e');
        _chatRooms = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Crear una sala de chat
  Future<ChatRoom?> createChatRoom(String name, List<String> participants, [String? description]) async {
    if (name.isEmpty || participants.isEmpty) {
      print('No se puede crear sala de chat: nombre o participantes vacíos');
      return null;
    }

    try {
      _isLoading = true;
      notifyListeners();
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/chat/rooms');
      print('Creando sala de chat en: $uri');
      
      try {
        final response = await http.post(
          uri,
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
        } else {
          print('Error creando sala de chat: ${response.statusCode} - ${response.body}');
          
          // Para propósitos de desarrollo, permitir crear una sala ficticia
          if (response.statusCode == 404) {
            final createdRoom = ChatRoom(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              description: description,
              participants: participants,
              createdAt: DateTime.now(),
              lastMessage: null,
              lastMessageTime: null,
            );
            
            _chatRooms.add(createdRoom);
            notifyListeners();
            return createdRoom;
          }
          return null;
        }
      } catch (e) {
        print('Error al crear sala de chat: $e');
        return null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar mensajes para una sala
  Future<void> loadMessages(String roomId, [int limit = 50]) async {
    if (roomId.isEmpty) {
      print('No se puede cargar mensajes: roomId está vacío');
      return;
    }

    try {
      _isLoading = true;
      _currentRoomId = roomId;
      notifyListeners();
      
      // Unirse a la sala mediante Socket.IO
      print('Unido a la sala de chat: $roomId');
      _socketService.joinChatRoom(roomId);
      
      // Si ya tenemos mensajes para esta sala, usarlos
      if (_messages.containsKey(roomId) && _messages[roomId]!.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/chat/messages/$roomId?limit=$limit');
      print('Cargando mensajes desde: $uri');
      
      try {
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          _messages[roomId] = data.map((m) => Message.fromJson(m)).toList();
        } else {
          print('Error cargando mensajes: ${response.statusCode} - ${response.body}');
          // Inicializar con un array vacío para evitar errores
          _messages[roomId] = [];
        }
      } catch (e) {
        print('Error al hacer la solicitud de mensajes: $e');
        _messages[roomId] = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Enviar un mensaje
  void sendMessage(String roomId, String content) {
    if (roomId.isEmpty) {
      print('Error: roomId no puede estar vacío');
      return;
    }
    
    if (content.trim().isEmpty) {
      print('Error: el mensaje no puede estar vacío');
      return;
    }
    
    print('Enviando mensaje a la sala $roomId: $content');
    _socketService.sendMessage(roomId, content);
    
    // Añadir mensaje temporal para mejor UX
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final temporaryMessage = Message(
      id: tempId,
      senderId: 'current_user', // Reemplazar con ID real cuando esté disponible
      senderName: 'Yo',
      content: content,
      timestamp: DateTime.now(),
      roomId: roomId,
      isRead: false,
    );
    
    if (!_messages.containsKey(roomId)) {
      _messages[roomId] = [];
    }
    
    _messages[roomId]!.add(temporaryMessage);
    notifyListeners();
  }

  // Enviar estado "escribiendo..."
  void sendTyping(String roomId) {
    if (roomId.isEmpty) return;
    
    _socketService.sendTyping(roomId);
  }

  // Marcar mensajes como leídos
  Future<void> markMessagesAsRead(String userId) async {
    if (_currentRoomId == null || _currentRoomId!.isEmpty || userId.isEmpty) return;
    
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/chat/messages/read');
      
      await http.post(
        uri,
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
    if (roomId.isEmpty) return false;
    
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/chat/rooms/$roomId');
      
      try {
        final response = await http.delete(uri);
        
        if (response.statusCode == 200 || response.statusCode == 404) {
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
        print('Error al realizar la solicitud para eliminar sala: $e');
        
        // Para propósitos de desarrollo, permitir eliminar localmente
        _chatRooms.removeWhere((room) => room.id == roomId);
        _messages.remove(roomId);
        
        if (_currentRoomId == roomId) {
          _currentRoomId = null;
        }
        
        notifyListeners();
        return true;
      }
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