import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/user_service.dart';
import 'package:flutter_application_1/widgets/user_card.dart';
import 'package:flutter_application_1/widgets/user_edit_form.dart';
import 'package:flutter_application_1/widgets/user_create_form.dart';

class UsersManagement extends StatefulWidget {
  const UsersManagement({Key? key}) : super(key: key);

  @override
  _UsersManagementState createState() => _UsersManagementState();
}

class _UsersManagementState extends State<UsersManagement> {
  final UserService _userService = UserService();
  
  List<User> _users = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalUsers = 0;
  bool _isLoading = false;
  bool _includeHidden = true;
  String _errorMessage = '';
  
  // For editing and creating users
  bool _showEditForm = false;
  bool _showCreateForm = false;
  User? _selectedUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _userService.getUsers(
        page: _currentPage,
        limit: 10,
        includeHidden: _includeHidden,
      );
      
      setState(() {
        _users = response['users'];
        _totalUsers = response['totalUsers'];
        _totalPages = response['totalPages'];
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading users';
      });
      print('Error loading users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUsers() async {
    await _loadUsers();
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
    });
    _loadUsers();
  }

  Future<void> _toggleUserVisibility(User user) async {
    try {
      await _userService.toggleUserVisibility(user.id);
      _refreshUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling user visibility: $e')),
      );
    }
  }

  Future<void> _deleteUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete user ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _userService.deleteUser(user.id);
        _refreshUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting user: $e')),
        );
      }
    }
  }

  void _showUserDetails(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.username),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.profilePicture != null && user.profilePicture!.isNotEmpty)
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(user.profilePicture!),
                  ),
                ),
              const SizedBox(height: 16),
              _detailRow('Email', user.email),
              _detailRow('Level', user.level.toString()),
              _detailRow('Total Distance', '${(user.totalDistance / 1000).toStringAsFixed(2)} km'),
              _detailRow('Total Time', '${user.totalTime} minutes'),
              _detailRow('Activities', '${user.activities?.length ?? 0}'),
              _detailRow('Achievements', '${user.achievements?.length ?? 0}'),
              _detailRow('Challenges', '${user.challengesCompleted?.length ?? 0}'),
              _detailRow('Visibility', user.visibility ? 'Visible' : 'Hidden'),
              _detailRow('Role', user.role),
              _detailRow('Created', user.createdAt.toString()),
              _detailRow('Updated', user.updatedAt.toString()),
              if (user.bio != null && user.bio!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Biography:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(user.bio!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _editUser(User user) {
    setState(() {
      _selectedUser = user;
      _showEditForm = true;
    });
  }

  void _createUser() {
    setState(() {
      _showCreateForm = true;
    });
  }

  void _cancelCreateUser() {
    setState(() {
      _showCreateForm = false;
    });
  }

  void _userCreated() {
    setState(() {
      _showCreateForm = false;
    });
    _refreshUsers();
  }

  void _cancelEditUser() {
    setState(() {
      _showEditForm = false;
      _selectedUser = null;
    });
  }

  void _userUpdated() {
    setState(() {
      _showEditForm = false;
      _selectedUser = null;
    });
    _refreshUsers();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCreateForm) {
      return UserCreateForm(
        onCancel: _cancelCreateUser,
        onUserCreated: _userCreated,
      );
    }

    if (_showEditForm && _selectedUser != null) {
      return UserEditForm(
        user: _selectedUser!,
        onCancel: _cancelEditUser,
        onUserUpdated: _userUpdated,
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshUsers,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Users Management',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Row(
                          children: [
                            const Text('Show Hidden:'),
                            Switch(
                              value: _includeHidden,
                              onChanged: (value) {
                                setState(() {
                                  _includeHidden = value;
                                });
                                _refreshUsers();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Expanded(
                    child: _users.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No users found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _createUser,
                                  child: const Text('Create User'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              return UserCard(
                                user: user,
                                onView: () => _showUserDetails(user),
                                onEdit: () => _editUser(user),
                                onDelete: () => _deleteUser(user),
                                onToggleVisibility: () => _toggleUserVisibility(user),
                              );
                            },
                          ),
                  ),
                  if (_totalPages > 1)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: _currentPage > 1
                                ? () => _changePage(_currentPage - 1)
                                : null,
                          ),
                          const SizedBox(width: 8),
                          ...List.generate(
                            _totalPages,
                            (index) {
                              final page = index + 1;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                child: ElevatedButton(
                                  onPressed: page != _currentPage
                                      ? () => _changePage(page)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: page == _currentPage
                                        ? Colors.deepPurple
                                        : Colors.grey[300],
                                    shape: const CircleBorder(),
                                    padding: const EdgeInsets.all(12),
                                  ),
                                  child: Text('$page'),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: _currentPage < _totalPages
                                ? () => _changePage(_currentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Showing page $_currentPage of $_totalPages (Total users: $_totalUsers)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createUser,
        child: const Icon(Icons.add),
        tooltip: 'Create User',
      ),
    );
  }
}