import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';


import '../../models/chat_room_model.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;

  const ChatRoomScreen({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Removed unused _userService field
  
  Timer? _typingTimer;
  bool _isTyping = false;
  String? _userTyping;
  bool _isInitialized = false;
  String _roomTitle = "Chat";
  
  // Track seen messages to avoid duplicates in UI
  Set<String> _displayedMessageIds = {};

  @override
  void initState() {
    super.initState();
    // Will load messages in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only initialize once
    if (!_isInitialized) {
      _isInitialized = true;
      _loadChatRoom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadChatRoom() async {
    // Load room details and messages
    await _loadRoomDetails();
    await _loadMessages();
  }
  
  Future<void> _loadRoomDetails() async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) return;
    
    try {
      // Find this room in the chat service
      final room = chatService.chatRooms.firstWhere(
        (room) => room.id == widget.roomId,
        orElse: () => ChatRoom(id: '', name: '', participants: [], createdAt: DateTime.now()),
      );
      
      // Use the room name from service
      setState(() {
        _roomTitle = room.name;
      });
      return;
      
      // If room not found in service or name is generic, try to get other participant's name
    } catch (e) {
      print('Error loading room details: $e');
    }
  }

  Future<void> _loadMessages() async {
  final chatService = Provider.of<ChatService>(context, listen: false);
  final authService = Provider.of<AuthService>(context, listen: false);
  
  try {
    // Añadir este debug log
    print('Cargando mensajes para sala: ${widget.roomId}');
    
    // Cargar mensajes para esta sala
    await chatService.loadMessages(widget.roomId);
    
    // Debug: verificar cuántos mensajes se cargaron
    print('Mensajes cargados: ${chatService.currentMessages.length}');

    // Mark messages as read
    if (authService.currentUser != null) {
      await chatService.markMessagesAsRead(authService.currentUser!.id);
    }

    // Scroll to the bottom after messages load
    _scrollToBottom();
  } catch (e) {
    print('Error loading messages: $e');
  }
}
  
  void _scrollToBottom() {
    // Delay to ensure the list is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final messageText = _messageController.text.trim();
    
    if (messageText.isEmpty) return;

    chatService.sendMessage(widget.roomId, messageText);
    _messageController.clear();
    
    // Scroll to bottom after sending (even before message appears)
    _scrollToBottom();
  }

  void _onTyping(String text) {
    final chatService = Provider.of<ChatService>(context, listen: false);

    // If the user starts typing and wasn't before, send typing event
    if (!_isTyping && text.trim().isNotEmpty) {
      _isTyping = true;
      chatService.sendTyping(widget.roomId);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    
    // Set timer to mark user as no longer typing after 2 seconds
    _typingTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _isTyping = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final currentUserId = authService.currentUser?.id ?? '';
    
    // Get messages without duplicates
    final messages = chatService.currentMessages;

    return Scaffold(
      appBar: AppBar(
        title: Text(_roomTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Recargar mensajes',
          ),
        ],
      ),
      body: chatService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Typing indicator
                if (_userTyping != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$_userTyping está escribiendo...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // Message list
               Expanded(
                 child: messages.isEmpty
                  ? _buildEmptyState()
                   : ListView.builder(
                       controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                      final message = messages[index];
            
                       // Debugging: imprime cada mensaje para verificar qué se está procesando
                      print('Renderizando mensaje: ${message.id} - ${message.content}');
            
            return _buildMessageItem(
              message,
              message.senderId == currentUserId,
            );
          },
        ),
),

                // Message input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 2,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file),
                        onPressed: () {
                          // Feature not implemented
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onChanged: _onTyping,
                          decoration: const InputDecoration(
                            hintText: 'Mensaje',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(24)),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Color(0xFFF3F3F3),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: Theme.of(context).primaryColor,
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay mensajes aún',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Envía el primer mensaje',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(Message message, bool isCurrentUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: isCurrentUser ? Colors.deepPurple[200] : Colors.grey[300],
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: isCurrentUser ? Colors.deepPurple[800] : Colors.black87,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isCurrentUser ? Colors.deepPurple : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser && message.senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrentUser ? Colors.white : Colors.black87,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(
                      color: isCurrentUser
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isCurrentUser)
            Icon(
              message.isRead ? Icons.done_all : Icons.done,
              size: 16,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}