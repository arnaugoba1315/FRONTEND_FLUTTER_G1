import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/activity.dart';
import 'package:flutter_application_1/services/activity_service.dart';
import 'package:flutter_application_1/services/user_service.dart';

class ActivityCreateForm extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback onActivityCreated;

  const ActivityCreateForm({
    Key? key,
    required this.onCancel,
    required this.onActivityCreated,
  }) : super(key: key);

  @override
  _ActivityCreateFormState createState() => _ActivityCreateFormState();
}

class _ActivityCreateFormState extends State<ActivityCreateForm> {
  final _formKey = GlobalKey<FormState>();
  final ActivityService _activityService = ActivityService();
  final UserService _userService = UserService();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _elevationGainController = TextEditingController();
  final TextEditingController _averageSpeedController = TextEditingController();
  final TextEditingController _caloriesBurnedController = TextEditingController();
  
  String _selectedAuthor = '';
  ActivityType _selectedType = ActivityType.running;
  List<Map<String, dynamic>> _authors = [];
  
  bool _isLoading = false;
  bool _isLoadingAuthors = false;
  String _errorMessage = '';
  
  // Date and time pickers
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _endTime = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(hours: 1))
  );

  @override
  void initState() {
    super.initState();
    
    // Initialize date/time fields
    _startTimeController.text = _formatDateTime(_startDate, _startTime);
    _endTimeController.text = _formatDateTime(_endDate, _endTime);
    
    // Set default duration to 60 minutes
    _durationController.text = '60';
    
    // Load authors
    _loadAuthors();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _elevationGainController.dispose();
    _averageSpeedController.dispose();
    _caloriesBurnedController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthors() async {
    setState(() {
      _isLoadingAuthors = true;
    });

    try {
      final response = await _userService.getUsers(limit: 100);
      final users = response['users'];
      
      setState(() {
        _authors = users.map<Map<String, dynamic>>((user) => {
          'id': user.id,
          'username': user.username,
        }).toList();
        
        if (_authors.isNotEmpty) {
          _selectedAuthor = _authors[0]['id'];
        }
        
        _isLoadingAuthors = false;
      });
    } catch (e) {
      print('Error loading authors: $e');
      setState(() {
        _isLoadingAuthors = false;
      });
    }
  }

  String _formatDateTime(DateTime date, TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} $hour:$minute';
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startTimeController.text = _formatDateTime(_startDate, _startTime);
      });
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _startTimeController.text = _formatDateTime(_startDate, _startTime);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endTimeController.text = _formatDateTime(_endDate, _endTime);
        
        // Update duration
        _updateDuration();
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    
    if (picked != null) {
      setState(() {
        _endTime = picked;
        _endTimeController.text = _formatDateTime(_endDate, _endTime);
        
        // Update duration
        _updateDuration();
      });
    }
  }

  void _updateDuration() {
    final startDateTime = _combineDateTime(_startDate, _startTime);
    final endDateTime = _combineDateTime(_endDate, _endTime);
    
    final duration = endDateTime.difference(startDateTime).inMinutes;
    if (duration > 0) {
      _durationController.text = duration.toString();
    }
  }

  Future<void> _createActivity() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Combine date and time
        final startDateTime = _combineDateTime(_startDate, _startTime);
        final endDateTime = _combineDateTime(_endDate, _endTime);
        
        final activityData = {
          'name': _nameController.text,
          'author': _selectedAuthor,
          'startTime': startDateTime.toIso8601String(),
          'endTime': endDateTime.toIso8601String(),
          'duration': int.parse(_durationController.text),
          'distance': double.parse(_distanceController.text),
          'elevationGain': double.parse(_elevationGainController.text),
          'averageSpeed': double.parse(_averageSpeedController.text),
          'caloriesBurned': _caloriesBurnedController.text.isNotEmpty 
              ? double.parse(_caloriesBurnedController.text) 
              : null,
          'type': _selectedType.toString().split('.').last,
          'route': [],
          'musicPlaylist': [],
        };

        await _activityService.createActivity(activityData);
        widget.onActivityCreated();
      } catch (e) {
        setState(() {
          _errorMessage = 'Error creating activity: $e';
        });
        print('Error creating activity: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Activity'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onCancel,
        ),
      ),
      body: _isLoadingAuthors
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Activity Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an activity name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: _selectedAuthor.isEmpty && _authors.isNotEmpty 
                          ? _authors[0]['id'] 
                          : _selectedAuthor,
                      decoration: const InputDecoration(
                        labelText: 'Author',
                        border: OutlineInputBorder(),
                      ),
                      items: _authors.map((author) {
                        return DropdownMenuItem<String>(
                          value: author['id'],
                          child: Text(author['username']),
                        );
                      }).toList(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select an author';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          _selectedAuthor = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<ActivityType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Activity Type',
                        border: OutlineInputBorder(),
                      ),
                      items: ActivityType.values.map((type) {
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
                        return DropdownMenuItem<ActivityType>(
                          value: type,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startTimeController,
                            decoration: const InputDecoration(
                              labelText: 'Start Date & Time',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            onTap: () async {
                              await _selectStartDate();
                              await _selectStartTime();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectStartDate,
                        ),
                        IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: _selectStartTime,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _endTimeController,
                            decoration: const InputDecoration(
                              labelText: 'End Date & Time',
                              border: OutlineInputBorder(),
                            ),
                            readOnly: true,
                            onTap: () async {
                              await _selectEndDate();
                              await _selectEndTime();
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _selectEndDate,
                        ),
                        IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: _selectEndTime,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter duration';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (int.parse(value) < 1) {
                          return 'Duration must be at least 1 minute';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _distanceController,
                      decoration: const InputDecoration(
                        labelText: 'Distance (meters)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter distance';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Distance must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _elevationGainController,
                      decoration: const InputDecoration(
                        labelText: 'Elevation Gain (meters)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter elevation gain';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _averageSpeedController,
                      decoration: const InputDecoration(
                        labelText: 'Average Speed (km/h)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter average speed';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Speed must be greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _caloriesBurnedController,
                      decoration: const InputDecoration(
                        labelText: 'Calories Burned (optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          if (double.parse(value) < 0) {
                            return 'Calories must not be negative';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24.0),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _createActivity,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            )
                          : const Text('Create Activity'),
                    ),
                    const SizedBox(height: 12.0),
                    OutlinedButton(
                      onPressed: widget.onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}