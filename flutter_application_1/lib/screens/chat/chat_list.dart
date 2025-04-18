import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/models/chat_room_model.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_service.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/screens/chat/chat_room.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final UserService _userService = UserService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoadingUsers = false;
  bool _isInitialized = false;
  bool _isCreatingChat = false;

  @override
  void initState() {
    super.initState();
    // NO cargar datos aquí, usar didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Solo inicializar una vez
    if (!_isInitialized) {
      _isInitialized = true;
      // Usar Future.microtask para evitar setState durante build
      Future.microtask(() {
        _loadChatRooms();
        _loadUsers();
      });
    }
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final response = await _userService.getUsers(limit: 100);
      
      if (!mounted) return;
      
      setState(() {
        _users = response['users']
            .map<Map<String, dynamic>>((user) => {
                  'id': user.id,
                  'username': user.username,
                })
            .toList();
        _isLoadingUsers = false;
      });
    } catch (e) {
      print('Error cargando usuarios: $e');
      
      if (!mounted) return;
      
      setState(() {
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _loadChatRooms() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final chatService = Provider.of<ChatService>(context, listen: false);
    
    if (authService.currentUser != null) {
      await chatService.loadChatRooms(authService.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final chatService = Provider.of<ChatService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatRooms,
            tooltip: 'Recargar chats',
          ),
        ],
      ),
      body: _isCreatingChat
          ? const Center(child: CircularProgressIndicator())
          : chatService.isLoading
              ? const Center(child: CircularProgressIndicator())
              : chatService.chatRooms.isEmpty
                  ? _buildEmptyState()
                  : _buildChatRoomsList(chatService.chatRooms),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatDialog(context),
        child: const Icon(Icons.add),
        tooltip: 'Nuevo chat',
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
            'No tienes conversaciones',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Inicia un nuevo chat con el botón +',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatRoomsList(List<ChatRoom> chatRooms) {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadChatRooms();
      },
      child: ListView.builder(
        itemCount: chatRooms.length,
        itemBuilder: (context, index) {
          final room = chatRooms[index];
          return _buildChatRoomItem(room);
        },
      ),
    );
  }

  Widget _buildChatRoomItem(ChatRoom room) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUserId = authService.currentUser?.id ?? '';
    
    // Get display name - use room name as is (it should already be properly set by the chat service)
    String displayName = room.name;
    if (displayName.isEmpty || displayName == 'Chat Room') {
      displayName = 'Chat';
    }
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.deepPurple[100],
        child: Text(
          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
          style: const TextStyle(color: Colors.deepPurple),
        ),
      ),
      title: Text(displayName),
      subtitle: room.lastMessage != null
          ? Text(
              room.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : const Text(
              'No hay mensajes aún',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
      trailing: room.lastMessageTime != null
          ? Text(
              _formatTime(room.lastMessageTime!),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            )
          : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(roomId: room.id),
          ),
        ).then((_) {
          // Reload chat rooms when returning from chat screen
          _loadChatRooms();
        });
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Ayer';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _showNewChatDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    List<String> selectedUserIds = [];
    String? selectedUserId;  // Variable for the current dropdown selection
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Nuevo chat'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skip room name for direct chats - we'll use the other user's name
                  
                  const Text('Selecciona un usuario para chatear:'),
                  const SizedBox(height: 16),
                  
                  // Chips for selected participants
                  if (selectedUserIds.isNotEmpty)
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: selectedUserIds.map((userId) {
                        final user = _users.firstWhere(
                          (u) => u['id'] == userId,
                          orElse: () => {'id': userId, 'username': 'Usuario'},
                        );
                        return Chip(
                          label: Text(user['username']),
                          onDeleted: () {
                            setState(() {
                              selectedUserIds.remove(userId);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  
                  const SizedBox(height: 16),
                  _isLoadingUsers
                      ? const Center(child: CircularProgressIndicator())
                      : _users.isEmpty
                        ? const Text('No hay usuarios disponibles')
                        : DropdownButton<String>(
                            hint: const Text('Seleccionar usuario'),
                            value: selectedUserId,
                            isExpanded: true,
                            items: _users
                                .where((user) => !selectedUserIds.contains(user['id']))
                                .map<DropdownMenuItem<String>>((user) {
                              return DropdownMenuItem<String>(
                                value: user['id'],
                                child: Text(user['username']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedUserIds = [value]; // For direct chats, just use one user
                                  selectedUserId = null; // Reset after selecting
                                });
                              }
                            },
                          ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  if (selectedUserIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Selecciona un usuario para chatear')),
                    );
                    return;
                  }
                  
                  setState(() => _isCreatingChat = true);
                  Navigator.pop(context);
                  
                  try {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final chatService = Provider.of<ChatService>(context, listen: false);
                    final currentUserId = authService.currentUser?.id ?? '';
                    
                    if (currentUserId.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error: No se pudo identificar el usuario actual')),
                      );
                      return;
                    }
                    
                    // Add the current user to participants list
                    final participants = [currentUserId, ...selectedUserIds];
                    
                    // Get the selected user's name as chat name
                    String chatName = 'Chat';
                    try {
                      // Find the username in our loaded users list
                      final selectedUser = _users.firstWhere(
                        (u) => u['id'] == selectedUserIds[0],
                        orElse: () => {'id': selectedUserIds[0], 'username': 'Chat'},
                      );
                      chatName = selectedUser['username'];
                    } catch (e) {
                      print('Error getting username: $e');
                    }
                    
                    // Create chat room with the other user's name
                    final room = await chatService.createChatRoom(
                      chatName, // This will be replaced with the other user's name in the service
                      participants,
                    );
                    
                    if (room != null) {
                      // Navigate to the new chat
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(roomId: room.id),
                        ),
                      );
                    } else {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error al crear la sala de chat')),
                      );
                    }
                  } catch (e) {
                    print('Error creating chat room: $e');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isCreatingChat = false);
                    }
                  }
                },
                child: const Text('Crear'),
              ),
            ],
          );
        },
      ),
    );
  }
}