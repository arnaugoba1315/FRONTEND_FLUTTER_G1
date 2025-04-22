import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/config/routes.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

import '../../services/socket_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _bioController;
  late TextEditingController _profilePictureController;
  
  bool _isLoading = false;
  bool _isEditing = false;
  String _errorMessage = '';
  String _successMessage = '';
  User? _user;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _bioController = TextEditingController();
    _profilePictureController = TextEditingController();
    
    // Load user data
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _profilePictureController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final userId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
      
      if (userId != null) {
        final user = await _userService.getUserById(userId);
        
        setState(() {
          _user = user;
          _usernameController.text = user?.username ?? '';
          _emailController.text = user!.email;
          _bioController.text = user.bio ?? '';
          _profilePictureController.text = user.profilePicture ?? '';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading user data';
      });
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _successMessage = '';
      });

      try {
        final userData = {
          'username': _usernameController.text,
          'email': _emailController.text,
          'bio': _bioController.text,
          'profilePicture': _profilePictureController.text,
        };

        final updatedUser = await _userService.updateUser(_user!.id, userData);
        
        // Update local user data
        setState(() {
          _user = updatedUser;
          _successMessage = 'Profile updated successfully';
          _isEditing = false;
        });
        
        // Update auth service with new user data
        Provider.of<AuthService>(context, listen: false);
        // This would typically include logic to update the stored user in the auth service
        
      } catch (e) {
        setState(() {
          _errorMessage = 'Error updating profile';
        });
        print('Error updating profile: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, AppRoutes.userHome);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final socketService = Provider.of<SocketService>(context, listen: false);
              await authService.logout(socketService);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('No user data available'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error, color: Colors.red.shade800),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  _errorMessage,
                                  style: TextStyle(color: Colors.red.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_successMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12.0),
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade800),
                              const SizedBox(width: 8.0),
                              Expanded(
                                child: Text(
                                  _successMessage,
                                  style: TextStyle(color: Colors.green.shade800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Card(
                        elevation: 4.0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.0),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 40.0,
                                    backgroundColor: Colors.grey.shade200,
                                    backgroundImage: _user!.profilePicture != null && _user!.profilePicture!.isNotEmpty
                                        ? NetworkImage(_user!.profilePicture!)
                                        : null,
                                    child: _user!.profilePicture == null || _user!.profilePicture!.isEmpty
                                        ? const Icon(
                                            Icons.person,
                                            size: 40.0,
                                            color: Colors.grey,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _user!.username,
                                          style: const TextStyle(
                                            fontSize: 24.0,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _user!.email,
                                          style: const TextStyle(
                                            fontSize: 16.0,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 8.0),
                                        Text(
                                          'Level: ${_user!.level}',
                                          style: const TextStyle(
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!_isEditing)
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = true;
                                        });
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16.0),
                              if (!_isEditing) ...[
                                const Divider(),
                                ListTile(
                                  leading: const Icon(Icons.info_outline),
                                  title: const Text('Biography'),
                                  subtitle: Text(
                                    _user!.bio ?? 'No biography available',
                                    style: const TextStyle(fontSize: 14.0),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.directions_run),
                                  title: const Text('Total Distance'),
                                  subtitle: Text(
                                    '${(_user!.totalDistance / 1000).toStringAsFixed(2)} km',
                                    style: const TextStyle(fontSize: 14.0),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.timer),
                                  title: const Text('Total Time'),
                                  subtitle: Text(
                                    '${_user!.totalTime} minutes',
                                    style: const TextStyle(fontSize: 14.0),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.event_note),
                                  title: const Text('Activities'),
                                  subtitle: Text(
                                    '${_user!.activities?.length ?? 0} activities',
                                    style: const TextStyle(fontSize: 14.0),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.emoji_events),
                                  title: const Text('Achievements'),
                                  subtitle: Text(
                                    '${_user!.achievements?.length ?? 0} achievements',
                                    style: const TextStyle(fontSize: 14.0),
                                  ),
                                ),
                                ListTile(
                                  leading: const Icon(Icons.flag),
                                  title: const Text('Challenges Completed'),
                                  subtitle: Text(
                                    '${_user!.challengesCompleted?.length ?? 0} challenges',
                                    style: const TextStyle(fontSize: 14.0),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 16.0),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _usernameController,
                                        decoration: const InputDecoration(
                                          labelText: 'Username',
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Username is required';
                                          }
                                          if (value.length < 4) {
                                            return 'Username must be at least 4 characters';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16.0),
                                      TextFormField(
                                        controller: _emailController,
                                        decoration: const InputDecoration(
                                          labelText: 'Email',
                                          border: OutlineInputBorder(),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Email is required';
                                          }
                                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                              .hasMatch(value)) {
                                            return 'Please enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16.0),
                                      TextFormField(
                                        controller: _profilePictureController,
                                        decoration: const InputDecoration(
                                          labelText: 'Profile Picture URL',
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                      const SizedBox(height: 16.0),
                                      TextFormField(
                                        controller: _bioController,
                                        decoration: const InputDecoration(
                                          labelText: 'Biography',
                                          border: OutlineInputBorder(),
                                        ),
                                        maxLines: 3,
                                      ),
                                      const SizedBox(height: 24.0),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () {
                                              setState(() {
                                                _isEditing = false;
                                                
                                                // Reset form data
                                                _usernameController.text = _user!.username;
                                                _emailController.text = _user!.email;
                                                _bioController.text = _user!.bio ?? '';
                                                _profilePictureController.text = _user!.profilePicture ?? '';
                                              });
                                            },
                                            child: const Text('Cancel'),
                                          ),
                                          const SizedBox(width: 16.0),
                                          ElevatedButton(
                                            onPressed: _isLoading ? null : _saveProfile,
                                            child: _isLoading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2.0,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text('Save Changes'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}