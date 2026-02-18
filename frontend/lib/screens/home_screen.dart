import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final int currentUserId; // รับ ID เรามา เพื่อจะได้กรองของตัวเองออก

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
        products = allProducts.where((p) => p.ownerId != widget.currentUserId).toList();
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("ตลาดสินค้า", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchProducts,
              child: products.isEmpty
                  ? const Center(child: Text("ยังไม่มีสินค้าจากคนอื่น"))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65, // ปรับความสูงการ์ด
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
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
        _fetchProducts(); // กลับมาแล้วโหลดใหม่ (เผื่อซื้อไปแล้ว)
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. รูปภาพ
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: product.images.isNotEmpty
                    ? Image.network(
                        '${ApiService.baseUrl}/uploads/${product.images[0]}',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                      )
                    : Container(color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
              ),
            ),
            
            // 2. ข้อมูลสินค้า
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "฿ ${product.price}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green),
                  ),
                  const SizedBox(height: 8),
                  
                  // 3. ชื่อคนขาย & สถานที่
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 8, 
                        backgroundColor: Colors.grey, 
                        child: Icon(Icons.person, size: 12, color: Colors.white)
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          product.ownerName, // ชื่อคนขาย
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}