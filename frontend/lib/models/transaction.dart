class Transaction {
  final int id;
  final String buyerId;
  final String sellerId;
  final int productId;
  final String type;
  final String status;
  final int price;
  final String? meetingPoint;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? product;
  final Map<String, dynamic>? buyer;
  final Map<String, dynamic>? seller;

  Transaction({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    required this.type,
    required this.status,
    required this.price,
    this.meetingPoint,
    required this.createdAt,
    required this.updatedAt,
    this.product,
    this.buyer,
    this.seller,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      buyerId: json['buyerId'] ?? '',
      sellerId: json['sellerId'] ?? '',
      productId: json['productId'] ?? 0,
      type: json['type'] ?? 'SALE',
      status: json['status'] ?? 'PENDING',
      price: json['price'] ?? 0,
      meetingPoint: json['meetingPoint'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      product: json['product'] != null
          ? Map<String, dynamic>.from(json['product'])
          : null,
      buyer: json['buyer'] != null
          ? Map<String, dynamic>.from(json['buyer'])
          : null,
      seller: json['seller'] != null
          ? Map<String, dynamic>.from(json['seller'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'productId': productId,
      'type': type,
      'status': status,
      'price': price,
      'meetingPoint': meetingPoint,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'product': product,
      'buyer': buyer,
      'seller': seller,
    };
  }
}
