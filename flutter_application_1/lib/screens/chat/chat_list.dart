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
    // Determine un icono en base al número de participantes
    IconData iconData = Icons.person;
    if (room.participants.length > 2) {
      iconData = Icons.group;
    }
    
    // Get display name - use room name as is (it should already be properly set by the chat service)
    String displayName = room.name;
    if (displayName.isEmpty) {
      displayName = 'Chat';
    }
    
    return Dismissible(
      key: Key(room.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirmar"),
              content: const Text("¿Estás seguro de que quieres eliminar este chat?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancelar"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Eliminar"),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        final chatService = Provider.of<ChatService>(context, listen: false);
        chatService.deleteChatRoom(room.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Chat "${displayName}" eliminado'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () {
                // Recargar salas para recuperar la eliminada (si es posible)
                _loadChatRooms();
              },
            ),
          ),
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple[100],
          child: Icon(
            iconData,
            color: Colors.deepPurple,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Badge for group chats
            if (room.participants.length > 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${room.participants.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepPurple[700],
                  ),
                ),
              ),
          ],
        ),
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
      ),
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
    bool isGroupChat = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isGroupChat ? 'Nuevo chat grupal' : 'Nuevo chat'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Switch entre chat individual y grupal
                  SwitchListTile(
                    title: const Text('Chat grupal'),
                    value: isGroupChat,
                    onChanged: (value) {
                      setState(() {
                        isGroupChat = value;
                        // Limpiar nombre de sala si cambiamos a chat individual
                        if (!isGroupChat) {
                          nameController.clear();
                        }
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Nombre del chat (solo para chats grupales)
                  if (isGroupChat)
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del grupo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  const Text('Selecciona usuarios para el chat:'),
                  const SizedBox(height: 8),
                  
                  // Chips for selected participants
                  if (selectedUserIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: SingleChildScrollView(
                        child: Wrap(
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
                      ),
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
                                  // Para chats individuales, reemplazar la selección
                                  // Para chats grupales, añadir a la lista
                                  if (isGroupChat) {
                                    selectedUserIds.add(value);
                                  } else {
                                    selectedUserIds = [value];
                                  }
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
                      const SnackBar(content: Text('Selecciona al menos un usuario para el chat')),
                    );
                    return;
                  }
                  
                  if (isGroupChat && nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Debes ingresar un nombre para el chat grupal')),
                    );
                    return;
                  }
                  
                  Navigator.pop(context);
                  
                  setState(() => _isCreatingChat = true);
                  
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
                    
                    // Determine chat name
                    String chatName;
                    if (isGroupChat) {
                      // Use the provided name for group chats
                      chatName = nameController.text.trim();
                    } else {
                      // Use the other user's name for individual chats
                      try {
                        final selectedUser = _users.firstWhere(
                          (u) => u['id'] == selectedUserIds[0],
                          orElse: () => {'id': selectedUserIds[0], 'username': 'Usuario'},
                        );
                        chatName = selectedUser['username'];
                      } catch (e) {
                        chatName = 'Chat';
                        print('Error getting username: $e');
                      }
                    }
                    
                    // Create chat room
                    final room = await chatService.createChatRoom(
                      chatName,
                      participants,
                      isGroupChat ? 'Chat grupal' : null,
                    );
                    
                    if (room != null) {
                      // Navigate to the new chat
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(roomId: room.id),
                        ),
                      ).then((_) {
                        // Reload chat rooms when returning from chat screen
                        _loadChatRooms();
                      });
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