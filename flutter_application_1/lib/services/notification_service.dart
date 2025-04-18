import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/notification.dart' as app;
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/services/socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    // Cargar notificaciones guardadas
    _loadSavedNotifications();
  }

  // Cargar notificaciones guardadas desde SharedPreferences
  Future<void> _loadSavedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsData = prefs.getStringList('notifications');
      
      if (notificationsData != null && notificationsData.isNotEmpty) {
        _notifications = notificationsData
            .map((data) => app.Notification.fromJson(json.decode(data)))
            .toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      print('Error cargando notificaciones guardadas: $e');
    }
  }

  // Guardar notificaciones en SharedPreferences
  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsData = _notifications
          .map((notif) => json.encode(notif.toJson()))
          .toList();
      
      await prefs.setStringList('notifications', notificationsData);
    } catch (e) {
      print('Error guardando notificaciones: $e');
    }
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
    try {
      final notification = app.Notification.fromJson(data);
      _notifications.insert(0, notification);
      _unreadCount++;
      
      // Guardar notificaciones actualizadas
      _saveNotifications();
      
      notifyListeners();
    } catch (e) {
      print('Error al procesar notificación: $e');
    }
  }

  // Cargar notificaciones para un usuario
  Future<void> loadNotifications(String userId, {bool onlyUnread = false}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final uri = Uri.parse(ApiConstants.userNotifications(userId)).replace(
        queryParameters: {
          'onlyUnread': onlyUnread.toString(),
        },
      );
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        List<app.Notification> serverNotifications = data
            .map((n) => app.Notification.fromJson(n))
            .toList();
        
        // Combinar notificaciones del servidor con las locales
        _mergeNotifications(serverNotifications);
        
        // Guardar notificaciones actualizadas
        _saveNotifications();
      }
    } catch (e) {
      print('Error al cargar notificaciones: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Combinar notificaciones del servidor con las locales
  void _mergeNotifications(List<app.Notification> serverNotifications) {
    // Identificar notificaciones nuevas del servidor
    for (final serverNotification in serverNotifications) {
      final existingIndex = _notifications.indexWhere((n) => n.id == serverNotification.id);
      
      if (existingIndex >= 0) {
        // Actualizar estado de lectura si es necesario
        if (serverNotification.isRead && !_notifications[existingIndex].isRead) {
          _notifications[existingIndex] = serverNotification;
        }
      } else {
        // Añadir nueva notificación
        _notifications.add(serverNotification);
        if (!serverNotification.isRead) {
          _unreadCount++;
        }
      }
    }
    
    // Ordenar por fecha, más recientes primero
    _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  // Marcar notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConstants.markNotificationRead(notificationId)),
      );
      
      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        
        if (index != -1) {
          final wasUnread = !_notifications[index].isRead;
          
          _notifications[index] = app.Notification(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            type: _notifications[index].type,
            content: _notifications[index].content,
            relatedId: _notifications[index].relatedId,
            isRead: true,
            timestamp: _notifications[index].timestamp,
          );
          
          if (wasUnread && _unreadCount > 0) {
            _unreadCount--;
          }
          
          // Guardar notificaciones actualizadas
          _saveNotifications();
          
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
        Uri.parse(ApiConstants.markAllNotificationsRead),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
        }),
      );
      
      if (response.statusCode == 200) {
        for (int i = 0; i < _notifications.length; i++) {
          if (!_notifications[i].isRead) {
            _notifications[i] = app.Notification(
              id: _notifications[i].id,
              userId: _notifications[i].userId,
              type: _notifications[i].type,
              content: _notifications[i].content,
              relatedId: _notifications[i].relatedId,
              isRead: true,
              timestamp: _notifications[i].timestamp,
            );
          }
        }
        
        _unreadCount = 0;
        
        // Guardar notificaciones actualizadas
        _saveNotifications();
        
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
        Uri.parse('${ApiConstants.notifications}/$notificationId'),
      );
      
      if (response.statusCode == 200) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        
        if (index != -1) {
          final wasUnread = !_notifications[index].isRead;
          _notifications.removeAt(index);
          
          if (wasUnread && _unreadCount > 0) {
            _unreadCount--;
          }
          
          // Guardar notificaciones actualizadas
          _saveNotifications();
          
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
        Uri.parse(ApiConstants.deleteUserNotifications(userId)),
      );
      
      if (response.statusCode == 200) {
        _notifications.clear();
        _unreadCount = 0;
        
        // Guardar notificaciones actualizadas
        _saveNotifications();
        
        notifyListeners();
      }
    } catch (e) {
      print('Error al eliminar todas las notificaciones: $e');
    }
  }

  // Crear una notificación local (para pruebas)
  void createLocalNotification(String userId, String type, String content, {String? relatedId}) {
    final notification = app.Notification(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      type: type,
      content: content,
      relatedId: relatedId,
      isRead: false,
      timestamp: DateTime.now(),
    );
    
    _notifications.insert(0, notification);
    _unreadCount++;
    
    // Guardar notificaciones actualizadas
    _saveNotifications();
    
    notifyListeners();
  }
}