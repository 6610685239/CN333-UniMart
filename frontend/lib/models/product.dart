class Product {
  final int id;
  final String title;
  final String description;
  final double price;
  final String status;
  final String condition;
  final List<String> images;
  final String categoryName; // รับมาเฉพาะชื่อหมวดหมู่ก็ได้เพื่อนแสดงผล
  final String location;

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
  });

  // Factory: แปลงจาก JSON (Map) เป็น Object
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      price: (json['price'] as num).toDouble(), // แปลงเป็น double เสมอ
      status: json['status'] ?? 'AVAILABLE',
      condition: json['condition'] ?? 'มือหนึ่ง',
      // เช็ค null ป้องกันแอปพัง
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      // ดึงชื่อหมวดหมู่จาก object category ที่ซ้อนอยู่
      categoryName: json['category'] != null ? json['category']['name'] : 'ไม่ระบุ',
      location: json['location'] ?? 'ไม่ระบุ',
    );
  }
}