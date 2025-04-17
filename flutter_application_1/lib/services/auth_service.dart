import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/socket_service.dart';

class AuthService with ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isLoading = false;
  String _error = '';

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  String get error => _error;

  // Inicializar el servicio y verificar si hay un usuario almacenado
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    
    if (userData != null) {
      try {
        print("Datos de usuario guardados: $userData");
        final parsedJson = json.decode(userData);
        
        // Verificar si hay un problema con el ID
        if (parsedJson['_id'] == null && parsedJson['id'] == null) {
          print("ADVERTENCIA: No se encontró ID de usuario en los datos guardados");
        }
        
        final user = User.fromJson(parsedJson);
        
        if (user.id.isEmpty) {
          print("ERROR: ID de usuario vacío después de parsear los datos guardados");
          await logout(); // Limpiar datos inconsistentes
        } else {
          _currentUser = user;
          _isLoggedIn = true;
          _isAdmin = user.role == 'admin';
          print("Usuario inicializado correctamente con ID: ${user.id}");
        }
      } catch (e) {
        print('Error al analizar datos de usuario almacenados: $e');
        await logout();
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Iniciar sesión de usuario
  Future<bool> login(String username, String password, SocketService socketService) async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password
        }),
      );

      print("Respuesta del servidor (login): ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['user'] != null) {
          // Verificar si hay ID en la respuesta
          final userData = data['user'];
          
          if (userData['_id'] == null && userData['id'] == null) {
            print("ERROR: No se encontró _id o id en la respuesta del servidor");
            _error = 'Error en la respuesta del servidor: falta ID de usuario';
            _isLoading = false;
            notifyListeners();
            return false;
          }
          
          // Almacenar el usuario en memoria
          final user = User.fromJson(userData);
          
          if (user.id.isEmpty) {
            print("Error: ID de usuario vacío después del inicio de sesión");
            _error = 'Error en la autenticación: ID de usuario vacío';
            _isLoading = false;
            notifyListeners();
            return false;
          }
          
          print("Usuario creado correctamente con ID: ${user.id}");
          
          _currentUser = user;
          _isLoggedIn = true;
          _isAdmin = user.role == 'admin';
          
          // Almacenar datos de usuario en SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', json.encode(userData));
          
          // Primero desconectar si ya estaba conectado
          socketService.disconnect();
          
          // Esperar un momento antes de intentar conectar para evitar errores
          await Future.delayed(Duration(milliseconds: 500));
          
          // Conectar Socket.IO
          socketService.connect(user);
          
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          print("ERROR: No se encontró objeto 'user' en la respuesta del servidor");
          _error = 'Formato de respuesta del servidor inválido';
        }
      } else {
        print("ERROR: Código de estado HTTP ${response.statusCode}");
        _error = 'Credenciales inválidas';
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('Error de conexión: $e');
      _error = 'Error de conexión: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Registrar usuario
  Future<bool> register(String username, String email, String password) async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password
        }),
      );

      _isLoading = false;
      notifyListeners();
      
      return response.statusCode == 201;
    } catch (e) {
      _error = 'Error de registro: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cerrar sesión de usuario
  Future<void> logout([SocketService? socketService]) async {
    // Desconectar Socket.IO si se proporciona
    if (socketService != null) {
      socketService.disconnect();
    }
    
    _currentUser = null;
    _isLoggedIn = false;
    _isAdmin = false;
    
    // Eliminar datos de usuario almacenados
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}