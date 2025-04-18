import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/models/chat_room_model.dart';
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/services/socket_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService with ChangeNotifier {
  final SocketService _socketService;
  final UserService _userService = UserService();
  
  // Estado local
  List<ChatRoom> _chatRooms = [];
  Map<String, List<Message>> _messages = {};
  String? _currentRoomId;
  bool _isLoading = false;
  // Track message IDs to prevent duplicates
  Set<String> _processedMessageIds = {};

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
    // Cargar salas guardadas
    _loadSavedRooms();
  }

  // Cargar salas guardadas desde SharedPreferences
  Future<void> _loadSavedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomsData = prefs.getStringList('chat_rooms');
      
      if (roomsData != null && roomsData.isNotEmpty) {
        _chatRooms = roomsData
            .map((data) => ChatRoom.fromJson(json.decode(data)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error cargando salas guardadas: $e');
    }
  }

  // Guardar salas en SharedPreferences
  Future<void> _saveRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomsData = _chatRooms
          .map((room) => json.encode(room.toJson()))
          .toList();
      
      await prefs.setStringList('chat_rooms', roomsData);
    } catch (e) {
      print('Error guardando salas: $e');
    }
  }

  // Configurar listeners para Socket.IO
  void _setupSocketListeners() {
    _socketService.socket.on('new_message', (data) {
      print('Mensaje recibido: $data');
      _handleNewMessage(data);
    });

    _socketService.socket.on('user_typing', (data) {
      print('Usuario escribiendo: $data');
      // Manejar evento de usuario escribiendo
      notifyListeners();
    });
  }

  // Manejar nuevo mensaje recibido
  void _handleNewMessage(dynamic data) {
    try {
      // Extraer el roomId del mensaje
      final roomId = data['roomId'];
      if (roomId == null) {
        print('Error: roomId es nulo en el mensaje recibido');
        return;
      }

      // Crear objeto Message desde los datos recibidos
      final message = Message.fromJson(data);
      
      // Verificar si ya procesamos este mensaje para evitar duplicados
      if (_processedMessageIds.contains(message.id)) {
        print('Mensaje duplicado detectado y omitido: ${message.id}');
        return;
      }
      
      // Añadir a mensajes procesados
      _processedMessageIds.add(message.id);
      
      // Asegurarse de que existe la lista para esta sala
      if (!_messages.containsKey(roomId)) {
        _messages[roomId] = [];
      }
      
      // Añadir mensaje a la lista
      _messages[roomId]!.add(message);
      
      // Actualizar último mensaje en la sala de chat
      final index = _chatRooms.indexWhere((room) => room.id == roomId);
      if (index != -1) {
        final updatedRoom = _chatRooms[index].copyWith(
          lastMessage: message.content,
          lastMessageTime: message.timestamp,
        );
        
        _chatRooms[index] = updatedRoom;
        
        // Guardar salas actualizadas
        _saveRooms();
      }
      
      // Notificar cambios
      notifyListeners();
    } catch (e) {
      print('Error al procesar mensaje nuevo: $e');
    }
  }

  Future<void> loadChatRooms(String userId) async {
    if (userId.isEmpty) {
      print('No se puede cargar salas de chat: userId está vacío');
      return;
    }

    try {
      _isLoading = true;
      notifyListeners();
      
      final uri = Uri.parse(ApiConstants.userChatRooms(userId));
      
      try {
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          List<dynamic> roomsList;
          if (data is List) {
            roomsList = data;
          } else if (data['rooms'] != null) {
            roomsList = data['rooms'];
          } else {
            // Usar salas locales si hay error con la API
            _isLoading = false;
            notifyListeners();
            return;
          }
          
          // Procesar las salas de chat
          final newRooms = await _processChatRooms(roomsList, userId);
          
          // Combinar salas del servidor con las locales
          _mergeRooms(newRooms);
          
          // Guardar salas actualizadas
          _saveRooms();
        }
      } catch (e) {
        print('Error al hacer la solicitud de salas de chat: $e');
        // Continuar usando las salas locales
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Combinar salas nuevas con existentes
  void _mergeRooms(List<ChatRoom> newRooms) {
    for (final newRoom in newRooms) {
      final existingIndex = _chatRooms.indexWhere((r) => r.id == newRoom.id);
      
      if (existingIndex >= 0) {
        // Actualizar sala existente preservando mensajes
        final existingRoom = _chatRooms[existingIndex];
        _chatRooms[existingIndex] = newRoom.copyWith(
          lastMessage: newRoom.lastMessage ?? existingRoom.lastMessage,
          lastMessageTime: newRoom.lastMessageTime ?? existingRoom.lastMessageTime,
        );
      } else {
        // Añadir nueva sala
        _chatRooms.add(newRoom);
      }
    }
  }
  
  // Procesar salas de chat para mostrar nombres de usuario en lugar de IDs
  Future<List<ChatRoom>> _processChatRooms(List<dynamic> data, String currentUserId) async {
    List<ChatRoom> rooms = [];
    
    for (var roomData in data) {
      ChatRoom room = ChatRoom.fromJson(roomData);
      
      // Para salas con exactamente 2 participantes, mostrar el nombre de la otra persona
      if (room.participants.length == 2) {
        String otherUserId = room.participants.firstWhere(
          (id) => id != currentUserId, 
          orElse: () => ''
        );
        
        if (otherUserId.isNotEmpty) {
          try {
            final otherUser = await _userService.getUserById(otherUserId);
            if (otherUser != null) {
              // Usar el nombre del otro usuario como nombre de la sala
              room = room.copyWith(
                name: otherUser.username,
              );
            }
          } catch (e) {
            print('Error obteniendo datos de usuario para sala de chat: $e');
          }
        }
      }
      
      rooms.add(room);
    }
    
    return rooms;
  }

  // Crear una sala de chat
  Future<ChatRoom?> createChatRoom(String name, List<String> participants, [String? description]) async {
    if (participants.isEmpty) {
      print('No se puede crear sala de chat: participantes vacíos');
      return null;
    }

    try {
      _isLoading = true;
      notifyListeners();
      
      // Verificar si ya existe una sala con estos participantes
      if (participants.length == 2) {
        final existingRoom = _chatRooms.firstWhere(
          (room) => 
            room.participants.length == participants.length && 
            room.participants.toSet().containsAll(participants.toSet()),
          orElse: () => ChatRoom(
            id: '', 
            name: '', 
            participants: [], 
            createdAt: DateTime.now()
          ),
        );
        
        if (existingRoom.id.isNotEmpty) {
          _isLoading = false;
          notifyListeners();
          return existingRoom;
        }
      }
      
      final uri = Uri.parse(ApiConstants.chatRooms);
      
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
          final roomData = json.decode(response.body);
          
          // Para chats 1-a-1, reemplazar el nombre de la sala con el nombre del otro usuario
          if (participants.length == 2) {
            final currentUserId = participants[0]; // Suponiendo que el primer participante es el usuario actual
            String otherUserId = participants[1]; // El otro usuario
            
            try {
              final otherUser = await _userService.getUserById(otherUserId);
              if (otherUser != null) {
                roomData['name'] = otherUser.username;
              }
            } catch (e) {
              print('Error obteniendo datos de usuario para nueva sala de chat: $e');
            }
          }
          
          final room = ChatRoom.fromJson(roomData);
          _chatRooms.add(room);
          
          // Guardar salas actualizadas
          _saveRooms();
          
          notifyListeners();
          return room;
        } else {
          print('Error creando sala de chat: ${response.statusCode} - ${response.body}');
          
          // Para propósitos de desarrollo, crear una sala ficticia
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
          
          // Guardar salas actualizadas
          _saveRooms();
          
          notifyListeners();
          return createdRoom;
        }
      } catch (e) {
        print('Error al crear sala de chat: $e');
        
        // Crear una sala local para pruebas
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
        
        // Guardar salas actualizadas
        _saveRooms();
        
        notifyListeners();
        return createdRoom;
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
      _socketService.joinChatRoom(roomId);
      
      // Si ya tenemos mensajes para esta sala, usarlos
      if (_messages.containsKey(roomId) && _messages[roomId]!.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      
      final uri = Uri.parse(ApiConstants.chatMessages(roomId));
      
      try {
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final messages = data.map((m) => Message.fromJson(m)).toList();
          
          // Añadir todos los IDs de mensajes al conjunto procesado para evitar duplicados
          for (var message in messages) {
            _processedMessageIds.add(message.id);
          }
          
          _messages[roomId] = messages;
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

  void sendMessage(String roomId, String content) {
    if (roomId.isEmpty || content.trim().isEmpty) return;
    
    // Generar un ID único para el mensaje que estamos enviando
    final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${_socketService.socket.id}';
    
    // Tomar los datos del usuario del socketService
    final senderId = _socketService.socket.auth['userId'] as String? ?? '';
    final senderName = _socketService.socket.auth['username'] as String? ?? 'Yo';
    
    // Añadir mensaje local temporalmente para mejor UX
    final temporaryMessage = Message(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: DateTime.now(),
      roomId: roomId,
      isRead: false,
    );
    
    // Añadir a la lista de mensajes locales
    if (!_messages.containsKey(roomId)) {
      _messages[roomId] = [];
    }
    
    _messages[roomId]!.add(temporaryMessage);
    _processedMessageIds.add(messageId); // Para evitar duplicados cuando llegue el eco
    
    // Actualizar último mensaje en la sala de chat
    final index = _chatRooms.indexWhere((room) => room.id == roomId);
    if (index != -1) {
      _chatRooms[index] = _chatRooms[index].copyWith(
        lastMessage: content,
        lastMessageTime: DateTime.now(),
      );
      
      // Guardar salas actualizadas
      _saveRooms();
    }
    
    // Notificar cambios para actualizar la UI inmediatamente
    notifyListeners();
    
    // Enviar mensaje a través de Socket.IO
    _socketService.sendMessage(roomId, content);
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
      // Marcar mensajes como leídos localmente
      if (_messages.containsKey(_currentRoomId!)) {
        final messages = _messages[_currentRoomId!]!;
        bool updated = false;
        
        for (int i = 0; i < messages.length; i++) {
          if (messages[i].senderId != userId && !messages[i].isRead) {
            messages[i] = messages[i].copyWith(isRead: true);
            updated = true;
          }
        }
        
        if (updated) {
          notifyListeners();
        }
      }
      
      // Enviar solicitud al servidor
      final uri = Uri.parse(ApiConstants.markMessagesRead);
      
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
      final uri = Uri.parse(ApiConstants.chatRoom(roomId));
      
      try {
        final response = await http.delete(uri);
        
        if (response.statusCode == 200 || response.statusCode == 404) {
          _chatRooms.removeWhere((room) => room.id == roomId);
          _messages.remove(roomId);
          
          if (_currentRoomId == roomId) {
            _currentRoomId = null;
          }
          
          // Guardar salas actualizadas
          _saveRooms();
          
          notifyListeners();
          return true;
        }
        
        return false;
      } catch (e) {
        print('Error al realizar la solicitud para eliminar sala: $e');
        
        // Eliminar localmente
        _chatRooms.removeWhere((room) => room.id == roomId);
        _messages.remove(roomId);
        
        if (_currentRoomId == roomId) {
          _currentRoomId = null;
        }
        
        // Guardar salas actualizadas
        _saveRooms();
        
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
  
  // Limpiar mensajes procesados
  void clearProcessedMessages() {
    _processedMessageIds.clear();
  }
}