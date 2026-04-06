class ChatRoom {
  final String id;
  final String buyerId;
  final String sellerId;
  final int productId;
  final String productTitle;
  final String otherUserName;
  final String? lastMessage;
  final bool isBuyer;
  final bool isPinned;
  final bool isLocked;

  final DateTime? lastMessageTime;
  final int unreadCount;

  ChatRoom({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.productTitle,
    required this.otherUserName,
    this.lastMessage,
    this.isBuyer = true,
    this.isPinned = false,
    this.isLocked = false,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'] ?? '',
      buyerId: json['buyerId'] ?? '',
      sellerId: json['sellerId'] ?? '',
      productId: json['productId'] ?? 0,
      productTitle: json['productTitle'] ?? 'ไม่ระบุ',
      otherUserName: json['otherUser'] != null
          ? json['otherUser']['displayName'] ?? 'ไม่ระบุชื่อ'
          : json['otherUserName'] ?? 'ไม่ระบุชื่อ',
      lastMessage: json['lastMessage'] != null
          ? json['lastMessage']['content']
          : null,
      lastMessageTime: json['lastMessage'] != null &&
              json['lastMessage']['createdAt'] != null
          ? DateTime.parse(json['lastMessage']['createdAt'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'productId': productId,
      'productTitle': productTitle,
      'otherUserName': otherUserName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }
}
