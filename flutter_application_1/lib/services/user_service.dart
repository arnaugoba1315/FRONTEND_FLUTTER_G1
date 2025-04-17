import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/models/user.dart';

class UserService {
  // Get all users with pagination
  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 10,
    bool includeHidden = false,
  }) async {
    try {
      final uri = Uri.parse(ApiConstants.users).replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
          if (includeHidden) 'includeInvisible': 'true',
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parse users list
        final List<User> users = [];
        if (data['users'] != null) {
          for (var item in data['users']) {
            users.add(User.fromJson(item));
          }
        }
        
        return {
          'users': users,
          'totalUsers': data['totalUsers'] ?? 0,
          'totalPages': data['totalPages'] ?? 1,
          'currentPage': data['currentPage'] ?? 1,
        };
      }
      
      throw Exception('Failed to load users: ${response.statusCode}');
    } catch (e) {
      print('Error getting users: $e');
      throw Exception('Failed to load users');
    }
  }

  // Get user by ID
  Future<User> getUserById(String id) async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.user(id)));

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      }
      
      throw Exception('Failed to load user: ${response.statusCode}');
    } catch (e) {
      print('Error getting user: $e');
      throw Exception('Failed to load user');
    }
  }

  // Get user by username
  Future<User?> getUserByUsername(String username) async {
    try {
      final uri = Uri.parse('${ApiConstants.users}/username/$username');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return User.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        // Usuario no encontrado, pero no es un error
        return null;
      }
      
      throw Exception('Failed to find user: ${response.statusCode}');
    } catch (e) {
      print('Error finding user by username: $e');
      return null;
    }
  }

  // Search users by username
  Future<List<User>> searchUsers(String searchText) async {
    try {
      final uri = Uri.parse('${ApiConstants.users}/search').replace(
        queryParameters: {
          'query': searchText,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((user) => User.fromJson(user)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Create user
  Future<User> createUser(Map<String, dynamic> userData) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.users),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['user'] != null) {
          return User.fromJson(data['user']);
        }
      }
      
      throw Exception('Failed to create user: ${response.statusCode}');
    } catch (e) {
      print('Error creating user: $e');
      throw Exception('Failed to create user');
    }
  }

  // Update user
  Future<User> updateUser(String id, Map<String, dynamic> userData) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConstants.user(id)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userData),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['user'] != null) {
          return User.fromJson(data['user']);
        }
      }
      
      throw Exception('Failed to update user: ${response.statusCode}');
    } catch (e) {
      print('Error updating user: $e');
      throw Exception('Failed to update user');
    }
  }

  // Delete user
  Future<bool> deleteUser(String id) async {
    try {
      final response = await http.delete(Uri.parse(ApiConstants.user(id)));
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting user: $e');
      return false;
    }
  }

  // Toggle user visibility
  Future<Map<String, dynamic>> toggleUserVisibility(String id) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConstants.toggleUserVisibility(id)),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      
      throw Exception('Failed to toggle user visibility: ${response.statusCode}');
    } catch (e) {
      print('Error toggling user visibility: $e');
      throw Exception('Failed to toggle user visibility');
    }
  }
}