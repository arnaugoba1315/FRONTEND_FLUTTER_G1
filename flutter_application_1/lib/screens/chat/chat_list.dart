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

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
    });

    try {
      final response = await _userService.getUsers(limit: 100);
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
      ),
      body: chatService.isLoading
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
      onRefresh: _loadChatRooms,
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
    
    // Filtrar para mostrar nombre del otro participante en chats privados
    String displayName = room.name;
    List<String> otherParticipants = room.participants.where((id) => id != currentUserId).toList();
    if (room.participants.length == 2 && otherParticipants.isNotEmpty) {
      displayName = otherParticipants[0];
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
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Ayer';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  void _showNewChatDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController participantsController = TextEditingController();
    List<String> selectedUserIds = [];
    
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
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del chat',
                      hintText: 'Ej: Amigos, Familia, etc.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Participantes:'),
                  const SizedBox(height: 8),
                  
                  // Chips para participantes seleccionados
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
                      : DropdownButtonFormField<String>(
                          hint: const Text('Seleccionar participante'),
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
                                selectedUserIds.add(value);
                              });
                            }
                          },
                        ),
                  
                  const SizedBox(height: 16),
                  const Text(
                    'O introduce nombres de usuario manualmente:',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: participantsController,
                    decoration: const InputDecoration(
                      labelText: 'Nombres de usuario (separados por coma)',
                      hintText: 'usuario1, usuario2, usuario3',
                    ),
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
                  if (nameController.text.isNotEmpty && 
                      (selectedUserIds.isNotEmpty || participantsController.text.isNotEmpty)) {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final chatService = Provider.of<ChatService>(context, listen: false);
                    final currentUserId = authService.currentUser?.id ?? '';
                    
                    // Añadir el usuario actual como participante
                    final participants = [currentUserId, ...selectedUserIds];
                    
                    // Añadir participantes por nombre de usuario si se ingresaron
                    if (participantsController.text.isNotEmpty) {
                      final usernames = participantsController.text
                          .split(',')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList();
                      
                      // Obtener IDs de estos usuarios
                      try {
                        for (var username in usernames) {
                          // Buscar usuario por nombre
                          final userData = await _userService.getUserByUsername(username);
                          if (userData != null && userData.id.isNotEmpty) {
                            // Evitar duplicados
                            if (!participants.contains(userData.id)) {
                              participants.add(userData.id);
                            }
                          }
                        }
                      } catch (e) {
                        print('Error al buscar usuarios por nombre: $e');
                      }
                    }
                    
                    // Crear sala de chat
                    final room = await chatService.createChatRoom(
                      nameController.text,
                      participants,
                    );
                    
                    if (room != null) {
                      // Navegar a la nueva sala
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatRoomScreen(roomId: room.id),
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error al crear la sala de chat')),
                      );
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