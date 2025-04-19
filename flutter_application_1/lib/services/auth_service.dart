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
  bool _isLoading = false;
  String _error = '';

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String get error => _error;

  bool? get isAdmin => null;

  // Initialize service and check for stored user
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    
    if (userData != null) {
      try {
        print("Stored user data: $userData");
        final parsedJson = json.decode(userData);
        
        if (parsedJson['_id'] == null && parsedJson['id'] == null) {
          print("WARNING: No user ID found in stored data");
        }
        
        final user = User.fromJson(parsedJson);
        
        if (user.id.isEmpty) {
          print("ERROR: Empty user ID after parsing stored data");
          await logout();
        } else {
          _currentUser = user;
          _isLoggedIn = true;
          print("User initialized successfully with ID: ${user.id}");
        }
      } catch (e) {
        print('Error parsing stored user data: $e');
        await logout();
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<User?> login(String username, String password, SocketService socketService) async {
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

      print("Server response (login): ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['user'] != null) {
          final userData = data['user'];
          
          if (userData['_id'] == null && userData['id'] == null) {
            print("ERROR: No _id or id found in server response");
            _error = 'Server response error: missing user ID';
            _isLoading = false;
            notifyListeners();
            return null;
          }
          
          final user = User.fromJson(userData);
          
          if (user.id.isEmpty) {
            print("Error: Empty user ID after login");
            _error = 'Authentication error: empty user ID';
            _isLoading = false;
            notifyListeners();
            return null;
          }
          
          print("User created successfully with ID: ${user.id}");
          
          _currentUser = user;
          _isLoggedIn = true;
          
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', json.encode(userData));
          
          socketService.disconnect();
          await Future.delayed(Duration(milliseconds: 500));
          socketService.connect(user);
          
          _isLoading = false;
          notifyListeners();
          return user;
        } else {
          print("ERROR: No 'user' object found in server response");
          _error = 'Invalid server response format';
        }
      } else {
        print("ERROR: HTTP status code ${response.statusCode}");
        _error = 'Invalid credentials';
      }
      
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      print('Connection error: $e');
      _error = 'Connection error: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

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
      _error = 'Registration error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout([SocketService? socketService]) async {
    if (socketService != null) {
      socketService.disconnect();
    }
    
    _currentUser = null;
    _isLoggedIn = false;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }
}