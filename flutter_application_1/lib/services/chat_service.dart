import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/models/chat_room_model.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/services/socket_service.dart';

class ChatService with ChangeNotifier {
  final SocketService _socketService;
  
  List<ChatRoom> _chatRooms = [];
  Map<String, List<Message>> _messages = {};
  String? _currentRoomId;
  bool _isLoading = false;
  Set<String> _processedMessageIds = {};
  DateTime? _lastTypingEvent;

  ChatService(this._socketService) {
    _setupSocketListeners();
    _loadPersistedData();
  }

  // Getters
  List<ChatRoom> get chatRooms => _chatRooms;
  List<Message> getMessages(String roomId) => _messages[roomId] ?? [];
  String? get currentRoomId => _currentRoomId;
  bool get isLoading => _isLoading;
  List<Message> get currentMessages => _messages[_currentRoomId ?? ''] ?? [];

  Future<void> _loadPersistedData() async {
    await _loadSavedRooms();
    await _loadAllSavedMessages();
  }

  Future<void> loadChatRooms(String userId) async {
    if (userId.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      final response = await http.get(
        Uri.parse(ApiConstants.userChatRooms(userId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _chatRooms = data.map((roomData) => ChatRoom.fromJson(roomData)).toList();
        
        await _saveRooms();
        
        for (var room in _chatRooms) {
          await loadMessages(room.id);
          _socketService.joinChatRoom(room.id);
        }
      }
    } catch (e) {
      print('Error loading chat rooms: $e');
      await _loadSavedRooms();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(String roomId) async {
    if (roomId.isEmpty) return;

    try {
      _currentRoomId = roomId;
      notifyListeners();

      final response = await http.get(
        Uri.parse(ApiConstants.chatMessages(roomId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final messages = data.map((m) => Message.fromJson(m)).toList();
        
        _messages[roomId] = messages;
        
        for (var message in messages) {
          _processedMessageIds.add('${roomId}_${message.id}');
        }

        await _saveLocalMessages(roomId, messages);
        notifyListeners();
      }
    } catch (e) {
      print('Error loading messages: $e');
      _messages[roomId] = _messages[roomId] ?? [];
    }
  }

  Future<ChatRoom?> createChatRoom(String name, List<String> participants, [String? description]) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatRooms),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'participants': participants,
          'description': description,
          'isGroup': participants.length > 2,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newRoom = ChatRoom.fromJson(data);
        
        _chatRooms.add(newRoom);
        _messages[newRoom.id] = [];
        
        await _saveRooms();
        _socketService.joinChatRoom(newRoom.id);
        
        notifyListeners();
        return newRoom;
      }
      return null;
    } catch (e) {
      print('Error creating chat room: $e');
      return null;
    }
  }

  void sendMessage(String roomId, String content) {
    if (roomId.isEmpty || content.trim().isEmpty) return;

    try {
      final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${_socketService.socket.id}';
      final senderId = _socketService.socket.auth['userId'] as String? ?? '';
      final senderName = _socketService.socket.auth['username'] as String? ?? '';

      if (senderId.isEmpty) return;

      final message = Message(
        id: messageId,
        roomId: roomId,
        senderId: senderId,
        senderName: senderName,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
      );

      if (!_messages.containsKey(roomId)) {
        _messages[roomId] = [];
      }

      _messages[roomId]!.add(message);
      _processedMessageIds.add('${roomId}_${messageId}');
      
      _saveLocalMessages(roomId, _messages[roomId]!);
      _updateLastMessageForRoom(roomId, content, message.timestamp);
      
      notifyListeners();
      
      _socketService.sendMessage(roomId, content, messageId);
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void _handleNewMessage(dynamic data) {
    try {
      final message = Message.fromJson(data);
      final messageKey = '${message.roomId}_${message.id}';
      
      if (_processedMessageIds.contains(messageKey)) return;
      
      if (!_messages.containsKey(message.roomId)) {
        _messages[message.roomId] = [];
      }
      
      _messages[message.roomId]!.add(message);
      _processedMessageIds.add(messageKey);
      
      _saveLocalMessages(message.roomId, _messages[message.roomId]!);
      _updateLastMessageForRoom(message.roomId, message.content, message.timestamp);
      
      notifyListeners();
    } catch (e) {
      print('Error handling new message: $e');
    }
  }

  Future<void> _loadSavedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomsJson = prefs.getStringList('chat_rooms');
      if (roomsJson != null) {
        _chatRooms = roomsJson
            .map((data) => ChatRoom.fromJson(json.decode(data)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading saved rooms: $e');
    }
  }

  Future<void> _saveRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomsJson = _chatRooms
          .map((room) => json.encode(room.toJson()))
          .toList();
      await prefs.setStringList('chat_rooms', roomsJson);
    } catch (e) {
      print('Error saving rooms: $e');
    }
  }

  Future<void> _loadAllSavedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (var room in _chatRooms) {
        final messagesJson = prefs.getStringList('messages_${room.id}');
        if (messagesJson != null) {
          _messages[room.id] = messagesJson
              .map((msg) => Message.fromJson(json.decode(msg)))
              .toList();
          
          for (var message in _messages[room.id]!) {
            _processedMessageIds.add('${room.id}_${message.id}');
          }
        }
      }
    } catch (e) {
      print('Error loading saved messages: $e');
    }
  }

  Future<void> _saveLocalMessages(String roomId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = messages
          .map((msg) => json.encode(msg.toJson()))
          .toList();
      await prefs.setStringList('messages_$roomId', messagesJson);
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  void _setupSocketListeners() {
    _socketService.socket.on('message', _handleNewMessage);
    _socketService.socket.on('new_chat_room', _handleNewChatRoom);
  }

  void _handleNewChatRoom(dynamic data) {
    try {
      final newRoom = ChatRoom.fromJson(data);
      if (!_chatRooms.any((room) => room.id == newRoom.id)) {
        _chatRooms.add(newRoom);
        _messages[newRoom.id] = [];
        _saveRooms();
        notifyListeners();
      }
    } catch (e) {
      print('Error handling new chat room: $e');
    }
  }

  void _updateLastMessageForRoom(String roomId, String content, DateTime timestamp) {
    final index = _chatRooms.indexWhere((room) => room.id == roomId);
    if (index != -1) {
      _chatRooms[index] = _chatRooms[index].copyWith(
        lastMessage: content,
        lastMessageTime: timestamp,
      );
      _saveRooms();
      notifyListeners();
    }
  }

  Future<void> deleteChatRoom(String roomId) async {
    if (roomId.isEmpty) return;

    try {
      final response = await http.delete(
        Uri.parse(ApiConstants.deleteChatRoom(roomId)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('messages_$roomId');

        _chatRooms.removeWhere((room) => room.id == roomId);
        _messages.remove(roomId);
        _processedMessageIds.removeWhere((key) => key.startsWith('${roomId}_'));

        _socketService.socket.emit('leave_room', roomId);

        await _saveRooms();
        notifyListeners();
      }
    } catch (e) {
      print('Error deleting chat room: $e');
      throw Exception('Failed to delete chat room: $e');
    }
  }

  void dispose() {
    _messages.clear();
    _processedMessageIds.clear();
    super.dispose();
  }
}