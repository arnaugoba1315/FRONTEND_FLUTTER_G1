class ChatRoom {
  final String id;
  final String name;
  final String? description;
  final List<String> participants;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageTime;

  ChatRoom({
    required this.id,
    required this.name,
    this.description,
    required this.participants,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    // Safely extract the ID - first try '_id', then 'id', or use empty string as fallback
    final String roomId = json['_id'] ?? json['id'] ?? '';
    
    // Get the room name, with a meaningful default
    String roomName = json['name'] ?? 'Chat Room';
    
    // If the name is an ID-like string (long hex string), replace with generic name
    if (roomName.length > 20 && RegExp(r'^[0-9a-f]+$').hasMatch(roomName)) {
      roomName = 'Chat Room';
    }
    
    // Process participants array properly
    List<String> participantsList;
    if (json['participants'] is List) {
      participantsList = List<String>.from(
        (json['participants'] as List).map((item) {
          // Handle if participants can be objects or strings
          if (item is Map) {
            return item['_id'] ?? item['id'] ?? '';
          } else {
            return item.toString();
          }
        })
      );
    } else {
      participantsList = [];
    }
    
    // Parse dates safely
    DateTime createdAtDate;
    try {
      createdAtDate = json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now();
    } catch (e) {
      print('Error parsing createdAt date: $e');
      createdAtDate = DateTime.now();
    }
    
    DateTime? lastMessageTimeDate;
    if (json['lastMessageTime'] != null) {
      try {
        lastMessageTimeDate = DateTime.parse(json['lastMessageTime']);
      } catch (e) {
        print('Error parsing lastMessageTime date: $e');
        lastMessageTimeDate = null;
      }
    }

    return ChatRoom(
      id: roomId,
      name: roomName,
      description: json['description'],
      participants: participantsList,
      createdAt: createdAtDate,
      lastMessage: json['lastMessage'],
      lastMessageTime: lastMessageTimeDate,
    );
  }
  
  // Add a method to convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'participants': participants,
      'createdAt': createdAt.toIso8601String(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
    };
  }
  
  // Create a copy with modified properties
  ChatRoom copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? participants,
    DateTime? createdAt,
    String? lastMessage,
    DateTime? lastMessageTime,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
    );
  }
}