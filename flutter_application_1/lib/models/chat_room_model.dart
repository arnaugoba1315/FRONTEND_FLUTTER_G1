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
    return ChatRoom(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? 'Chat Room',
      description: json['description'],
      participants: List<String>.from(json['participants'] ?? []),
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : DateTime.now(),
      lastMessage: json['lastMessage'],
      lastMessageTime: json['lastMessageTime'] != null 
        ? DateTime.parse(json['lastMessageTime']) 
        : null,
    );
  }
}