import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/config/routes.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/screens/admin/users_management.dart';
import 'package:flutter_application_1/screens/admin/activities_management.dart';

import '../../services/socket_service.dart';

class BackofficeScreen extends StatefulWidget {
  const BackofficeScreen({Key? key}) : super(key: key);

  @override
  _BackofficeScreenState createState() => _BackofficeScreenState();
}

class _BackofficeScreenState extends State<BackofficeScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _screens = [
    const UsersManagement(),
    const ActivitiesManagement(),
  ];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final socketService = Provider.of<SocketService>(context, listen: false);
              await authService.logout(socketService);
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.username ?? 'Admin'),
              accountEmail: Text(user?.email ?? 'admin@example.com'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: user?.profilePicture != null && user!.profilePicture!.isNotEmpty
                    ? NetworkImage(user.profilePicture!)
                    : null,
                child: user?.profilePicture == null || user!.profilePicture!.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 40.0,
                        color: Colors.deepPurple,
                      )
                    : null,
              ),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users Management'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.directions_run),
              title: const Text('Activities Management'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help & Support'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to help
              },
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Activities',
          ),
        ],
      ),
    );
  }
}