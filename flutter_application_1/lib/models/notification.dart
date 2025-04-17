class Notification {
  final String id;
  final String userId;
  final String type;
  final String content;
  final String? relatedId;
  final bool isRead;
  final DateTime timestamp;

  Notification({
    required this.id,
    required this.userId,
    required this.type,
    required this.content,
    this.relatedId,
    required this.isRead,
    required this.timestamp,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['userId'] ?? '',
      type: json['type'] ?? 'system',
      content: json['content'] ?? '',
      relatedId: json['relatedId'],
      isRead: json['isRead'] ?? false,
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp']) 
        : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'content': content,
      'relatedId': relatedId,
      'isRead': isRead,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get typeIcon {
    switch (type) {
      case 'achievement':
        return '🏆';
      case 'challenge':
        return '🎯';
      case 'activity':
        return '🏃';
      case 'message':
        return '💬';
      case 'friend':
        return '👥';
      default:
        return '📢';
    }
  }

  String get formattedTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} minutos';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} horas';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}