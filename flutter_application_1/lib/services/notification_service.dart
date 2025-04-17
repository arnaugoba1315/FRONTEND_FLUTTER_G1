import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/notification.dart' as app;
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/services/socket_service.dart';

class NotificationService with ChangeNotifier {
  final SocketService _socketService;
  
  List<app.Notification> _notifications = [];
  bool _isLoading = false;
  int _unreadCount = 0;

  // Getters
  List<app.Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _unreadCount;

  // Constructor
  NotificationService(this._socketService) {
    // Configurar listeners para Socket.IO
    _setupSocketListeners();
  }

  // Configurar listeners para Socket.IO
  void _setupSocketListeners() {
    _socketService.socket.on('notification', (data) {
      print('Notificación recibida: $data');
      _handleNewNotification(data);
    });
  }

  // Manejar nueva notificación
  void _handleNewNotification(dynamic data) {
    final notification = app.Notification.fromJson(data);
    _notifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();
  }

  // Cargar notificaciones para un usuario
  Future<void> loadNotifications(String userId, {bool onlyUnread = false}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/notifications/user/$userId').replace(
        queryParameters: {
          'onlyUnread': onlyUnread.toString(),
        },
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _notifications = data.map((n) => app.Notification.fromJson(n)).toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      }
    } catch (e) {
      print('Error al cargar notificaciones: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.baseUrl}/api/notifications/$notificationId/read'),
      );
      
      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        
        if (index != -1) {
          final updatedNotification = app.Notification(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            type: _notifications[index].type,
            content: _notifications[index].content,
            relatedId: _notifications[index].relatedId,
            isRead: true,
            timestamp: _notifications[index].timestamp,
          );
          
          _notifications[index] = updatedNotification;
          
          if (_unreadCount > 0) {
            _unreadCount--;
          }
          
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error al marcar notificación como leída: $e');
    }
  }

  // Marcar todas las notificaciones como leídas
  Future<void> markAllAsRead(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/notifications/read-all'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
        }),
      );
      
      if (response.statusCode == 200) {
        _notifications = _notifications.map((n) {
          return app.Notification(
            id: n.id,
            userId: n.userId,
            type: n.type,
            content: n.content,
            relatedId: n.relatedId,
            isRead: true,
            timestamp: n.timestamp,
          );
        }).toList();
        
        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      print('Error al marcar todas las notificaciones como leídas: $e');
    }
  }

  // Eliminar notificación
  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/notifications/$notificationId'),
      );
      
      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        
        if (index != -1) {
          final wasUnread = !_notifications[index].isRead;
          _notifications.removeAt(index);
          
          if (wasUnread && _unreadCount > 0) {
            _unreadCount--;
          }
          
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error al eliminar notificación: $e');
    }
  }

  // Eliminar todas las notificaciones
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/api/notifications/user/$userId'),
      );
      
      if (response.statusCode == 200) {
        _notifications.clear();
        _unreadCount = 0;
        notifyListeners();
      }
    } catch (e) {
      print('Error al eliminar todas las notificaciones: $e');
    }
  }
}