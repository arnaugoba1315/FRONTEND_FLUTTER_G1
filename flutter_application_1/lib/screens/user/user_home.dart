import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/config/routes.dart';
import 'package:flutter_application_1/services/auth_service.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EA Grup 1'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Welcome, ${user?.username ?? "User"}',
                        style: const TextStyle(
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 16.0),
                      const Text(
                        'Here you can manage your sports activities and track your progress.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24.0),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.userProfile);
                        },
                        icon: const Icon(Icons.person),
                        label: const Text('View Profile'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 12.0,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32.0),
              _buildQuickStats(context, user),
              const SizedBox(height: 32.0),
              _buildRecentActivities(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Stats',
          style: TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16.0),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Level',
                '${user?.level ?? 1}',
                Icons.star,
                Colors.amber,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildStatCard(
                context,
                'Distance',
                '${((user?.totalDistance ?? 0) / 1000).toStringAsFixed(2)} km',
                Icons.directions_run,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: _buildStatCard(
                context,
                'Time',
                '${user?.totalTime ?? 0} min',
                Icons.timer,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32.0,
          ),
          const SizedBox(height: 8.0),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.0,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivities(BuildContext context) {
    // Mock data for recent activities
    final List<Map<String, dynamic>> recentActivities = [
      {
        'name': 'Morning Run',
        'date': 'Today, 08:00 AM',
        'type': 'running',
        'distance': '5.2 km',
      },
      {
        'name': 'Cycling Tour',
        'date': 'Yesterday, 10:30 AM',
        'type': 'cycling',
        'distance': '15.7 km',
      },
      {
        'name': 'Evening Walk',
        'date': '2 days ago, 06:00 PM',
        'type': 'walking',
        'distance': '3.1 km',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activities',
              style: TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Navigate to all activities
              },
              child: const Text('See All'),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
        ...recentActivities.map((activity) => _buildActivityCard(context, activity)),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context, Map<String, dynamic> activity) {
    IconData activityIcon;
    Color activityColor;

    switch (activity['type']) {
      case 'running':
        activityIcon = Icons.directions_run;
        activityColor = Colors.green;
        break;
      case 'cycling':
        activityIcon = Icons.directions_bike;
        activityColor = Colors.blue;
        break;
      case 'walking':
        activityIcon = Icons.directions_walk;
        activityColor = Colors.purple;
        break;
      case 'hiking':
        activityIcon = Icons.terrain;
        activityColor = Colors.orange;
        break;
      default:
        activityIcon = Icons.directions_run;
        activityColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: activityColor.withOpacity(0.2),
          child: Icon(
            activityIcon,
            color: activityColor,
          ),
        ),
        title: Text(
          activity['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          activity['date'],
          style: const TextStyle(
            fontSize: 12.0,
          ),
        ),
        trailing: Text(
          activity['distance'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () {
          // Navigate to activity details
        },
      ),
    );
  }
}