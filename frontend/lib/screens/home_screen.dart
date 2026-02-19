import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final String currentUserId; // รับ ID เรามา เพื่อจะได้กรองของตัวเองออก

  const HomeScreen({super.key, required this.currentUserId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService api = ApiService();
  List<Product> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final allProducts = await api.getProducts();
      setState(() {
        // ⭐ กรอง: เอาเฉพาะของที่ไม่ใช่ของฉัน (ownerId != currentUserId)
        products =
            allProducts.where((p) => p.ownerId != widget.currentUserId).toList();
        isLoading = false;
      });
    } catch (e) {
      print("Error loading home: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // พื้นหลังสีเทาอ่อน
      appBar: AppBar(
        title: const Text("ตลาดสินค้า",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black),
              onPressed: () {}),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchProducts,
              child: products.isEmpty
                  ? const Center(child: Text("ยังไม่มีสินค้าจากคนอื่น"))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.60, // ✅ ปรับสัดส่วนให้เท่าหน้า MyShop (0.60)
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _buildProductCard(product);
                      },
                    ),
            ),
    );
  }

Widget _buildProductCard(Product product) {
    String? firstImage = product.images.isNotEmpty
        ? 'http://10.0.2.2:3000/uploads/${product.images[0]}'
        : null;

    // ⭐ เช็คว่าเป็นของเช่าหรือไม่
    bool isRent = product.type == 'RENT';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              currentUserId: widget.currentUserId,
            ),
          ),
        );
        _fetchProducts(); 
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ส่วนรูปภาพ
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    firstImage != null
                        ? Image.network(
                            firstImage,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.image_not_supported),
                            ),
                          )
                        : Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.image, color: Colors.grey, size: 50),
                          ),
                    
                    // ⭐ ป้าย "ให้เช่า" (แสดงเฉพาะ type == RENT)
                    if (isRent)
                      Positioned(
                        top: 8,
                        left: 8, // แปะไว้ซ้ายบน จะได้ไม่ทับสถานะ (ถ้ามี)
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent, // ใช้สีฟ้าให้ดูแตกต่างจากการขาย
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "ให้เช่า",
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 2. ส่วนข้อมูล
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.categoryName,
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),

                    // ⭐ ราคา (เปลี่ยนตามประเภท)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          // ถ้าเช่า โชว์ค่าเช่า + "/ วัน", ถ้าขาย โชว์ราคาปกติ
                          isRent ? "฿ ${product.rentPrice} /วัน" : "฿ ${product.price}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // ลดขนาดลงนิดนึงเผื่อคำว่า /วัน ยาว
                            color: isRent ? Colors.blue[700] : Colors.black87, // ถ้าเช่าให้ตัวเลขสีฟ้า
                          ),
                        ),
                        const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
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
  }
}