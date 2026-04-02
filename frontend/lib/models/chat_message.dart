class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String? content;
  final String? imageUrl;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    this.content,
    this.imageUrl,
    this.type = 'text',
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      roomId: json['roomId'] ?? json['room_id'] ?? '',
      senderId: json['senderId'] ?? json['sender_id'] ?? '',
      content: json['content'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      type: json['type'] ?? 'text',
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
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
