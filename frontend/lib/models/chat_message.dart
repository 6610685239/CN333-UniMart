/// Message delivery status for offline handling
enum MessageStatus {
  sent,    // Confirmed by server
  pending, // Waiting to send (offline / in-flight)
  failed,  // Send failed
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String? content;
  final String? imageUrl;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  /// Client-only: delivery status for optimistic UI
  final MessageStatus status;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.content,
    this.imageUrl,
    this.type = 'text',
    this.isRead = false,
    required this.createdAt,
    this.status = MessageStatus.sent,
  });

  /// Create a copy with a different status
  ChatMessage copyWith({
    String? id,
    bool? isRead,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId,
      senderId: senderId,
      content: content,
      imageUrl: imageUrl,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? '').toString(),
      roomId: json['roomId'] ?? json['room_id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      content: json['content'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      type: json['type'] ?? 'text',
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : json['created_at'] != null
              ? DateTime.parse(json['created_at']).toLocal()
              : DateTime.now(),
      status: MessageStatus.sent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'content': content,
      'imageUrl': imageUrl,
      'type': type,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
