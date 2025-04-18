class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final String roomId;
  final bool isRead;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.roomId,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Generate a unique ID if one isn't provided
    String messageId = json['_id'] ?? 
                     json['id'] ?? 
                     'msg_${DateTime.now().millisecondsSinceEpoch}_${json['senderId']}';
    
    // Handle different sender field names
    String sender = '';
    if (json['userId'] != null) sender = json['userId'];
    if (json['senderId'] != null) sender = json['senderId'];
    
    // Handle different sender name field names
    String name = 'Usuario';
    if (json['username'] != null) name = json['username'];
    if (json['senderName'] != null) name = json['senderName'];
    
    // Handle different content field names
    String messageContent = '';
    if (json['message'] != null) messageContent = json['message'];
    if (json['content'] != null) messageContent = json['content'];
    
    // Handle different room ID field names
    String room = '';
    if (json['room'] != null) room = json['room'];
    if (json['roomId'] != null) room = json['roomId'];
    
    // Parse timestamp with error handling
    DateTime messageTime;
    try {
      messageTime = json['timestamp'] != null 
        ? DateTime.parse(json['timestamp']) 
        : DateTime.now();
    } catch (e) {
      print('Error parsing message timestamp: $e');
      messageTime = DateTime.now();
    }

    return Message(
      id: messageId,
      senderId: sender,
      senderName: name,
      content: messageContent,
      timestamp: messageTime,
      roomId: room,
      isRead: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'roomId': roomId,
      'read': isRead,
    };
  }
  
  // Create a copy with updated properties
  Message copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    String? roomId,
    bool? isRead,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      roomId: roomId ?? this.roomId,
      isRead: isRead ?? this.isRead,
    );
  }
  
  // Override equals and hashCode to properly compare messages
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && 
           other.id == id &&
           other.roomId == roomId;
  }

  @override
  int get hashCode => id.hashCode ^ roomId.hashCode;
}