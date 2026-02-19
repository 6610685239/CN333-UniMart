class Product {
  final int id;
  final String title;
  final String description;
  final double price;
  final String status;
  final String condition;
  final List<String> images;
  final String categoryName;
  final String location;
  final String ownerId;
  final String ownerName;
  final String type;
  final double rentPrice;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.status,
    required this.condition,
    required this.images,
    required this.categoryName,
    required this.location,
    required this.ownerId,
    required this.ownerName,
    this.type = 'SALE',
    this.rentPrice = 0.0,
  });

factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0, // ดัก null ให้กลายเป็น 0 
      title: json['title'] ?? 'ไม่มีชื่อสินค้า', // ดัก null กัน Error ประเภท String
      description: json['description'] ?? '',
      price: json['price'] != null ? (json['price'] as num).toDouble() : 0.0, // ดัก null ให้ราคาเป็น 0.0 ก่อนแปลงค่า
      status: json['status'] ?? 'AVAILABLE',
      condition: json['condition'] ?? 'มือหนึ่ง',
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      categoryName: json['category'] != null
          ? json['category']['name']
          : 'ไม่ระบุ',
      location: json['location'] ?? 'ไม่ระบุ',
      ownerId: json['ownerId'] ?? '',
      ownerName: json['owner'] != null
          ? json['owner']['username'] ?? 'ผู้ขายไม่ระบุชื่อ'
          : 'ผู้ขายไม่ระบุชื่อ',
      type: json['type'] ?? 'SALE',
      rentPrice: (json['rentPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}