class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final String roomId;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.roomId,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: json['userId'] ?? json['senderId'] ?? '',
      senderName: json['username'] ?? json['senderName'] ?? 'Usuario',
      content: json['message'] ?? json['content'] ?? '',
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp']) 
        : DateTime.now(),
      roomId: json['room'] ?? json['roomId'] ?? '',
    );
  }
}