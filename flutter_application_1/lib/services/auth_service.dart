import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/models/user.dart';

class AuthService with ChangeNotifier {
  User? _currentUser;
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _isAdmin;

  // Initialize the service and check if there's a stored user
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user');
    
    if (userData != null) {
      try {
        final user = User.fromJson(json.decode(userData));
        _currentUser = user;
        _isLoggedIn = true;
        _isAdmin = user.role == 'admin';
        notifyListeners();
      } catch (e) {
        print('Error parsing stored user data: $e');
        await logout();
      }
    }
  }

  // Login user
  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['user'] != null) {
          // Store the user in memory
          final user = User.fromJson(data['user']);
          _currentUser = user;
          _isLoggedIn = true;
          _isAdmin = user.role == 'admin';
          
          // Store user data in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', json.encode(data['user']));
          
          notifyListeners();
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  // Register user
  Future<bool> register(String username, String email, String password) async {
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

      return response.statusCode == 201;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    _currentUser = null;
    _isLoggedIn = false;
    _isAdmin = false;
    
    // Clear stored user data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    
    notifyListeners();
  }
}