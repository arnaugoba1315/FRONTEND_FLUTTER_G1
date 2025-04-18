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
    print('Configurando listeners de Socket.IO para chat');
    
    _socketService.socket.on('new_message', (data) {
      print('Mensaje recibido por Socket.IO: $data');
      _handleNewMessage(data);
    });

    _socketService.socket.on('new_chat_room', (data) {
      print('Nueva sala de chat recibida: $data');
      _handleNewChatRoom(data);
    });

    _socketService.socket.on('user_typing', (data) {
      print('Usuario escribiendo: $data');
      // Manejar evento de usuario escribiendo
      notifyListeners();
    });
  }

  // Manejar una nueva sala de chat recibida
  void _handleNewChatRoom(dynamic data) {
    try {
      if (data == null) return;
      
      final ChatRoom newRoom = ChatRoom.fromJson(data);
      
      // Verificar si ya tenemos esta sala
      final existingIndex = _chatRooms.indexWhere((r) => r.id == newRoom.id);
      
      if (existingIndex >= 0) {
        // Actualizar sala existente
        _chatRooms[existingIndex] = newRoom;
      } else {
        // Añadir nueva sala
        _chatRooms.add(newRoom);
      }
      
      // Guardar y notificar
      _saveRooms();
      notifyListeners();
    } catch (e) {
      print('Error procesando nueva sala de chat: $e');
    }
  }

  void _handleNewMessage(dynamic data) {
    try {
      print('Procesando mensaje recibido: $data');
      
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
      
      // Guardar mensajes localmente para persistencia
      _saveLocalMessages(roomId, _messages[roomId]!);
      
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
      } else {
        // La sala no existe localmente, puede ser una nueva sala
        // Intentar cargar las salas para asegurarnos de tener la más reciente
        print('Sala no encontrada localmente: $roomId. Intentando recargar salas...');
        final userId = _socketService.socket.auth['userId'] as String? ?? '';
        if (userId.isNotEmpty) {
          loadChatRooms(userId);
        }
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
      
      print('Cargando salas de chat para usuario: $userId');
      final uri = Uri.parse(ApiConstants.userChatRooms(userId));
      
      try {
        final response = await http.get(uri);
        print('Respuesta de salas de chat: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('Datos de salas recibidos: $data');
          
          List<dynamic> roomsList;
          if (data is List) {
            roomsList = data;
          } else if (data['rooms'] != null) {
            roomsList = data['rooms'];
          } else {
            // Usar salas locales si hay error con la API
            print('Formato de respuesta inesperado: $data');
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
        } else {
          print('Error cargando salas: ${response.statusCode} - ${response.body}');
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
    print('Combinando ${newRooms.length} salas nuevas con ${_chatRooms.length} salas existentes');
    
    // Eliminar todas las salas de prueba o vacías
    _chatRooms.removeWhere((room) => 
      room.name == 'Chat de prueba' || 
      room.name == 'Sala de prueba' ||
      room.name == 'Test room' ||
      room.name == 'Chat Room' ||
      room.name.isEmpty
    );
    
    // Limpiar los mensajes predeterminados
    _messages.forEach((roomId, messages) {
      messages.removeWhere((message) => 
        message.content.contains('Bienvenido a la sala') ||
        message.content.contains('Mensaje de prueba') ||
        message.content.contains('Test message')
      );
    });
    
    final currentUserId = _socketService.socket.auth['userId'] as String? ?? '';
    
    for (final newRoom in newRooms) {
      // Si es una sala individual (2 participantes), asegurarse de que el nombre es el del otro usuario
      ChatRoom roomToAdd = newRoom;
      
      if (newRoom.participants.length == 2 && currentUserId.isNotEmpty) {
        final otherUserId = newRoom.participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => ''
        );
        
        if (otherUserId.isNotEmpty) {
          // Si ya tenemos un usuario cargado con este ID en _userService.cache, usar su nombre
          _userService.getUserById(otherUserId).then((otherUser) {
            if (otherUser != null && otherUser.username.isNotEmpty) {
              // Solo actualizar el nombre si es diferente
              if (roomToAdd.name != otherUser.username) {
                final index = _chatRooms.indexWhere((r) => r.id == newRoom.id);
                if (index >= 0) {
                  _chatRooms[index] = _chatRooms[index].copyWith(name: otherUser.username);
                  _saveRooms();
                  notifyListeners();
                }
              }
            }
          }).catchError((e) {
            print('Error obteniendo usuario para renombrar sala: $e');
          });
        }
      }
      
      final existingIndex = _chatRooms.indexWhere((r) => r.id == newRoom.id);
      
      if (existingIndex >= 0) {
        // Actualizar sala existente preservando mensajes
        final existingRoom = _chatRooms[existingIndex];
        _chatRooms[existingIndex] = roomToAdd.copyWith(
          name: existingRoom.name, // Preservar nombre existente para evitar sobrescribir nombres personalizados
          lastMessage: roomToAdd.lastMessage ?? existingRoom.lastMessage,
          lastMessageTime: roomToAdd.lastMessageTime ?? existingRoom.lastMessageTime,
        );
      } else {
        // Añadir nueva sala
        _chatRooms.add(roomToAdd);
      }
    }
    
    print('Total de salas después de combinar: ${_chatRooms.length}');
  }
  
  // Procesar salas de chat para mostrar nombres de usuario en lugar de IDs
  Future<List<ChatRoom>> _processChatRooms(List<dynamic> data, String currentUserId) async {
    List<ChatRoom> rooms = [];
    
    for (var roomData in data) {
      ChatRoom room = ChatRoom.fromJson(roomData);
      
      // Ignorar salas de prueba
      if (room.name == 'Chat de prueba' || 
          room.name == 'Sala de prueba' || 
          room.name == 'Test room' ||
          room.name == 'Chat Room') {
        continue;
      }
      
      // Para salas con exactamente 2 participantes, mostrar el nombre del OTRO usuario
      if (room.participants.length == 2) {
        // Encontrar el ID del otro usuario (no el actual)
        String otherUserId = room.participants.firstWhere(
          (id) => id != currentUserId, 
          orElse: () => ''
        );
        
        if (otherUserId.isNotEmpty) {
          try {
            final otherUser = await _userService.getUserById(otherUserId);
            if (otherUser != null) {
              print('Ajustando nombre de sala ${room.id} para usuario $currentUserId: usando nombre "${otherUser.username}"');
              
              // Siempre usar el nombre del otro usuario como nombre de la sala
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
      
      // Obtener el ID del usuario actual
      final currentUserId = _socketService.socket.auth['userId'] as String? ?? '';
      if (currentUserId.isEmpty) {
        print('Error: No se pudo identificar el ID del usuario actual');
        _isLoading = false;
        notifyListeners();
        return null;
      }
      
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
          print('Sala existente encontrada: ${existingRoom.id}');
          _isLoading = false;
          notifyListeners();
          return existingRoom;
        }
      }
      
      // Si es un chat individual (1-a-1), siempre usar el nombre del otro usuario
      String chatName = name;
      if (participants.length == 2) {
        // Encontrar el ID del otro usuario (no el actual)
        String otherUserId = participants.firstWhere(
          (id) => id != currentUserId,
          orElse: () => ''
        );
        
        if (otherUserId.isNotEmpty) {
          try {
            final otherUser = await _userService.getUserById(otherUserId);
            if (otherUser != null) {
              chatName = otherUser.username;
              print('Usando el nombre del otro usuario para el chat: ${otherUser.username}');
            }
          } catch (e) {
            print('Error obteniendo datos de usuario para nombre de sala: $e');
          }
        }
      }
      
      print('Creando nueva sala de chat "${chatName}" para ${participants.length} participantes');
      final uri = Uri.parse(ApiConstants.chatRooms);
      
      try {
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': chatName, // Usar el nombre ajustado
            'participants': participants,
            'description': description,
          }),
        );
        
        print('Respuesta de creación de sala: ${response.statusCode}');
        
        if (response.statusCode == 201) {
          final roomData = json.decode(response.body);
          print('Datos de sala creada: $roomData');
          
          // Asegurarnos de que el nombre se mantiene como el del otro usuario en caso de chat individual
          if (participants.length == 2) {
            roomData['name'] = chatName;
          }
          
          final room = ChatRoom.fromJson(roomData);
          _chatRooms.add(room);
          
          // Asegurarnos de que el otro usuario reciba la notificación
          _socketService.socket.emit('join_room', room.id);
          
          // Guardar salas actualizadas
          _saveRooms();
          
          notifyListeners();
          return room;
        } else {
          print('Error creando sala de chat: ${response.statusCode} - ${response.body}');
          _isLoading = false;
          notifyListeners();
          return null;
        }
      } catch (e) {
        print('Error al crear sala de chat: $e');
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Actualizar el nombre de la sala para que muestre el nombre del otro usuario
  void _updateRoomNameForCurrentUser(String roomId) {
    final currentUserId = _socketService.socket.auth['userId'] as String? ?? '';
    if (currentUserId.isEmpty) return;

    final roomIndex = _chatRooms.indexWhere((room) => room.id == roomId);
    if (roomIndex != -1) {
      final room = _chatRooms[roomIndex];
      if (room.participants.length == 2) {
        final otherUserId = room.participants.firstWhere((id) => id != currentUserId, orElse: () => '');
        if (otherUserId.isNotEmpty) {
          _userService.getUserById(otherUserId).then((otherUser) {
            if (otherUser != null && otherUser.username.isNotEmpty) {
              _chatRooms[roomIndex] = room.copyWith(name: otherUser.username);
              _saveRooms();
              notifyListeners();
            }
          }).catchError((e) {
            print('Error obteniendo usuario para actualizar nombre de sala: $e');
          });
        }
      }
    }
  }

  // Cargar mensajes para una sala
  Future<void> loadMessages(String roomId) async {
    if (roomId.isEmpty) {
      print('No se puede cargar mensajes: roomId está vacío');
      return;
    }

    try {
      _isLoading = true;
      _currentRoomId = roomId;
      notifyListeners();
      
      // Unirse a la sala mediante Socket.IO
      print('Uniéndose a la sala: $roomId');
      _socketService.joinChatRoom(roomId);
      
      // Actualizar el nombre de la sala para que muestre el nombre del otro usuario
      _updateRoomNameForCurrentUser(roomId);
      
      // Intentar cargar mensajes locales primero
      final localMessages = await _loadLocalMessages(roomId);
      if (localMessages.isNotEmpty) {
        print('Usando ${localMessages.length} mensajes desde almacenamiento local para sala $roomId');
        _messages[roomId] = localMessages;
      }
      
      final uri = Uri.parse(ApiConstants.chatMessages(roomId));
      
      try {
        final response = await http.get(uri);
        
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          print('Mensajes recibidos para sala $roomId: ${data.length}');
          
          // Solo filtrar mensajes de sistema, no los mensajes regulares
          final filteredData = data.where((m) => 
            m['content'] != null && 
            !(m['content'].toString().contains("Bienvenido") && 
              m['content'].toString().contains("sala"))
          ).toList();
          
          print('Después de filtrado: ${filteredData.length} mensajes');
          
          // Crear instancias de Message a partir de los datos JSON
          final messages = filteredData.map((m) => Message.fromJson(m)).toList();
          
          // Inicializar la lista de mensajes para esta sala solo si no tenemos mensajes locales
          // o si tenemos más mensajes del servidor
          if (!_messages.containsKey(roomId) || 
              _messages[roomId]!.isEmpty ||
              messages.length > _messages[roomId]!.length) {
            
            _messages[roomId] = [];
            
            // Añadir todos los IDs de mensajes al conjunto procesado para evitar duplicados
            _processedMessageIds.clear(); // Limpiar para evitar mantener mensajes antiguos
            
            // Añadir mensajes a la lista y registrar sus IDs
            for (var message in messages) {
              _messages[roomId]!.add(message);
              _processedMessageIds.add(message.id);
            }
            
            // Guardar mensajes localmente
            _saveLocalMessages(roomId, _messages[roomId]!);
          }
        } else {
          print('Error cargando mensajes: ${response.statusCode} - ${response.body}');
          // Si no hay mensajes locales, inicializar con array vacío
          if (!_messages.containsKey(roomId)) {
            _messages[roomId] = [];
          }
        }
      } catch (e) {
        print('Error al hacer la solicitud de mensajes: $e');
        // Si no hay mensajes locales, inicializar con array vacío
        if (!_messages.containsKey(roomId)) {
          _messages[roomId] = [];
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Guardar mensajes localmente
  Future<void> _saveLocalMessages(String roomId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = messages.map((msg) => json.encode(msg.toJson())).toList();
      await prefs.setStringList('messages_$roomId', messagesJson);
      print('Guardados ${messages.length} mensajes localmente para sala $roomId');
    } catch (e) {
      print('Error guardando mensajes localmente: $e');
    }
  }
  
  // Cargar mensajes desde almacenamiento local
  Future<List<Message>> _loadLocalMessages(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getStringList('messages_$roomId');
      
      if (messagesJson == null || messagesJson.isEmpty) {
        return [];
      }
      
      final messages = messagesJson.map((msgStr) {
        try {
          return Message.fromJson(json.decode(msgStr));
        } catch (e) {
          print('Error parseando mensaje: $e');
          return null;
        }
      }).where((msg) => msg != null).cast<Message>().toList();
      
      // Registrar IDs para evitar duplicados
      for (var message in messages) {
        _processedMessageIds.add(message.id);
      }
      
      return messages;
    } catch (e) {
      print('Error cargando mensajes localmente: $e');
      return [];
    }
  }

  void sendMessage(String roomId, String content) {
    if (roomId.isEmpty || content.trim().isEmpty) {
      print('No se puede enviar mensaje: roomId o contenido vacío');
      return;
    }
    
    // Tomar los datos del usuario del socketService
    final senderId = _socketService.socket.auth['userId'] as String? ?? '';
    final senderName = _socketService.socket.auth['username'] as String? ?? 'Yo';
    
    if (senderId.isEmpty) {
      print('Error: ID de remitente vacío');
      return;
    }
    
    // Generar un ID único para el mensaje que estamos enviando
    final uniqueTimestamp = DateTime.now().millisecondsSinceEpoch;
    final messageId = 'msg_${uniqueTimestamp}_${senderId}_${DateTime.now().microsecond}';
    
    // Crear el mensaje localmente
    final temporaryMessage = Message(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      content: content,
      timestamp: DateTime.now(),
      roomId: roomId,
      isRead: false,
    );
    
    // Registrar este ID para evitar duplicados cuando regrese desde el servidor
    _processedMessageIds.add(messageId);
    
    // Añadir a la lista de mensajes locales
    if (!_messages.containsKey(roomId)) {
      _messages[roomId] = [];
    }
    
    _messages[roomId]!.add(temporaryMessage);
    
    // Guardar mensajes localmente para persistencia
    _saveLocalMessages(roomId, _messages[roomId]!);
    
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
    
    // Enviar mensaje a través de Socket.IO con el ID único
    print('Enviando mensaje a través de Socket.IO - Sala: $roomId, ID: $messageId');
    _socketService.sendMessage(roomId, content, messageId);
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