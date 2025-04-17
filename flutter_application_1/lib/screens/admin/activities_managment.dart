import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/activity.dart';
import 'package:flutter_application_1/services/activity_service.dart';
import 'package:flutter_application_1/widgets/activity_card.dart';
import 'package:flutter_application_1/widgets/activity_edit_form.dart';
import 'package:flutter_application_1/widgets/activity_create_form.dart';
import 'package:flutter_application_1/widgets/activity_history_dialog.dart';

class ActivitiesManagement extends StatefulWidget {
  const ActivitiesManagement({Key? key}) : super(key: key);

  @override
  _ActivitiesManagementState createState() => _ActivitiesManagementState();
}

class _ActivitiesManagementState extends State<ActivitiesManagement> {
  final ActivityService _activityService = ActivityService();
  
  List<Activity> _activities = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalActivities = 0;
  bool _isLoading = false;
  String _errorMessage = '';
  String _filterType = '';
  
  // For editing and creating activities
  bool _showEditForm = false;
  bool _showCreateForm = false;
  Activity? _selectedActivity;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _activityService.getActivities(
        page: _currentPage,
        limit: 5,
      );
      
      setState(() {
        _activities = response['activities'];
        _totalActivities = response['totalActivities'];
        _totalPages = response['totalPages'];
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading activities';
      });
      print('Error loading activities: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshActivities() async {
    await _loadActivities();
  }

  void _changePage(int page) {
    if (page < 1 || page > _totalPages) return;
    setState(() {
      _currentPage = page;
    });
    _loadActivities();
  }

  void _filterActivities() {
    // Resets to first page when filtering
    setState(() {
      _currentPage = 1;
    });
    _loadActivities();
  }

  Future<void> _deleteActivity(Activity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete activity "${activity.name}"?'),
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
        await _activityService.deleteActivity(activity.id);
        _refreshActivities();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting activity: $e')),
        );
      }
    }
  }

  void _showActivityDetails(Activity activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(activity.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _activityTypeChip(activity.type),
              const SizedBox(height: 16),
              _detailRow('Author', activity.authorName ?? activity.author),
              _detailRow('Start Time', _formatDateTime(activity.startTime)),
              _detailRow('End Time', _formatDateTime(activity.endTime)),
              _detailRow('Duration', _formatDuration(activity.duration)),
              _detailRow('Distance', _formatDistance(activity.distance)),
              _detailRow('Elevation Gain', '${activity.elevationGain.toStringAsFixed(0)} m'),
              _detailRow('Average Speed', '${activity.averageSpeed.toStringAsFixed(1)} km/h'),
              if (activity.caloriesBurned != null)
                _detailRow('Calories Burned', '${activity.caloriesBurned!.toStringAsFixed(0)} kcal'),
              _detailRow('Route Points', '${activity.route.length}'),
              if (activity.musicPlaylist != null)
                _detailRow('Music Playlist', '${activity.musicPlaylist!.length} songs'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _editActivity(activity);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showActivityHistory(Activity activity) {
    showDialog(
      context: context,
      builder: (context) => ActivityHistoryDialog(activityId: activity.id),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${mins}min';
    } else {
      return '${mins}min';
    }
  }

  String _formatDistance(double meters) {
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  Widget _activityTypeChip(ActivityType type) {
    Color color;
    String label;

    switch (type) {
      case ActivityType.running:
        color = Colors.green;
        label = 'Running';
        break;
      case ActivityType.cycling:
        color = Colors.blue;
        label = 'Cycling';
        break;
      case ActivityType.hiking:
        color = Colors.orange;
        label = 'Hiking';
        break;
      case ActivityType.walking:
        color = Colors.purple;
        label = 'Walking';
        break;
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
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

  void _editActivity(Activity activity) {
    setState(() {
      _selectedActivity = activity;
      _showEditForm = true;
    });
  }

  void _createActivity() {
    setState(() {
      _showCreateForm = true;
    });
  }

  void _cancelCreateActivity() {
    setState(() {
      _showCreateForm = false;
    });
  }

  void _activityCreated() {
    setState(() {
      _showCreateForm = false;
    });
    _refreshActivities();
  }

  void _cancelEditActivity() {
    setState(() {
      _showEditForm = false;
      _selectedActivity = null;
    });
  }

  void _activityUpdated() {
    setState(() {
      _showEditForm = false;
      _selectedActivity = null;
    });
    _refreshActivities();
  }

  @override
  Widget build(BuildContext context) {
    if (_showCreateForm) {
      return ActivityCreateForm(
        onCancel: _cancelCreateActivity,
        onActivityCreated: _activityCreated,
      );
    }

    if (_showEditForm && _selectedActivity != null) {
      return ActivityEditForm(
        activity: _selectedActivity!,
        onCancel: _cancelEditActivity,
        onActivityUpdated: _activityUpdated,
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshActivities,
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
                          'Activities Management',
                          style: Theme.of(context).textTheme.headline6,
                        ),
                        DropdownButton<String>(
                          hint: const Text('Filter by type'),
                          value: _filterType.isEmpty ? null : _filterType,
                          onChanged: (value) {
                            setState(() {
                              _filterType = value ?? '';
                            });
                            _filterActivities();
                          },
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('All types'),
                            ),
                            ...ActivityType.values.map((type) {
                              String label;
                              switch (type) {
                                case ActivityType.running:
                                  label = 'Running';
                                  break;
                                case ActivityType.cycling:
                                  label = 'Cycling';
                                  break;
                                case ActivityType.hiking:
                                  label = 'Hiking';
                                  break;
                                case ActivityType.walking:
                                  label = 'Walking';
                                  break;
                              }
                              return DropdownMenuItem(
                                value: label.toLowerCase(),
                                child: Text(label),
                              );
                            }).toList(),
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
                    child: _activities.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.directions_run,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No activities found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _createActivity,
                                  child: const Text('Create Activity'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(8.0),
                            itemCount: _activities.length,
                            itemBuilder: (context, index) {
                              final activity = _activities[index];
                              return ActivityCard(
                                activity: activity,
                                onView: () => _showActivityDetails(activity),
                                onEdit: () => _editActivity(activity),
                                onDelete: () => _deleteActivity(activity),
                                onViewHistory: () => _showActivityHistory(activity),
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
                      'Showing page $_currentPage of $_totalPages (Total activities: $_totalActivities)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createActivity,
        child: const Icon(Icons.add),
        tooltip: 'Create Activity',
      ),
    );
  }
}

extension on TextTheme {
  get headline6 => null;
}