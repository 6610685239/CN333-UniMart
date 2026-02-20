import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';

class MyShopScreen extends StatefulWidget {
  const MyShopScreen({super.key, required this.currentUserId});
  final String currentUserId;

  @override
  State<MyShopScreen> createState() => _MyShopScreenState();
}

class _MyShopScreenState extends State<MyShopScreen> {
  final ApiService api = ApiService();
  List<Product> products = [];
  bool isLoading = true;

  // Palette (match HomePage style)
  static const Color _pink     = Color(0xFFF48FB1);
  static const Color _deepPink = Color(0xFFE91E8C);
  static const Color _bgColor  = Color(0xFFF7F8FA);
  static const Color _textDark = Color(0xFF1A1F36);
  static const Color _textMid  = Color(0xFF8A94A6);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final result = await api.getMyProducts(widget.currentUserId);
      setState(() {
        products = result;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'RESERVED': return Colors.orange;
      case 'SOLD':     return Colors.red;
      default:         return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        // ✅ หัวข้อภาษาอังกฤษ + อยู่ตรงกลาง
        title: const Text(
          'My Shop',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _textDark),
        surfaceTintColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: _deepPink,
              child: products.isEmpty
                  // ✅ Empty state — กดรีเฟรชได้ด้วย CustomScrollView
                  ? CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverFillRemaining(
                          child: _buildEmptyState(),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.60,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) =>
                          _buildProductCard(products[index]),
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddProductScreen(userId: widget.currentUserId),
            ),
          );
          if (result == true) _fetchData();
        },
        backgroundColor: _deepPink,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  // ── EMPTY STATE ──────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ไอคอนวงกลม
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: _pink.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.storefront_outlined, size: 42, color: _pink),
          ),
          const SizedBox(height: 18),
          const Text(
            "No listings yet",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap + to list your first item for sale or rent',
            style: TextStyle(fontSize: 13, color: _textMid),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // ปุ่ม shortcut
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddProductScreen(userId: widget.currentUserId),
                ),
              );
              if (result == true) _fetchData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF48FB1), Color(0xFFE91E8C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: _pink.withOpacity(0.4),
                    blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Text(
                'Start Selling',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PRODUCT CARD ─────────────────────────────────────────────
  Widget _buildProductCard(Product product) {
    final String? firstImage = product.images.isNotEmpty
        ? 'http://10.0.2.2:3000/uploads/${product.images[0]}'
        : null;
    final bool isRent = product.type == 'RENT';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              currentUserId: widget.currentUserId.toString(),
            ),
          ),
        );
        _fetchData();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // รูปภาพ
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    firstImage != null
                        ? Image.network(firstImage, fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: Colors.grey[100],
                              child: const Icon(Icons.image_not_supported_outlined,
                                color: Colors.grey),
                            ))
                        : Container(
                            color: Colors.grey[100],
                            child: const Icon(Icons.image_outlined,
                              color: Colors.grey, size: 50)),

                    if (isRent)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(8)),
                          child: const Text('For Rent',
                            style: TextStyle(color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.bold)),
                        ),
                      ),

                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(product.status).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12)),
                        child: Text(product.status,
                          style: const TextStyle(color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ข้อมูล
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.categoryName,
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          maxLines: 1),
                        const SizedBox(height: 2),
                        Text(product.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(product.description,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isRent ? '฿ ${product.rentPrice} / Day' : '฿ ${product.price}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14,
                            color: isRent ? Colors.blue[700] : _textDark),
                        ),
                        Icon(Icons.favorite_border, size: 18, color: Colors.grey[400]),
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