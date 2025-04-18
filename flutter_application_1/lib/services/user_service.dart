import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/config/api_constants.dart';
import 'package:flutter_application_1/models/user.dart';

class UserService {
  // In-memory cache for users to reduce API calls
  final Map<String, User> _userCache = {};
  
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
      print('User API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parse users list
        final List<User> users = [];
        if (data['users'] != null) {
          for (var item in data['users']) {
            final user = User.fromJson(item);
            users.add(user);
            
            // Update cache
            _userCache[user.id] = user;
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
  Future<User?> getUserById(String id) async {
    // Return from cache if available 
    if (_userCache.containsKey(id)) {
      return _userCache[id];
    }
    
    try {
      final response = await http.get(Uri.parse(ApiConstants.user(id)));

      if (response.statusCode == 200) {
        final user = User.fromJson(json.decode(response.body));
        
        // Add to cache
        _userCache[id] = user;
        
        return user;
      } else if (response.statusCode == 404) {
        return null;
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
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/users/username/$username');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final user = User.fromJson(json.decode(response.body));
        
        // Add to cache
        _userCache[user.id] = user;
        
        return user;
      } else if (response.statusCode == 404) {
        // User not found, but not an error
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
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/users/search').replace(
        queryParameters: {
          'query': searchText,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final users = data.map((user) => User.fromJson(user)).toList();
        
        // Update cache
        for (var user in users) {
          _userCache[user.id] = user;
        }
        
        return users;
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
          final newUser = User.fromJson(data['user']);
          
          // Add to cache
          _userCache[newUser.id] = newUser;
          
          return newUser;
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
          final updatedUser = User.fromJson(data['user']);
          
          // Update cache
          _userCache[updatedUser.id] = updatedUser;
          
          return updatedUser;
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
      
      if (response.statusCode == 200) {
        // Remove from cache
        _userCache.remove(id);
        return true;
      }
      
      return false;
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
        final result = json.decode(response.body);
        
        // Update cache if user data is returned
        if (result['user'] != null) {
          final userData = result['user'];
          if (userData['id'] != null) {
            // Remove from cache to force refresh next time
            _userCache.remove(userData['id']);
          }
        }
        
        return result;
      }
      
      throw Exception('Failed to toggle user visibility: ${response.statusCode}');
    } catch (e) {
      print('Error toggling user visibility: $e');
      throw Exception('Failed to toggle user visibility');
    }
  }
  
  // Clear cache
  void clearCache() {
    _userCache.clear();
  }
}