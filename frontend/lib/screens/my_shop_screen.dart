import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key});

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  final ApiService api = ApiService();
  List<Product> products = [];
  bool isLoading = true;
  final int currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final result = await api.getMyProducts(currentUserId);
      setState(() {
        products = result;
        isLoading = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'RESERVED':
        return Colors.orange;
      case 'SOLD':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // พื้นหลังสีเทาอ่อนๆ ให้ Card เด่นขึ้น
      appBar: AppBar(
        title: const Text(
          "ร้านค้าของฉัน",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: GridView.builder(
                padding: const EdgeInsets.all(12), // ขอบรอบๆ ตาราง
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 คอลัมน์ (แสดงสินค้า 2 ชิ้นต่อแถว)
                  childAspectRatio:
                      0.60, // อัตราส่วน กว้าง:สูง (ยิ่งน้อยยิ่งสูง)
                  crossAxisSpacing: 12, // ระยะห่างแนวนอน
                  mainAxisSpacing: 12, // ระยะห่างแนวตั้ง
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  String? firstImage = product.images.isNotEmpty
                      ? '${ApiService.baseUrl}/uploads/${product.images[0]}'
                      : null;

                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailScreen(
                            product: product,
                            currentUserId:
                                currentUserId, // <--- ส่ง ID ของเราไปเทียบ (บรรทัดนี้สำคัญ!)
                          ),
                        ),
                      );
                      _fetchData();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // มุมโค้งมนสวยๆ
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.4),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 4), // เงาตกกระทบด้านล่าง
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. ส่วนรูปภาพ (Image)
                          Expanded(
                            flex: 4, // ให้รูปใช้พื้นที่เยอะหน่อย
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: Stack(
                                children: [
                                  // รูปสินค้า
                                  firstImage != null
                                      ? Image.network(
                                          firstImage,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: Colors.grey[200],
                                          width: double.infinity,
                                          child: const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                            size: 50,
                                          ),
                                        ),

                                  // ป้ายสถานะ (แปะไว้บนรูปมุมขวาบน)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(
                                          product.status,
                                        ).withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        product.status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2. ส่วนข้อมูล (Info)
                          Expanded(
                            flex: 3, // พื้นที่สำหรับตัวหนังสือ
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // หมวดหมู่ (ตัวเล็กๆ สีเทา)
                                      Text(
                                        product.categoryName,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 2),
                                      // ชื่อสินค้า (ตัวหนา)
                                      Text(
                                        product.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      // คำอธิบาย (ตัวเล็ก ตัดคำ)
                                      Text(
                                        product.description,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),

                                  // ราคา และ หัวใจ
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "฿ ${product.price}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.favorite_border,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProductScreen(userId: currentUserId),
            ),
          );
          if (result == true) _fetchData();
        },
        backgroundColor: Colors.black, // ปุ่มสีดำให้ดูมินิมอล
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
