import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/models/notification.dart' as app;
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    
    if (authService.currentUser != null) {
      await notificationService.loadNotifications(authService.currentUser!.id);
      await notificationService.markAllAsRead(authService.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = Provider.of<NotificationService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _showClearConfirmDialog(context),
            tooltip: 'Borrar todas',
          ),
        ],
      ),
      body: notificationService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notificationService.notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(notificationService.notifications),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes notificaciones',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(List<app.Notification> notifications) {
    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }

  Widget _buildNotificationItem(app.Notification notification) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        final notificationService = Provider.of<NotificationService>(context, listen: false);
        notificationService.deleteNotification(notification.id);
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification.type),
          child: Text(
            notification.typeIcon,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        title: Text(notification.content),
        subtitle: Text(
          notification.formattedTimestamp,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: notification.isRead
            ? null
            : Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.deepPurple,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          // Navegar a la pantalla relacionada con la notificación
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'achievement':
        return Colors.amber;
      case 'challenge':
        return Colors.green;
      case 'activity':
        return Colors.blue;
      case 'message':
        return Colors.deepPurple;
      case 'friend':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _handleNotificationTap(app.Notification notification) {
    final notificationService = Provider.of<NotificationService>(context, listen: false);
    
    // Marcar como leída si no lo está
    if (!notification.isRead) {
      notificationService.markAsRead(notification.id);
    }
    
    // Navegar según el tipo de notificación
    switch (notification.type) {
      case 'message':
        // Navegar a la sala de chat
        if (notification.relatedId != null) {
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => ChatRoomScreen(roomId: notification.relatedId!),
          //   ),
          // );
        }
        break;
      case 'activity':
        // Navegar a los detalles de actividad
        break;
      case 'achievement':
        // Navegar a los logros
        break;
      case 'challenge':
        // Navegar a los retos
        break;
      default:
        // No hacer nada
        break;
    }
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar notificaciones'),
        content: const Text('¿Estás seguro de que quieres borrar todas las notificaciones?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final authService = Provider.of<AuthService>(context, listen: false);
              final notificationService = Provider.of<NotificationService>(context, listen: false);
              
              if (authService.currentUser != null) {
                notificationService.deleteAllNotifications(authService.currentUser!.id);
              }
              
              Navigator.pop(context);
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }
}