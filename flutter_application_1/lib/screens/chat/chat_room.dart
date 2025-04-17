import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';

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
  Timer? _typingTimer;
  bool _isTyping = false;
  String? _userTyping;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    await chatService.loadMessages(widget.roomId);

    // Marcar mensajes como leídos
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.currentUser != null) {
      await chatService.markMessagesAsRead(authService.currentUser!.id);
    }

    // Desplazar al último mensaje
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
    if (_messageController.text.trim().isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.sendMessage(_messageController.text.trim());
    _messageController.clear();

    // Desplazar al último mensaje
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTyping(String text) {
    final chatService = Provider.of<ChatService>(context, listen: false);

    // Si el usuario comienza a escribir, enviar evento
    if (!_isTyping && text.trim().isNotEmpty) {
      _isTyping = true;
      chatService.sendTyping();
    }

    // Reiniciar el temporizador
    if (_typingTimer?.isActive ?? false) {
      _typingTimer!.cancel();
    }

    // Establecer temporizador para detectar cuando el usuario deja de escribir
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    final currentUserId = authService.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(chatService.currentRoomId != null ? 'Chat' : 'Cargando...'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Mostrar información de la sala
            },
          ),
        ],
      ),
      body: chatService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Mostrar "Escribiendo..." si corresponde
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

                // Lista de mensajes
                Expanded(
                  child: chatService.currentMessages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: chatService.currentMessages.length,
                          itemBuilder: (context, index) {
                            final message = chatService.currentMessages[index];
                            return _buildMessageItem(
                              message,
                              message.senderId == currentUserId,
                            );
                          },
                        ),
                ),

                // Campo de entrada de mensaje
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
                          // Implementar adjuntar archivo
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
              backgroundColor: Colors.grey[300],
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
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
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}