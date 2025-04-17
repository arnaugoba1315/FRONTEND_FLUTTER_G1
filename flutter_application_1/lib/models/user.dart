class User {
  final String id;
  final String username;
  final String email;
  final String? profilePicture;
  final String? bio;
  final int level;
  final double totalDistance;
  final int totalTime;
  final List<String>? activities;
  final List<String>? achievements;
  final List<String>? challengesCompleted;
  final bool visibility;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.profilePicture,
    this.bio,
    required this.level,
    required this.totalDistance,
    required this.totalTime,
    this.activities,
    this.achievements,
    this.challengesCompleted,
    required this.visibility,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Manejamos tanto _id como id para mayor compatibilidad
    String userId = '';
    if (json.containsKey('_id')) {
      userId = json['_id'].toString();
    } else if (json.containsKey('id')) {
      userId = json['id'].toString();
    }
    
    // Verificación adicional para imprimir información de depuración
    if (userId.isEmpty) {
      print("ADVERTENCIA: ID de usuario vacío en respuesta: ${json}");
    }

    return User(
      id: userId,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      profilePicture: json['profilePicture'],
      bio: json['bio'],
      level: json['level'] ?? 1,
      totalDistance: (json['totalDistance'] ?? 0).toDouble(),
      totalTime: json['totalTime'] ?? 0,
      activities: json['activities'] != null 
          ? List<String>.from(json['activities'])
          : [],
      achievements: json['achievements'] != null 
          ? List<String>.from(json['achievements'])
          : [],
      challengesCompleted: json['challengesCompleted'] != null 
          ? List<String>.from(json['challengesCompleted'])
          : [],
      visibility: json['visibility'] ?? true,
      role: json['role'] ?? 'user',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profilePicture': profilePicture,
      'bio': bio,
      'level': level,
      'totalDistance': totalDistance,
      'totalTime': totalTime,
      'activities': activities,
      'achievements': achievements,
      'challengesCompleted': challengesCompleted,
      'visibility': visibility,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? profilePicture,
    String? bio,
    int? level,
    double? totalDistance,
    int? totalTime,
    List<String>? activities,
    List<String>? achievements,
    List<String>? challengesCompleted,
    bool? visibility,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      profilePicture: profilePicture ?? this.profilePicture,
      bio: bio ?? this.bio,
      level: level ?? this.level,
      totalDistance: totalDistance ?? this.totalDistance,
      totalTime: totalTime ?? this.totalTime,
      activities: activities ?? this.activities,
      achievements: achievements ?? this.achievements,
      challengesCompleted: challengesCompleted ?? this.challengesCompleted,
      visibility: visibility ?? this.visibility,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}