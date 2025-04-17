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
    return Message(
      id: json['_id'] ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Usuario',
      content: json['content'] ?? '',
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp']) 
        : DateTime.now(),
      roomId: json['roomId'] ?? '',
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
}