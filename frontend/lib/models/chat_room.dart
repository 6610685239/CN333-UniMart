/// Represents a chat room in the unified chat list.
/// Each room is tied to a specific product + buyer + seller.
class ChatRoom {
  final String id;
  final String buyerId;
  final String sellerId;
  final bool isBuyer;
  final bool isPinned;
  final bool isLocked;

  // Other user info
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  // Product info (for tags + thumbnail)
  final int? productId;
  final String productTitle;
  final List<String> productImages;
  final int productPrice;
  final int productRentPrice;
  final String productType; // SALE | RENT
  final String productOwnerId;
  final String productStatus;

  // Last message
  final String? lastMessage;
  final String? lastMessageType;
  final DateTime? lastMessageTime;

  // Unread
  final int unreadCount;

  ChatRoom({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    this.isBuyer = true,
    this.isPinned = false,
    this.isLocked = false,
    this.otherUserId = '',
    required this.otherUserName,
    this.otherUserAvatar,
    this.productId,
    required this.productTitle,
    this.productImages = const [],
    this.productPrice = 0,
    this.productRentPrice = 0,
    this.productType = 'SALE',
    this.productOwnerId = '',
    this.productStatus = 'AVAILABLE',
    this.lastMessage,
    this.lastMessageType,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  /// Determine the tag for this room based on the current user's relation to the product.
  /// "[ขาย]" / "[ปล่อยเช่า]" if currentUser == product owner
  /// "[ซื้อ]" / "[เช่า]" if currentUser != product owner
  String tagFor(String currentUserId) {
    final isOwner = currentUserId == productOwnerId;
    if (productType == 'RENT') {
      return isOwner ? '[ปล่อยเช่า]' : '[เช่า]';
    }
    return isOwner ? '[ขาย]' : '[ซื้อ]';
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    final otherUser = json['otherUser'] as Map<String, dynamic>?;
    final product = json['product'] as Map<String, dynamic>?;
    final lastMsg = json['lastMessage'] as Map<String, dynamic>?;

    return ChatRoom(
      id: json['id']?.toString() ?? '',
      buyerId: json['buyerId'] ?? '',
      sellerId: json['sellerId'] ?? '',
      isBuyer: json['isBuyer'] ?? false,
      isPinned: json['isPinned'] ?? false,
      isLocked: json['isLocked'] ?? false,
      otherUserId: otherUser?['id'] ?? '',
      otherUserName: otherUser?['displayName'] ?? otherUser?['username'] ?? 'ไม่ระบุชื่อ',
      otherUserAvatar: otherUser?['avatar'],
      productId: product?['id'],
      productTitle: product?['title'] ?? 'ไม่ระบุ',
      productImages: product?['images'] != null
          ? List<String>.from(product!['images'])
          : [],
      productPrice: product?['price'] ?? 0,
      productRentPrice: product?['rentPrice'] ?? 0,
      productType: product?['type'] ?? 'SALE',
      productOwnerId: product?['ownerId'] ?? '',
      productStatus: product?['status'] ?? 'AVAILABLE',
      lastMessage: lastMsg?['content'],
      lastMessageType: lastMsg?['type'],
      lastMessageTime: lastMsg?['createdAt'] != null
          ? DateTime.parse(lastMsg!['createdAt']).toLocal()
          : null,
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'isBuyer': isBuyer,
      'productTitle': productTitle,
      'otherUserName': otherUserName,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }
}
