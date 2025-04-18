import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';
import 'package:flutter_application_1/models/chat_room_model.dart';
import 'package:flutter_application_1/services/socket_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;

  const ChatRoomScreen({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isInitialized = false;
  String _roomTitle = "Chat";
  ChatRoom? _currentRoom;
  bool _isAtBottom = true;
  Timer? _roomRefreshTimer;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
        setState(() {
          _isAtBottom = true;
        });
      } else {
        setState(() {
          _isAtBottom = false;
        });
      }
    });
    
    // Configurar temporizador para recargar periódicamente
    _roomRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _loadMessages();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Solo inicializar una vez
    if (!_isInitialized) {
      _isInitialized = true;
      _loadChatRoom();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // La app volvió al primer plano, recargar mensajes
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _roomRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
      
      setState(() {
        _currentRoom = room;
        _roomTitle = room.name.isNotEmpty ? room.name : 'Chat';
      });
    } catch (e) {
      print('Error loading room details: $e');
    }
  }

  Future<void> _loadMessages() async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    
    try {
      // Cargar mensajes para esta sala
      await chatService.loadMessages(widget.roomId);

      // Mark messages as read
      if (authService.currentUser != null) {
        await chatService.markMessagesAsRead(authService.currentUser!.id);
      }

      // Scroll to the bottom if we were already at the bottom
      if (_isAtBottom) {
        _scrollToBottom();
      }
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
    
    // Scroll to bottom after sending
    setState(() {
      _isAtBottom = true;
    });
    _scrollToBottom();
  }

  void _onTyping(String text) {
    final chatService = Provider.of<ChatService>(context, listen: false);

    if (text.trim().isNotEmpty) {
      chatService.sendTyping(widget.roomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final currentUserId = authService.currentUser?.id ?? '';
    final userTyping = Provider.of<SocketService>(context).userTyping;
    
    // Get messages for this room
    final messages = chatService.currentMessages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_roomTitle),
            if (_currentRoom != null && _currentRoom!.participants.length > 2)
              Text(
                '${_currentRoom!.participants.length} participantes',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Recargar mensajes',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showRoomInfo();
                  break;
                case 'leave':
                  _leaveRoom();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('Información'),
                ),
              ),
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app),
                  title: Text('Salir del chat'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: chatService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Typing indicator
                if (userTyping != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '$userTyping está escribiendo...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
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
                          final bool isCurrentUser = message.senderId == currentUserId;
                          
                          return _buildMessageItem(
                            message,
                            isCurrentUser,
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Función no disponible aún')),
                          );
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
  
  void _showRoomInfo() {
    if (_currentRoom == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_roomTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${_currentRoom!.id}'),
            const SizedBox(height: 8),
            Text('Participantes: ${_currentRoom!.participants.length}'),
            const SizedBox(height: 8),
            Text('Creado: ${_formatDate(_currentRoom!.createdAt)}'),
            if (_currentRoom!.description != null && _currentRoom!.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Descripción: ${_currentRoom!.description}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  void _leaveRoom() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir del chat'),
        content: const Text('¿Estás seguro de que quieres salir de este chat? Se eliminará de tu lista de chats.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              
              final chatService = Provider.of<ChatService>(context, listen: false);
              chatService.deleteChatRoom(widget.roomId);
              
              Navigator.pop(context); // Volver a la lista de chats
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}
